\timing on
\echo == count after an external Iceberg commit, same foreign table
SELECT count(*) FROM bookings_history;
SELECT count(*) FROM bookings_history WHERE checkin_date = DATE '2026-09-30';
\echo == stats for the lake queries
SELECT calls, round(mean_exec_time) AS mean_ms, analytics_total_rows_scanned AS rows_scanned,
       pg_size_pretty(analytics_remote_read_bytes) AS s3_read, pg_size_pretty(analytics_cache_hit_bytes) AS cache_hit,
       analytics_get_request_count AS s3_gets, left(regexp_replace(query, '\s+', ' ', 'g'), 70) AS query
FROM aurora_analytics_stat_statements() ORDER BY total_exec_time DESC LIMIT 8;
