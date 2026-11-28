-- Bersihkan employee dummy "--" hasil import customer lama.
-- Salesperson kosong/"--" pernah disimpan sebagai employee bernama "--",
-- sehingga customer tidak punya salesperson yang valid dan nama "--" muncul
-- di dropdown Sales Commission (report jadi kosong saat dipilih).
-- Aman dijalankan ulang.

BEGIN;

-- Pulihkan salesperson dari invoice customer bila masih bisa ditentukan.
UPDATE customer c
   SET employee_id = (
         SELECT a.employee_id
           FROM ar a
          WHERE a.customer_id = c.id
            AND a.invoice = true
            AND a.employee_id IS NOT NULL
            AND a.employee_id <> 0
            AND EXISTS (SELECT 1 FROM employee e
                         WHERE e.id = a.employee_id
                           AND e.name <> '--')
          ORDER BY a.transdate DESC, a.id DESC
          LIMIT 1
       )
 WHERE c.employee_id IN (SELECT id FROM employee WHERE name = '--')
   AND EXISTS (
     SELECT 1 FROM ar a
      WHERE a.customer_id = c.id
        AND a.invoice = true
        AND a.employee_id IS NOT NULL
        AND a.employee_id <> 0
        AND EXISTS (SELECT 1 FROM employee e
                     WHERE e.id = a.employee_id
                       AND e.name <> '--')
   );

-- Sisanya memang tidak punya salesperson valid: set ke 0 (kosong).
UPDATE customer c
   SET employee_id = 0
 WHERE c.employee_id IN (SELECT id FROM employee WHERE name = '--');

DELETE FROM employee
 WHERE name = '--'
   AND NOT EXISTS (SELECT 1 FROM customer WHERE employee_id = employee.id)
   AND NOT EXISTS (SELECT 1 FROM ar WHERE employee_id = employee.id)
   AND NOT EXISTS (SELECT 1 FROM ap WHERE employee_id = employee.id)
   AND NOT EXISTS (SELECT 1 FROM commission_payable WHERE employee_id = employee.id);

COMMIT;
