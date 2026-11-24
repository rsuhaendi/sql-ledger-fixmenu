-- Tambahkan kolom Status ISP ke tabel customer.
-- Dipakai sebagai placeholder kolom laporan; logika pengisian menyusul.

ALTER TABLE customer ADD COLUMN IF NOT EXISTS isp_status varchar(32);
