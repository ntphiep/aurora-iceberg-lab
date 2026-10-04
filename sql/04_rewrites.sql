\timing on
\echo == Q2 rewrite: extract month
SELECT extract(month FROM checkin_date) AS m, count(*), sum(room_rate * nights)
FROM bookings_history WHERE checkin_date >= DATE '2025-01-01' AND status = 'confirmed' GROUP BY 1 ORDER BY 1;
\echo == Q2 rewrite: daily aggregate in lake, monthly rollup in Postgres
SELECT date_trunc('month', d)::date AS month, sum(c) AS bookings, sum(r) AS revenue
FROM (SELECT checkin_date AS d, count(*) AS c, sum(room_rate * nights) AS r
      FROM bookings_history WHERE checkin_date >= DATE '2025-01-01' AND status = 'confirmed' GROUP BY 1) s
GROUP BY 1 ORDER BY 1;
\echo == Q3 plan (union)
EXPLAIN (VERBOSE) SELECT 'recent' AS source, count(*), round(avg(room_rate),2) FROM bookings_recent WHERE hotel_id = 42
UNION ALL
SELECT 'history', count(*), round(avg(room_rate),2) FROM bookings_history WHERE hotel_id = 42;
\echo == Q3 rewrite with materialized CTE
WITH h AS MATERIALIZED (SELECT count(*) AS c, round(avg(room_rate),2) AS a FROM bookings_history WHERE hotel_id = 42)
SELECT 'recent' AS source, count(*), round(avg(room_rate),2) FROM bookings_recent WHERE hotel_id = 42
UNION ALL SELECT 'history', c, a FROM h;
\echo == copy 2025 into a native table (the old way)
CREATE TABLE bookings_2025 AS SELECT * FROM bookings_history WHERE checkin_date >= DATE '2025-01-01';
CREATE INDEX ON bookings_2025 (checkin_date);
ANALYZE bookings_2025;
\echo == Q2 on native table
SELECT date_trunc('month', checkin_date)::date AS month, count(*), sum(room_rate * nights)
FROM bookings_2025 WHERE status = 'confirmed' GROUP BY 1 ORDER BY 1;
SELECT pg_size_pretty(pg_total_relation_size('bookings_2025')) AS native_size;
\echo == stat statements
SELECT * FROM aurora_analytics_stat_statements() LIMIT 0;
