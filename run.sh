#!/usr/bin/env bash
# Runs a SQL file against the lab cluster. Uses local psql if present, otherwise the postgres:17 image.
set -euo pipefail
set -a; . ./lab.env; set +a
CONN="host=$PGHOST dbname=postgres user=postgres sslmode=require"
if command -v psql >/dev/null; then
  psql "$CONN" -v glue_table_arn="$GLUE_TABLE_ARN" -f "$1"
else
  docker run --rm -e PGPASSWORD -v "$PWD:/w" -w /w postgres:17 psql "$CONN" -v glue_table_arn="$GLUE_TABLE_ARN" -f "$1"
fi
