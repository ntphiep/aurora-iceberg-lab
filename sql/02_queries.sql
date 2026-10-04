\timing on
\echo == Q1 count, cold
SELECT count(*) FROM bookings_history;
\echo == Q1 count, again
SELECT count(*) FROM bookings_history;
\echo == Q2 monthly revenue 2025, cold
SELECT date_trunc('month', checkin_date)::date AS month, count(*) AS bookings, sum(room_rate * nights) AS revenue
FROM bookings_history WHERE checkin_date >= DATE '2025-01-01' AND status = 'confirmed'
GROUP BY 1 ORDER BY 1;
\echo == Q2 again
SELECT date_trunc('month', checkin_date)::date AS month, count(*) AS bookings, sum(room_rate * nights) AS revenue
FROM bookings_history WHERE checkin_date >= DATE '2025-01-01' AND status = 'confirmed'
GROUP BY 1 ORDER BY 1;
\echo == Q3 one hotel, history + recent
SELECT 'recent' AS source, count(*), round(avg(room_rate),2) AS avg_rate FROM bookings_recent WHERE hotel_id = 42
UNION ALL
SELECT 'history', count(*), round(avg(room_rate),2) FROM bookings_history WHERE hotel_id = 42;
\echo == Q4 join lake with local hotels table
SELECT h.city, count(*) AS bookings, round(sum(b.room_rate * b.nights)) AS revenue
FROM bookings_history b JOIN hotels h USING (hotel_id)
WHERE b.checkin_date BETWEEN DATE '2025-06-01' AND DATE '2025-08-31'
GROUP BY h.city ORDER BY revenue DESC;
\echo == Q4 plan
EXPLAIN (VERBOSE) SELECT h.city, count(*) FROM bookings_history b JOIN hotels h USING (hotel_id)
WHERE b.checkin_date BETWEEN DATE '2025-06-01' AND DATE '2025-08-31' GROUP BY h.city;
