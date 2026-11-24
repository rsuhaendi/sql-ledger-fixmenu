-- Pindahkan No. KTP dari contact.title ke kolom khusus contact.ktp.
-- Bug sebelumnya: No. KTP disimpan di contacttitle sehingga field Title ikut terisi.

ALTER TABLE contact ADD COLUMN IF NOT EXISTS ktp varchar(64);

-- Pindahkan nilai yang jelas-jelas berupa NIK (16 digit) ke ktp.
UPDATE contact
   SET ktp = contacttitle
 WHERE contacttitle ~ '^[0-9]{16}$'
   AND (ktp IS NULL OR ktp = '')
   AND trans_id IN (SELECT id FROM customer);

-- Kosongkan Title untuk customer yang datanya sudah dipindahkan.
UPDATE contact
   SET contacttitle = NULL
 WHERE contacttitle ~ '^[0-9]{16}$'
   AND trans_id IN (SELECT id FROM customer);
