-- Sales commission per paid invoice
-- Adds per-salesperson fixed commission, configurable deduction and GL accounts.

ALTER TABLE employee ADD COLUMN commission_amount numeric(14,2) NOT NULL DEFAULT 0;

ALTER TABLE ar ADD COLUMN commission_amount numeric(14,2) NOT NULL DEFAULT 0;
ALTER TABLE ar ADD COLUMN commission_deduction numeric(5,2) NOT NULL DEFAULT 10;
ALTER TABLE ar ADD COLUMN commission_net numeric(14,2) NOT NULL DEFAULT 0;
ALTER TABLE ar ADD COLUMN commission_posted boolean NOT NULL DEFAULT false;

INSERT INTO defaults (fldname, fldvalue)
SELECT 'commission_deduction', '10'
WHERE NOT EXISTS (SELECT 1 FROM defaults WHERE fldname = 'commission_deduction');

INSERT INTO chart (accno, description, charttype, category, link)
SELECT '5480', 'Biaya Komisi', 'E', 'E', ''
WHERE NOT EXISTS (SELECT 1 FROM chart WHERE accno = '5480');

INSERT INTO chart (accno, description, charttype, category, link)
SELECT '2290', 'Hutang Komisi', 'L', 'L', ''
WHERE NOT EXISTS (SELECT 1 FROM chart WHERE accno = '2290');

INSERT INTO chart (accno, description, charttype, category, link)
SELECT '4490', 'Pendapatan Potongan Komisi', 'I', 'I', ''
WHERE NOT EXISTS (SELECT 1 FROM chart WHERE accno = '4490');
