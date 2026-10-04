\set QUIET on
\pset footer off
\timing on
\echo '-- 1) date_trunc() cannot be pushed down, so Postgres aggregates 12M rows itself'
SELECT date_trunc('month', checkin_date)::date AS month, count(*) AS bookings
FROM bookings_history
WHERE checkin_date >= '2025-01-01' AND status = 'confirmed'
GROUP BY 1 ORDER BY 1 LIMIT 3;
\echo '-- 2) extract() is pushed down, so the embedded DuckDB engine does the work'
SELECT extract(month FROM checkin_date) AS month, count(*) AS bookings
FROM bookings_history
WHERE checkin_date >= '2025-01-01' AND status = 'confirmed'
GROUP BY 1 ORDER BY 1 LIMIT 3;
