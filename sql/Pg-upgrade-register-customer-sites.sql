-- Register sites already stored on customer records in the Site lookup table.
-- This makes previously imported customer sites appear in Customers > Tampilkan Site
-- and in the Add Customer site dropdown.
-- Run once on an existing PostgreSQL database:
--   psql -d ledger -f sql/Pg-upgrade-register-customer-sites.sql

INSERT INTO site (site)
SELECT DISTINCT btrim(c.site)
FROM customer c
WHERE c.site IS NOT NULL
  AND btrim(c.site) <> ''
  AND NOT EXISTS (
    SELECT 1
    FROM site s
    WHERE s.site = btrim(c.site)
  );
