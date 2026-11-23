-- Add network / ISP billing fields to the customer table.
-- Run once on an existing PostgreSQL database:
--   psql -d ledger -f sql/Pg-upgrade-customer-network-fields.sql

ALTER TABLE customer ADD COLUMN IF NOT EXISTS site text;
ALTER TABLE customer ADD COLUMN IF NOT EXISTS coordinate varchar(100);
ALTER TABLE customer ADD COLUMN IF NOT EXISTS odp_location text;
ALTER TABLE customer ADD COLUMN IF NOT EXISTS pon varchar(64);
ALTER TABLE customer ADD COLUMN IF NOT EXISTS cable_length varchar(32);
ALTER TABLE customer ADD COLUMN IF NOT EXISTS signal_dbm varchar(32);
ALTER TABLE customer ADD COLUMN IF NOT EXISTS device_type varchar(64);
ALTER TABLE customer ADD COLUMN IF NOT EXISTS ip_address varchar(64);
ALTER TABLE customer ADD COLUMN IF NOT EXISTS pppoe_username varchar(64);
ALTER TABLE customer ADD COLUMN IF NOT EXISTS pppoe_password varchar(64);
ALTER TABLE customer ADD COLUMN IF NOT EXISTS bandwidth varchar(32);
ALTER TABLE customer ADD COLUMN IF NOT EXISTS registration_fee varchar(32);
ALTER TABLE customer ADD COLUMN IF NOT EXISTS monthly_fee varchar(32);
ALTER TABLE customer ADD COLUMN IF NOT EXISTS billing_type varchar(16);
