#!/bin/bash
set -euo pipefail

# FSxN スタッククリーンアップスクリプト v2
# RETAIN リソースの正しい削除順序を自動化する
# v2: VPC クリーンアップ追加、待機時間改善、SnapLock 対応
#
# Usage:
#   ./shared/scripts/cleanup-fsxn-stack.sh <stack-name> <region>
#
# Example:
#   ./shared/scripts/cleanup-fsxn-stack.sh Dev-BLEAFsxnModernization ap-northeast-1

STACK_NAME="${1:?Usage: $0 <stack-name> <region>}"
REGION="${2:-ap-northeast-1}"
WAIT_INTERVAL=30

echo "🧹 Cleaning up stack: ${STACK_NAME} in ${REGION}"

# 1. スタック状態確認
STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" --region "$REGION" \
  --query 'Stacks[0].StackStatus' --output text 2>&1 || echo "NOT_FOUND")

if echo "$STATUS" | grep -q "does not exist\|NOT_FOUND"; then
  echo "✅ Stack does not exist. Nothing to clean."
  exit 0
fi

echo "📋 Stack status: $STATUS"

# 2. VPC ID を記録（後で VPC クリーンアップに使用）
VPC_IDS=$(aws cloudformation list-stack-resources \
  --stack-name "$STACK_NAME" --region "$REGION" \
  --query 'StackResourceSummaries[?ResourceType==`AWS::EC2::VPC`].PhysicalResourceId' \
  --output text 2>/dev/null || echo "")

# 3. FSxN リソースを特定・削除
FS_IDS=$(aws cloudformation list-stack-resources \
  --stack-name "$STACK_NAME" --region "$REGION" \
  --query 'StackResourceSummaries[?ResourceType==`AWS::FSx::FileSystem`].PhysicalResourceId' \
  --output text 2>/dev/null || echo "")

for FS_ID in $FS_IDS; do
  if [ -z "$FS_ID" ]; then continue; fi

  echo "🔍 Processing FSxN: $FS_ID"

  # FSxN が存在するか確認
  FS_STATUS=$(aws fsx describe-file-systems --file-system-ids "$FS_ID" --region "$REGION" \
    --query 'FileSystems[0].Lifecycle' --output text 2>&1 || echo "NOT_FOUND")

  if echo "$FS_STATUS" | grep -q "NOT_FOUND\|does not exist"; then
    echo "  ⏭️  FSxN $FS_ID already deleted"
    continue
  fi

  echo "  📊 FSxN status: $FS_STATUS"

  if [ "$FS_STATUS" = "AVAILABLE" ]; then
    # Volume 削除 (ルートボリューム以外)
    VOLS=$(aws fsx describe-volumes --region "$REGION" \
      --filters Name=file-system-id,Values="$FS_ID" \
      --query 'Volumes[?!ends_with(Name, `_root`)].VolumeId' --output text 2>/dev/null || echo "")

    for VOL_ID in $VOLS; do
      if [ -z "$VOL_ID" ]; then continue; fi
      echo "  🗑️  Deleting volume: $VOL_ID"
      aws fsx delete-volume --volume-id "$VOL_ID" \
        --ontap-configuration '{"SkipFinalBackup":true,"BypassSnaplockEnterpriseRetention":true}' \
        --region "$REGION" --output text 2>/dev/null || true
    done

    # Volume 削除完了を待機
    if [ -n "$VOLS" ] && [ "$VOLS" != " " ]; then
      echo "  ⏳ Waiting for volume deletion..."
      for i in $(seq 1 10); do
        REMAINING=$(aws fsx describe-volumes --region "$REGION" \
          --filters Name=file-system-id,Values="$FS_ID" \
          --query 'Volumes[?!ends_with(Name, `_root`) && Lifecycle!=`DELETED`] | length(@)' \
          --output text 2>/dev/null || echo "0")
        if [ "$REMAINING" = "0" ]; then
          echo "  ✅ All volumes deleted"
          break
        fi
        echo "  ⏳ $REMAINING volumes remaining... (attempt $i/10)"
        sleep $WAIT_INTERVAL
      done
    fi

    # SVM 削除
    SVMS=$(aws fsx describe-storage-virtual-machines --region "$REGION" \
      --filters Name=file-system-id,Values="$FS_ID" \
      --query 'StorageVirtualMachines[*].StorageVirtualMachineId' --output text 2>/dev/null || echo "")

    for SVM_ID in $SVMS; do
      if [ -z "$SVM_ID" ]; then continue; fi
      echo "  🗑️  Deleting SVM: $SVM_ID"
      aws fsx delete-storage-virtual-machine --storage-virtual-machine-id "$SVM_ID" \
        --region "$REGION" --output text 2>/dev/null || true
    done

    # SVM 削除完了を待機
    if [ -n "$SVMS" ] && [ "$SVMS" != " " ]; then
      echo "  ⏳ Waiting for SVM deletion..."
      for i in $(seq 1 10); do
        SVM_CHECK=$(aws fsx describe-storage-virtual-machines --region "$REGION" \
          --filters Name=file-system-id,Values="$FS_ID" \
          --query 'StorageVirtualMachines | length(@)' --output text 2>/dev/null || echo "0")
        if [ "$SVM_CHECK" = "0" ]; then
          echo "  ✅ All SVMs deleted"
          break
        fi
        echo "  ⏳ $SVM_CHECK SVMs remaining... (attempt $i/10)"
        sleep $WAIT_INTERVAL
      done
    fi

    # FileSystem 削除
    echo "  🗑️  Deleting FSxN: $FS_ID"
    aws fsx delete-file-system --file-system-id "$FS_ID" --region "$REGION" --output text 2>/dev/null || true
    echo "  ⏳ FSxN deletion initiated (takes 20-30 min)"
  fi
