\timing on
\echo == Q2 plan
EXPLAIN (VERBOSE) SELECT date_trunc('month', checkin_date)::date, count(*), sum(room_rate * nights)
FROM bookings_history WHERE checkin_date >= DATE '2025-01-01' AND status = 'confirmed' GROUP BY 1;
\echo == Q2 without status filter
SELECT count(*), sum(room_rate * nights) FROM bookings_history WHERE checkin_date >= DATE '2025-01-01';
\echo == Q2 with COLLATE "C"
SELECT count(*), sum(room_rate * nights) FROM bookings_history WHERE checkin_date >= DATE '2025-01-01' AND status = 'confirmed' COLLATE "C";
\echo == Q2 plan with COLLATE "C"
EXPLAIN (VERBOSE) SELECT count(*), sum(room_rate * nights) FROM bookings_history WHERE checkin_date >= DATE '2025-01-01' AND status = 'confirmed' COLLATE "C";
\echo == Q2 default collation, same shape
SELECT count(*), sum(room_rate * nights) FROM bookings_history WHERE checkin_date >= DATE '2025-01-01' AND status = 'confirmed';
\echo == Q3 history part alone
SELECT count(*), round(avg(room_rate),2) FROM bookings_history WHERE hotel_id = 42;
EXPLAIN (VERBOSE) SELECT count(*), round(avg(room_rate),2) FROM bookings_history WHERE hotel_id = 42;
