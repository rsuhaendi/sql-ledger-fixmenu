-- Split customer coordinate into latitude/longitude and add PPN export support helper
ALTER TABLE customer ADD COLUMN IF NOT EXISTS latitude double precision;
ALTER TABLE customer ADD COLUMN IF NOT EXISTS longitude double precision;

-- Best-effort split existing "lat, long" coordinate values
UPDATE customer
SET latitude = NULLIF(split_part(replace(coordinate, ' ', ''), ',', 1), '')::double precision,
    longitude = NULLIF(split_part(replace(coordinate, ' ', ''), ',', 2), '')::double precision
WHERE coordinate IS NOT NULL
  AND coordinate LIKE '%,%'
  AND latitude IS NULL
  AND longitude IS NULL
  AND split_part(replace(coordinate, ' ', ''), ',', 1) ~ '^-?[0-9]+(\.[0-9]+)?$'
  AND split_part(replace(coordinate, ' ', ''), ',', 2) ~ '^-?[0-9]+(\.[0-9]+)?$';