done

# 4. FSxN 削除完了を待機（VPC ENI 解放のため）
if [ -n "$FS_IDS" ] && [ "$FS_IDS" != " " ]; then
  echo ""
  echo "⏳ Waiting for FSxN deletion to complete (max 35 min)..."
  for i in $(seq 1 70); do
    ALL_GONE=true
    for FS_ID in $FS_IDS; do
      if [ -z "$FS_ID" ]; then continue; fi
      CHECK=$(aws fsx describe-file-systems --file-system-ids "$FS_ID" --region "$REGION" \
        --query 'FileSystems[0].Lifecycle' --output text 2>&1 || echo "GONE")
      if ! echo "$CHECK" | grep -q "GONE\|does not exist"; then
        ALL_GONE=false
        break
      fi
    done
    if [ "$ALL_GONE" = true ]; then
      echo "✅ All FSxN file systems deleted"
      break
    fi
    if [ $((i % 6)) -eq 0 ]; then
      echo "  ⏳ Still waiting... ($((i * WAIT_INTERVAL / 60)) min elapsed)"
    fi
    sleep $WAIT_INTERVAL
  done
fi

# 5. CloudFormation スタック削除
echo ""
echo "🗑️  Deleting CloudFormation stack..."

# 再取得（ステータスが変わっている可能性）
STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" --region "$REGION" \
  --query 'Stacks[0].StackStatus' --output text 2>&1 || echo "NOT_FOUND")

if echo "$STATUS" | grep -q "does not exist\|NOT_FOUND"; then
  echo "  ✅ Stack already deleted"
elif echo "$STATUS" | grep -q "DELETE_FAILED"; then
  RETAIN_IDS=$(aws cloudformation list-stack-resources \
    --stack-name "$STACK_NAME" --region "$REGION" \
    --query 'StackResourceSummaries[?ResourceStatus!=`DELETE_COMPLETE`].LogicalResourceId' \
    --output text 2>/dev/null | tr '\t' '\n' | head -20)
  # shellcheck disable=SC2086
  aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" --region "$REGION" \
    --retain-resources $RETAIN_IDS 2>/dev/null || \
  aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" --region "$REGION" 2>/dev/null || true
else
  aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" --region "$REGION" 2>/dev/null || true
fi

# スタック削除完了を待機
echo "  ⏳ Waiting for stack deletion..."
for i in $(seq 1 12); do
  CHECK=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" --region "$REGION" \
    --query 'Stacks[0].StackStatus' --output text 2>&1 || echo "GONE")
  if echo "$CHECK" | grep -q "GONE\|does not exist"; then
    echo "  ✅ Stack deleted"
    break
  fi
  sleep 10
done

# 6. 孤立 VPC クリーンアップ
if [ -n "$VPC_IDS" ] && [ "$VPC_IDS" != " " ]; then
  echo ""
  echo "🧹 Cleaning up orphaned VPCs..."
  for VPC_ID in $VPC_IDS; do
    if [ -z "$VPC_ID" ]; then continue; fi

    # VPC が存在するか確認
    VPC_CHECK=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION" 2>&1 || echo "NOT_FOUND")
    if echo "$VPC_CHECK" | grep -q "NOT_FOUND\|does not exist\|InvalidVpcID"; then
      continue
    fi

    echo "  🔍 Cleaning VPC: $VPC_ID"

    # VPC Endpoints 削除
    EPS=$(aws ec2 describe-vpc-endpoints --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" \
      --query 'VpcEndpoints[*].VpcEndpointId' --output text 2>/dev/null || echo "")
    for EP in $EPS; do
      if [ -n "$EP" ]; then
        aws ec2 delete-vpc-endpoints --vpc-endpoint-ids "$EP" --region "$REGION" 2>/dev/null || true
      fi
    done

    # Subnets 削除
    SUBS=$(aws ec2 describe-subnets --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" \
      --query 'Subnets[*].SubnetId' --output text 2>/dev/null || echo "")
    for S in $SUBS; do
      if [ -n "$S" ]; then
        aws ec2 delete-subnet --subnet-id "$S" --region "$REGION" 2>/dev/null || true
      fi
    done

    # Non-main Route Tables 削除
    RTS=$(aws ec2 describe-route-tables --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" \
      --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null || echo "")
    for R in $RTS; do
      if [ -n "$R" ]; then
        aws ec2 delete-route-table --route-table-id "$R" --region "$REGION" 2>/dev/null || true
      fi
    done

    # Non-default Security Groups 削除
    SGS=$(aws ec2 describe-security-groups --region "$REGION" \
      --filters Name=vpc-id,Values="$VPC_ID" \
      --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")
    for SG in $SGS; do
      if [ -n "$SG" ]; then
        aws ec2 delete-security-group --group-id "$SG" --region "$REGION" 2>/dev/null || true
      fi
    done

    # VPC 削除
    aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$REGION" 2>/dev/null && \
      echo "  ✅ Deleted VPC: $VPC_ID" || \
      echo "  ⚠️  Could not delete VPC: $VPC_ID (may have remaining dependencies)"
  done
fi

echo ""
echo "✅ Cleanup complete."
