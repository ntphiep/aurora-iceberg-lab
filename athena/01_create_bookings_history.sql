CREATE TABLE ${GLUE_DB}.bookings_history
WITH (table_type='ICEBERG', location='s3://${BUCKET}/iceberg/bookings_history/', is_external=false, format='PARQUET', partitioning=ARRAY['month(checkin_date)'])
AS
SELECT
  CAST(a.x AS BIGINT) * 10000 + b.y AS booking_id,
  CAST(1 + floor(rand() * 5000) AS INTEGER) AS hotel_id,
  element_at(ARRAY['supplier_a','supplier_b','supplier_c','supplier_d','supplier_e','supplier_f','supplier_g','supplier_h'], CAST(1 + floor(rand()*8) AS INTEGER)) AS supplier,
  date_add('day', CAST(floor(rand() * 1096) AS INTEGER), DATE '2023-01-01') AS checkin_date,
  CAST(1 + floor(rand() * 7) AS INTEGER) AS nights,
  CAST(round(40 + rand() * 360, 2) AS DECIMAL(10,2)) AS room_rate,
  element_at(ARRAY['EUR','GBP','USD'], CAST(1 + floor(rand()*3) AS INTEGER)) AS currency,
  element_at(ARRAY['confirmed','confirmed','confirmed','cancelled','no_show'], CAST(1 + floor(rand()*5) AS INTEGER)) AS status
FROM UNNEST(sequence(1, 6000)) AS a(x)
CROSS JOIN UNNEST(sequence(1, 10000)) AS b(y)
