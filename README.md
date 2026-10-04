# aurora-iceberg-lab

A small lab for the Aurora PostgreSQL feature that queries Iceberg and Parquet data in S3 directly
([announcement](https://aws.amazon.com/blogs/aws/amazon-aurora-postgresql-now-supports-direct-querying-of-apache-iceberg-and-parquet-data-in-your-data-lake/),
[docs](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-analytics-prerequisites.html)).

The setup is one Aurora PostgreSQL 17.11 instance (db.r8g.large) and a 60M-row Iceberg table of
synthetic bookings, written by Athena and registered in the Glue Data Catalog. Postgres also holds two
normal tables, `hotels` (5,000 rows) and `bookings_recent` (2M rows), so local and lake data can be joined.

## What I found

| Query | Time |
|---|---|
| `count(*)` over 60M rows | 0.55 s cold, 0.31 s warm |
| Monthly report grouped by `date_trunc('month', ...)` | 6.1 s |
| Same report grouped by `extract(month FROM ...)` | 0.6 s |
| One hotel, `UNION ALL` of a local table and the lake table | 9.3 s |
| Same, with the lake side in a `MATERIALIZED` CTE | 0.9 s |
| Copy one year (20M rows) into a normal Postgres table | 80 s, 1.7 GB |
| Monthly report on that copied table | 3.6 s |

The whole Iceberg table (60M rows) is 389 MiB in S3.

Most of the difference comes from pushdown. Scans run on an embedded DuckDB engine. If every
expression in the query can be pushed down, DuckDB does the filtering and the aggregation and returns a
few rows. If one expression can't, Postgres gets the filtered rows back and aggregates them itself.
`date_trunc` is one of those expressions. `EXPLAIN (VERBOSE)` lists them under
"Unsupported Pushdown Expressions", see `results/03_pushdown.out`.

Two other things worth knowing:

- Schema inference worked from the Glue table ARN, no column list needed.
- A new commit to the Iceberg table (1,000 rows inserted by Athena) was visible on the next query,
  without recreating the foreign table.

These numbers are from one instance and synthetic data. Treat them as relative, not as a benchmark.

## Running it

You need the AWS CLI with permissions for RDS, IAM, S3, Glue and Athena, a default VPC in the region,
and either `psql` or Docker.

```bash
./setup.sh                       # about 15 minutes, writes lab.env
./run.sh sql/01_setup.sql        # extension, foreign table, local tables
./run.sh sql/02_queries.sql
./run.sh sql/03_pushdown.sql
./run.sh sql/04_rewrites.sql
./insert_rows.sh                 # new Iceberg commit through Athena
./run.sh sql/05_freshness.sql
./teardown.sh                    # deletes everything setup.sh created
```

`setup.sh` opens port 5432 only to your current public IP. Settings such as `REGION`, `NAME` and
`INSTANCE_CLASS` can be overridden with environment variables.

The instance is billed per hour, so run `teardown.sh` when you are done.

## Layout

```
setup.sh, teardown.sh     create and delete the AWS resources
run.sh, insert_rows.sh    run a SQL file, add an Iceberg commit
iam-policy.json           read access to the bucket and the Glue table
athena/                   SQL that generates and appends the Iceberg data
sql/                      the Postgres side
results/                  output of my run
```
