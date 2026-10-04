#!/usr/bin/env bash
# Deletes everything setup.sh created. No final snapshot is kept.
set -uo pipefail
. ./lab.env

aws rds delete-db-instance --region "$REGION" --db-instance-identifier "$NAME-1" >/dev/null
aws rds delete-db-cluster --region "$REGION" --db-cluster-identifier "$NAME" --skip-final-snapshot >/dev/null
aws rds wait db-instance-deleted --region "$REGION" --db-instance-identifier "$NAME-1"
aws rds wait db-cluster-deleted --region "$REGION" --db-cluster-identifier "$NAME"
aws rds delete-db-cluster-parameter-group --region "$REGION" --db-cluster-parameter-group-name "$NAME"
aws ec2 delete-security-group --region "$REGION" --group-id "$SG" >/dev/null
aws iam detach-role-policy --role-name "$NAME-role" --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/$NAME-read"
aws iam delete-role --role-name "$NAME-role"
aws iam delete-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/$NAME-read"
aws glue delete-table --region "$REGION" --database-name "$GLUE_DB" --name bookings_history
aws glue delete-database --region "$REGION" --name "$GLUE_DB"
aws athena delete-work-group --region "$REGION" --work-group "$NAME" --recursive-delete-option
aws s3 rm "s3://$BUCKET" --recursive --quiet
aws s3api delete-bucket --bucket "$BUCKET" --region "$REGION"

echo "left over (should be empty):"
aws resourcegroupstaggingapi get-resources --region "$REGION" --tag-filters "Key=Project,Values=$NAME" \
  --query 'ResourceTagMappingList[].ResourceARN' --output text
