#!/bin/bash
set -euo pipefail

# BLEA FSxN Data Analytics - Automated Deploy & Verify Script
# This script automates the entire deployment verification process.
# Run from: usecases/blea-guest-fsxn-data-analytics-sample/
#
# Prerequisites:
#   - AWS CLI configured with correct profile/credentials
#   - CDK Bootstrap done in target account/region
#   - npm ci already executed
#
# Usage:
#   ./scripts/deploy-and-verify.sh [deploy|verify|cleanup|all]

REGION="ap-northeast-1"
STACK_NAME="Dev-BLEAFsxnDataAnalytics"
CRAWLER_NAME="fsxn-data-crawler"
DATABASE_NAME="fsxn_analytics_db"
WORKGROUP_NAME="fsxn-analytics"
EVIDENCE_DIR="doc/verification-results"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

# ──────────────────────────────────────────────────────
# DEPLOY
# ──────────────────────────────────────────────────────
deploy() {
  log_info "Starting CDK deploy..."
  npx cdk deploy --all --require-approval never
  log_ok "Stack deployed: $STACK_NAME"
}

# ──────────────────────────────────────────────────────
# VERIFY
# ──────────────────────────────────────────────────────
verify() {
  log_info "Starting verification..."
  mkdir -p "$EVIDENCE_DIR"

  # 1. Stack status
  STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].StackStatus' --output text)
  if [ "$STACK_STATUS" = "CREATE_COMPLETE" ] || [ "$STACK_STATUS" = "UPDATE_COMPLETE" ]; then
    log_ok "Stack status: $STACK_STATUS"
  else
    log_fail "Stack status: $STACK_STATUS"
    exit 1
  fi

  # 2. FSxN File System
  FS_ID=$(aws cloudformation describe-stack-resources --stack-name "$STACK_NAME" --region "$REGION" \
    --query "StackResources[?ResourceType=='AWS::FSx::FileSystem'].PhysicalResourceId" --output text)
  FS_LIFECYCLE=$(aws fsx describe-file-systems --file-system-ids "$FS_ID" --region "$REGION" \
    --query 'FileSystems[0].Lifecycle' --output text)
  if [ "$FS_LIFECYCLE" = "AVAILABLE" ]; then
    log_ok "FSxN FileSystem: $FS_ID ($FS_LIFECYCLE)"
  else
    log_fail "FSxN FileSystem: $FS_ID ($FS_LIFECYCLE)"
  fi

  # 3. S3 Access Point
  AP_NAME=$(aws cloudformation describe-stack-resources --stack-name "$STACK_NAME" --region "$REGION" \
    --query "StackResources[?ResourceType=='AWS::FSx::S3AccessPointAttachment'].PhysicalResourceId" --output text)
  AP_ALIAS=$(aws fsx describe-s3-access-point-attachments --region "$REGION" \
    --query "S3AccessPointAttachments[?Name=='$AP_NAME'].S3AccessPoint.Alias" --output text)
  if [ -n "$AP_ALIAS" ]; then
    log_ok "S3 Access Point: $AP_NAME (alias: $AP_ALIAS)"
  else
    log_fail "S3 Access Point not found"
  fi

  # 4. Glue Crawler
  CRAWLER_STATE=$(aws glue get-crawler --name "$CRAWLER_NAME" --region "$REGION" \
    --query 'Crawler.State' --output text)
  log_ok "Glue Crawler: $CRAWLER_NAME ($CRAWLER_STATE)"

  # 5. Athena Workgroup
  WG_STATE=$(aws athena get-work-group --work-group "$WORKGROUP_NAME" --region "$REGION" \
    --query 'WorkGroup.State' --output text)
  log_ok "Athena Workgroup: $WORKGROUP_NAME ($WG_STATE)"

  # 6. Security: No IGW
  VPC_ID=$(aws cloudformation describe-stack-resources --stack-name "$STACK_NAME" --region "$REGION" \
    --query "StackResources[?ResourceType=='AWS::EC2::VPC'].PhysicalResourceId" --output text)
  IGW_COUNT=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --region "$REGION" --query 'length(InternetGateways)' --output text)
  if [ "$IGW_COUNT" = "0" ]; then
    log_ok "No Internet Gateway (security OK)"
  else
    log_fail "Internet Gateway found!"
  fi

  # 7. CloudWatch Alarms
  ALARM_COUNT=$(aws cloudwatch describe-alarms --alarm-name-prefix "$STACK_NAME" --region "$REGION" \
    --query 'length(MetricAlarms)' --output text)
  log_ok "CloudWatch Alarms: $ALARM_COUNT"

  # 8. S3 AP data access test
  if [ -n "$AP_ALIAS" ]; then
    FILE_COUNT=$(aws s3api list-objects-v2 --bucket "$AP_ALIAS" --prefix "sample/" \
      --region "$REGION" --query 'KeyCount' --output text 2>/dev/null || echo "0")
    if [ "$FILE_COUNT" -gt "0" ]; then
      log_ok "S3 AP data access: $FILE_COUNT files visible"
    else
      log_info "S3 AP: no files yet (run test data generation first)"
    fi
  fi

  # 9. Run Glue Crawler if data exists
  if [ "${FILE_COUNT:-0}" -gt "0" ] && [ "$CRAWLER_STATE" = "READY" ]; then
    log_info "Starting Glue Crawler..."
    aws glue start-crawler --name "$CRAWLER_NAME" --region "$REGION"
    log_info "Waiting for Crawler to complete (up to 3 min)..."
    for i in $(seq 1 18); do
      sleep 10
      STATE=$(aws glue get-crawler --name "$CRAWLER_NAME" --region "$REGION" \
        --query 'Crawler.State' --output text)
      if [ "$STATE" = "READY" ]; then
        LAST_STATUS=$(aws glue get-crawler --name "$CRAWLER_NAME" --region "$REGION" \
          --query 'Crawler.LastCrawl.Status' --output text)
        if [ "$LAST_STATUS" = "SUCCEEDED" ]; then
          log_ok "Glue Crawler: SUCCEEDED"
        else
          log_fail "Glue Crawler: $LAST_STATUS"
        fi
        break
      fi
    done
  fi

  # 10. Athena query test
  TABLE_COUNT=$(aws glue get-tables --database-name "$DATABASE_NAME" --region "$REGION" \
    --query 'length(TableList)' --output text 2>/dev/null || echo "0")
  if [ "$TABLE_COUNT" -gt "0" ]; then
    TABLE_NAME=$(aws glue get-tables --database-name "$DATABASE_NAME" --region "$REGION" \
      --query 'TableList[0].Name' --output text)
    QUERY_ID=$(aws athena start-query-execution \
      --query-string "SELECT category, COUNT(*) as cnt FROM $TABLE_NAME GROUP BY category" \
      --work-group "$WORKGROUP_NAME" \
      --query-execution-context Database="$DATABASE_NAME" \
      --region "$REGION" --query 'QueryExecutionId' --output text)
    log_info "Athena query submitted: $QUERY_ID"
    sleep 15
    QUERY_STATUS=$(aws athena get-query-execution --query-execution-id "$QUERY_ID" --region "$REGION" \
      --query 'QueryExecution.Status.State' --output text)
    if [ "$QUERY_STATUS" = "SUCCEEDED" ]; then
      log_ok "Athena query: SUCCEEDED"
      aws athena get-query-results --query-execution-id "$QUERY_ID" --region "$REGION" \
        --query 'ResultSet.Rows[*].Data[*].VarCharValue' --output table
    else
      log_fail "Athena query: $QUERY_STATUS"
    fi
  else
    log_info "No tables in Glue database (run Crawler first)"
  fi

  # Collect evidence
  log_info "Collecting evidence JSON..."
  aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --output json > "$EVIDENCE_DIR/stack-status.json"
  aws fsx describe-file-systems --file-system-ids "$FS_ID" --region "$REGION" --output json > "$EVIDENCE_DIR/fsxn-filesystem.json"
  log_ok "Evidence saved to $EVIDENCE_DIR/"
}

