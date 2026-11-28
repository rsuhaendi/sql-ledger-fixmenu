-- Perbaiki salesperson invoice hasil import lama.
-- Import lama kadang mengisi employee_id dengan user login (salesperson
-- kosong), sehingga komisi tampil di bawah nama user tersebut.
-- Aman dijalankan ulang: hanya baris yang masih salah yang berubah.

UPDATE ar a
   SET employee_id = CASE
         WHEN e.sales = true AND e.commission_amount > 0 THEN e.id
         ELSE 0
       END
  FROM customer cu
  LEFT JOIN employee e ON (e.id = cu.employee_id)
 WHERE a.invoice = true
   AND cu.id = a.customer_id
   AND a.employee_id <> 0
   AND NOT EXISTS (
     SELECT 1 FROM employee old
      WHERE old.id = a.employee_id
        AND old.sales = true
        AND old.commission_amount > 0
   )
   AND a.employee_id IS DISTINCT FROM
       CASE WHEN e.sales = true AND e.commission_amount > 0 THEN e.id ELSE 0 END;
