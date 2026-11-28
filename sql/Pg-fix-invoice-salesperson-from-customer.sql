-- Isi salesperson invoice yang kosong dari salesperson customer.
-- Dipakai saat invoice dibuat tanpa salesperson eksplisit (misalnya user login
-- bukan employee), supaya komisi tetap masuk ke salesperson customer.
-- Aman dijalankan ulang.

UPDATE ar a
   SET employee_id = e.id
  FROM customer c
  JOIN employee e ON (e.id = c.employee_id)
 WHERE a.customer_id = c.id
   AND a.invoice = true
   AND (a.employee_id IS NULL OR a.employee_id = 0)
   AND e.sales = true
   AND e.commission_amount > 0
   AND a.employee_id IS DISTINCT FROM e.id;