# ──────────────────────────────────────────────────────
# CLEANUP
# ──────────────────────────────────────────────────────
cleanup() {
  log_info "Starting cleanup..."
  npx cdk destroy --all --require-approval never || true

  log_info "Checking for RETAIN resources..."
  FS_ID=$(aws fsx describe-file-systems --region "$REGION" \
    --query "FileSystems[?Tags[?Key=='Environment' && Value=='Development']].FileSystemId" --output text 2>/dev/null || echo "")

  if [ -n "$FS_ID" ] && [ "$FS_ID" != "None" ]; then
    log_info "RETAIN resource found: FSxN $FS_ID"
    echo -e "${YELLOW}To delete manually:${NC}"
    echo "  aws fsx delete-volume --volume-id <vol-id> --ontap-configuration '{\"SkipFinalBackup\":true}' --region $REGION"
    echo "  aws fsx delete-storage-virtual-machine --storage-virtual-machine-id <svm-id> --region $REGION"
    echo "  aws fsx delete-file-system --file-system-id $FS_ID --ontap-configuration '{\"SkipFinalBackup\":true}' --region $REGION"
  else
    log_ok "No RETAIN FSxN resources found"
  fi
}

# ──────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────
case "${1:-all}" in
  deploy)  deploy ;;
  verify)  verify ;;
  cleanup) cleanup ;;
  all)     deploy && verify ;;
  *)       echo "Usage: $0 [deploy|verify|cleanup|all]"; exit 1 ;;
esac
