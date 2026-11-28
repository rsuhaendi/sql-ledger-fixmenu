-- Samakan currency vendor dengan mata uang yang masih terkonfigurasi.
-- Vendor lama bisa menyimpan USD walaupun tabel curr hanya berisi IDR,
-- sehingga form AP menampilkan field Exchange Rate (currency dropdown tetap
-- IDR). Aman dijalankan ulang.

UPDATE vendor v
   SET curr = (SELECT c.curr FROM curr c ORDER BY c.rn LIMIT 1)
 WHERE v.curr IS NOT NULL
   AND btrim(v.curr) <> ''
   AND NOT EXISTS (SELECT 1 FROM curr c WHERE btrim(c.curr) = btrim(v.curr));
