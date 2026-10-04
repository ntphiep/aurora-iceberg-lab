#!/usr/bin/env bash
# Commits 1000 new rows to the Iceberg table through Athena, for sql/05_freshness.sql.
set -euo pipefail
. ./lab.env
q=$(aws athena start-query-execution --region "$REGION" --work-group "$NAME" \
  --query-string "$(sed -e "s/\${GLUE_DB}/$GLUE_DB/g" athena/02_insert_new_rows.sql)" --query QueryExecutionId --output text)
until [[ $(aws athena get-query-execution --region "$REGION" --query-execution-id "$q" --query QueryExecution.Status.State --output text) =~ SUCCEEDED|FAILED|CANCELLED ]]; do sleep 3; done
aws athena get-query-execution --region "$REGION" --query-execution-id "$q" --query QueryExecution.Status.State --output text
