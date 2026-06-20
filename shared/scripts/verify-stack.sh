#!/bin/bash
set -euo pipefail

# スタックデプロイ検証スクリプト
# CloudFormation スタックのリソースを検証し、レポートを出力する
#
# Usage:
#   ./shared/scripts/verify-stack.sh <stack-name> <region>

STACK_NAME="${1:?Usage: $0 <stack-name> <region>}"
REGION="${2:-ap-northeast-1}"

echo "================================================"
echo " Stack Verification Report"
echo " Stack: ${STACK_NAME}"
echo " Region: ${REGION}"
echo " Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "================================================"
echo ""

# 1. スタック状態
STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" --region "$REGION" \
  --query 'Stacks[0].StackStatus' --output text 2>&1)

echo "## Stack Status: $STATUS"
if [ "$STATUS" != "CREATE_COMPLETE" ] && [ "$STATUS" != "UPDATE_COMPLETE" ]; then
  echo "❌ Stack is NOT in a healthy state."
  exit 1
fi
echo "✅ Stack is healthy"
echo ""

# 2. リソース数
RESOURCE_COUNT=$(aws cloudformation describe-stack-resources \
  --stack-name "$STACK_NAME" --region "$REGION" \
  --query 'StackResources | length(@)' --output text)
echo "## Total Resources: $RESOURCE_COUNT"
echo ""

# 3. FSxN リソース
echo "## FSxN Resources"
aws cloudformation describe-stack-resources \
  --stack-name "$STACK_NAME" --region "$REGION" \
  --query 'StackResources[?starts_with(ResourceType, `AWS::FSx`)].[LogicalResourceId,ResourceType,ResourceStatus]' \
  --output table 2>/dev/null || echo "  (none)"
echo ""

# 4. コンピュートリソース
echo "## Compute Resources"
aws cloudformation describe-stack-resources \
  --stack-name "$STACK_NAME" --region "$REGION" \
  --query 'StackResources[?ResourceType==`AWS::Lambda::Function` || ResourceType==`AWS::ECS::Service` || ResourceType==`AWS::EKS::Cluster` || ResourceType==`AWS::Batch::ComputeEnvironment` || ResourceType==`AWS::AutoScaling::AutoScalingGroup`].[LogicalResourceId,ResourceType,ResourceStatus]' \
  --output table 2>/dev/null || echo "  (none)"
echo ""

# 5. セキュリティリソース
echo "## Security Resources"
aws cloudformation describe-stack-resources \
  --stack-name "$STACK_NAME" --region "$REGION" \
  --query 'StackResources[?ResourceType==`AWS::KMS::Key` || ResourceType==`AWS::Backup::BackupVault`].[LogicalResourceId,ResourceType,ResourceStatus]' \
  --output table 2>/dev/null || echo "  (none)"
echo ""

# 6. モニタリング
echo "## Monitoring Resources"
aws cloudformation describe-stack-resources \
  --stack-name "$STACK_NAME" --region "$REGION" \
  --query 'StackResources[?ResourceType==`AWS::CloudWatch::Alarm` || ResourceType==`AWS::SNS::Topic`].[LogicalResourceId,ResourceType,ResourceStatus]' \
  --output table 2>/dev/null || echo "  (none)"
echo ""

# 7. エラーリソース
FAILED=$(aws cloudformation describe-stack-resources \
  --stack-name "$STACK_NAME" --region "$REGION" \
  --query 'StackResources[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`] | length(@)' \
  --output text)

if [ "$FAILED" -gt 0 ]; then
  echo "## ❌ Failed Resources: $FAILED"
  aws cloudformation describe-stack-resources \
    --stack-name "$STACK_NAME" --region "$REGION" \
    --query 'StackResources[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
    --output table
else
  echo "## ✅ No Failed Resources"
fi

echo ""
echo "================================================"
echo " Verification complete"
echo "================================================"
