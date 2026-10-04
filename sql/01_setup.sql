\timing on
SELECT version();
CREATE EXTENSION aurora_analytics;
\dx aurora_analytics
CREATE FOREIGN TABLE bookings_history ()
SERVER aurora_analytics_server
OPTIONS (location :'glue_table_arn');
\d bookings_history
-- operational tables that live in Postgres
CREATE TABLE hotels AS
SELECT g AS hotel_id, 'Hotel ' || g AS name,
       (ARRAY['Palma','Barcelona','Lisbon','London','Paris','Rome','Dubai','Bangkok'])[1 + g % 8] AS city
FROM generate_series(1, 5000) g;
ALTER TABLE hotels ADD PRIMARY KEY (hotel_id);
CREATE TABLE bookings_recent AS
SELECT 900000000000 + g AS booking_id, 1 + (random()*4999)::int AS hotel_id,
       'supplier_' || chr(97 + (random()*7)::int) AS supplier,
       DATE '2026-01-01' + (random()*270)::int AS checkin_date,
       1 + (random()*6)::int AS nights, round((40 + random()*360)::numeric, 2) AS room_rate,
       'EUR'::text AS currency, 'confirmed'::text AS status
FROM generate_series(1, 2000000) g;
CREATE INDEX ON bookings_recent (hotel_id);
ANALYZE hotels; ANALYZE bookings_recent;
