-- Akun Prive untuk pengambilan uang oleh pemilik.
-- Akun ekuitas kontra: saldo normal debit, mengurangi ekuitas.
-- Cara pakai: transaksi GL -> Debit 3400 Prive / Credit 1015 Kas Rupiah.

INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, contra, closed)
SELECT '3400', 'Prive', 'A', 'Q', '', '', true, false
WHERE NOT EXISTS (SELECT 1 FROM chart WHERE accno = '3400');
