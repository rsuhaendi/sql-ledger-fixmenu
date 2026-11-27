-- Move the sales-commission deduction percentage to the employee record.
-- Safe to run more than once.

ALTER TABLE employee ADD COLUMN IF NOT EXISTS commission_deduction numeric(5,2) NOT NULL DEFAULT 10;

UPDATE employee
   SET commission_deduction = 10
 WHERE commission_deduction IS NULL
    OR commission_deduction < 0
    OR commission_deduction > 100;

-- Keep the old global setting as the starting value for existing salespeople.
UPDATE employee
   SET commission_deduction = CASE
         WHEN (SELECT fldvalue FROM defaults WHERE fldname = 'commission_deduction') ~ '^\d+(\.\d+)?$'
          AND (SELECT fldvalue FROM defaults WHERE fldname = 'commission_deduction')::numeric BETWEEN 0 AND 100
         THEN (SELECT fldvalue FROM defaults WHERE fldname = 'commission_deduction')::numeric
         ELSE 10
       END
 WHERE commission_deduction = 10;
