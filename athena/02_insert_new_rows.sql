INSERT INTO ${GLUE_DB}.bookings_history
SELECT 700000000000 + y, CAST(1 + floor(rand()*5000) AS INTEGER), 'supplier_a', DATE '2026-09-30', 2, CAST(120.00 AS DECIMAL(10,2)), 'EUR', 'confirmed'
FROM UNNEST(sequence(1, 1000)) AS t(y)
