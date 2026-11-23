-- Add the site lookup table used by Customers > Add Site.
-- Run once on an existing PostgreSQL database:
--   psql -d ledger -f sql/Pg-upgrade-add-site.sql

CREATE TABLE IF NOT EXISTS site (
  id int DEFAULT nextval('id'),
  site text
);

CREATE INDEX IF NOT EXISTS site_id_key ON site (id);
CREATE UNIQUE INDEX IF NOT EXISTS site_key ON site (site);
