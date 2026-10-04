#!/usr/bin/env bash
# Creates everything the lab needs and writes the names to lab.env.
# Uses the default VPC of the region. Run teardown.sh when you are done.
set -euo pipefail

REGION=${REGION:-us-east-1}
NAME=${NAME:-aurora-iceberg-lab}
INSTANCE_CLASS=${INSTANCE_CLASS:-db.r8g.large}
ENGINE_VERSION=${ENGINE_VERSION:-17.11}
GLUE_DB=${GLUE_DB:-aurora_lab}
MY_IP=${MY_IP:-$(curl -s https://checkip.amazonaws.com)}

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET=${BUCKET:-$NAME-$ACCOUNT_ID-$(date +%s)}
PW=$(openssl rand -hex 16)
TAG="Key=Project,Value=$NAME"
VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNET_GROUP=default-$VPC_ID

cat > lab.env <<ENV
REGION=$REGION
NAME=$NAME
ACCOUNT_ID=$ACCOUNT_ID
BUCKET=$BUCKET
GLUE_DB=$GLUE_DB
PGPASSWORD=$PW
ENV

echo "bucket and glue database"
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
aws glue create-database --region "$REGION" --database-input "Name=$GLUE_DB"
aws athena create-work-group --region "$REGION" --name "$NAME" \
  --configuration "ResultConfiguration={OutputLocation=s3://$BUCKET/athena-results/}" --tags "$TAG"

echo "iam role for the cluster"
sed -e "s/\${BUCKET}/$BUCKET/g" -e "s/\${REGION}/$REGION/g" -e "s/\${ACCOUNT_ID}/$ACCOUNT_ID/g" -e "s/\${GLUE_DB}/$GLUE_DB/g" \
  iam-policy.json > /tmp/$NAME-policy.json
aws iam create-policy --policy-name "$NAME-read" --policy-document "file:///tmp/$NAME-policy.json" --tags "$TAG" >/dev/null
aws iam create-role --role-name "$NAME-role" --tags "$TAG" >/dev/null --assume-role-policy-document \
  '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"rds.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name "$NAME-role" --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/$NAME-read"

echo "parameter group and security group"
aws rds create-db-cluster-parameter-group --region "$REGION" --db-cluster-parameter-group-name "$NAME" \
  --db-parameter-group-family aurora-postgresql17 --description "$NAME" --tags "$TAG" >/dev/null
aws rds modify-db-cluster-parameter-group --region "$REGION" --db-cluster-parameter-group-name "$NAME" \
  --parameters "ParameterName=aurora_analytics.enabled,ParameterValue=true,ApplyMethod=immediate" >/dev/null
SG=$(aws ec2 create-security-group --region "$REGION" --group-name "$NAME" --description "$NAME" --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=security-group,Tags=[{$TAG}]" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG" --protocol tcp --port 5432 --cidr "$MY_IP/32" >/dev/null
echo "SG=$SG" >> lab.env

echo "aurora cluster (takes 10 to 15 minutes)"
aws rds create-db-cluster --region "$REGION" --db-cluster-identifier "$NAME" --engine aurora-postgresql \
  --engine-version "$ENGINE_VERSION" --master-username postgres --master-user-password "$PW" \
  --db-cluster-parameter-group-name "$NAME" --vpc-security-group-ids "$SG" --db-subnet-group-name "$SUBNET_GROUP" \
  --storage-encrypted --backup-retention-period 1 --tags "$TAG" >/dev/null
aws rds create-db-instance --region "$REGION" --db-instance-identifier "$NAME-1" --db-cluster-identifier "$NAME" \
  --engine aurora-postgresql --db-instance-class "$INSTANCE_CLASS" --publicly-accessible --tags "$TAG" >/dev/null

echo "test data: 60M rows in an Iceberg table, written by Athena"
run_athena() {
  local q
  q=$(aws athena start-query-execution --region "$REGION" --work-group "$NAME" \
    --query-string "$(sed -e "s/\${BUCKET}/$BUCKET/g" -e "s/\${GLUE_DB}/$GLUE_DB/g" "$1")" \
    --query QueryExecutionId --output text)
  while true; do
    s=$(aws athena get-query-execution --region "$REGION" --query-execution-id "$q" --query QueryExecution.Status.State --output text)
    case $s in SUCCEEDED) break ;; FAILED|CANCELLED) echo "athena query $1 $s"; exit 1 ;; esac
    sleep 5
  done
}
run_athena athena/01_create_bookings_history.sql

aws rds wait db-cluster-available --region "$REGION" --db-cluster-identifier "$NAME"
aws rds add-role-to-db-cluster --region "$REGION" --db-cluster-identifier "$NAME" \
  --feature-name AuroraAnalytics --role-arn "arn:aws:iam::$ACCOUNT_ID:role/$NAME-role"
aws rds wait db-instance-available --region "$REGION" --db-instance-identifier "$NAME-1"

HOST=$(aws rds describe-db-clusters --region "$REGION" --db-cluster-identifier "$NAME" --query 'DBClusters[0].Endpoint' --output text)
echo "PGHOST=$HOST" >> lab.env
echo "GLUE_TABLE_ARN=arn:aws:glue:$REGION:$ACCOUNT_ID:table/$GLUE_DB/bookings_history" >> lab.env
echo "done. next: ./run.sh sql/01_setup.sql"
