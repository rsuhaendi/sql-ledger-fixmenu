-- Sales commission outstanding and cash payment
-- Replaces direct GL posting at Generate time with an outstanding record.
-- Existing accrual journals are preserved and flagged so they are not posted twice.

CREATE TABLE IF NOT EXISTS commission_payable (
  id             integer PRIMARY KEY DEFAULT nextval('id'),
  ar_id          integer NOT NULL UNIQUE,
  invnumber      text,
  employee_id    integer NOT NULL,
  gross          numeric(14,2) NOT NULL DEFAULT 0,
  deduction      numeric(14,2) NOT NULL DEFAULT 0,
  net            numeric(14,2) NOT NULL DEFAULT 0,
  transdate      date NOT NULL,
  accrual_posted boolean NOT NULL DEFAULT false,
  paid           numeric(14,2) NOT NULL DEFAULT 0,
  paid_date      date,
  payment_accno  text,
  payment_source text,
  payment_id     integer,
  gl_id          integer
);

ALTER TABLE commission_payable OWNER TO "sql-ledger";
GRANT ALL ON commission_payable TO "sql-ledger";

-- Backfill commissions that were already generated under the old flow.
-- Their 5480/2290/4490 accrual lines already exist in acc_trans.
INSERT INTO commission_payable
  (ar_id, invnumber, employee_id, gross, deduction, net,
   transdate, accrual_posted, paid)
SELECT a.id, a.invnumber, a.employee_id,
       a.commission_amount,
       a.commission_amount - a.commission_net,
       a.commission_net,
       COALESCE(a.datepaid, a.transdate),
       true,
       0
FROM ar a
WHERE a.commission_posted = true
  AND a.commission_net <> 0
  AND NOT EXISTS (SELECT 1 FROM commission_payable p WHERE p.ar_id = a.id);
