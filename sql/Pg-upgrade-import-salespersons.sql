-- Register salespersons left in staged customer imports and link them to the
-- imported customers. This repairs imports where the Salesperson value was not
-- found in the employee master and was therefore saved without a link.
-- Run once on an existing PostgreSQL database:
--   psql -d ledger -f sql/Pg-upgrade-import-salespersons.sql

INSERT INTO employee (name, sales)
SELECT DISTINCT btrim(rv.reportvalue), true
FROM reportvars rv
JOIN report r ON (r.reportid = rv.reportid)
WHERE r.reportcode = 'import_customer'
  AND rv.reportvariable LIKE 'employee\_%'
  AND btrim(rv.reportvalue) <> ''
  AND NOT EXISTS (
    SELECT 1
    FROM employee e
    WHERE lower(e.name) = lower(btrim(rv.reportvalue))
  );

UPDATE customer c
SET employee_id = e.id
FROM reportvars rv
JOIN report r ON (r.reportid = rv.reportid)
JOIN employee e ON (lower(e.name) = lower(btrim(rv.reportvalue)))
WHERE r.reportcode = 'import_customer'
  AND rv.reportvariable LIKE 'employee\_%'
  AND btrim(rv.reportvalue) <> ''
  AND c.customernumber = (
    SELECT cn.reportvalue
    FROM reportvars cn
    WHERE cn.reportid = rv.reportid
      AND cn.reportvariable = 'customernumber_' || split_part(rv.reportvariable, '_', 2)
  );
