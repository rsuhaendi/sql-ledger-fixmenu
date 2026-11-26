-- Indonesian descriptions for the chart of accounts.
--
-- Only chart.description is changed. Account numbers (accno), chart type,
-- category, link, GIFI, contra, closed and all tax rates/links are left
-- untouched, so existing transactions and reports keep working.
--
-- Run once on an existing PostgreSQL database:
--   psql -d ledger -f sql/Pg-upgrade-chart-indonesian.sql

BEGIN;

UPDATE chart c
   SET description = v.description
  FROM (VALUES
    ('1000', 'AKTIVA LANCAR'),
    ('1060', 'Bank'),
    ('1065', 'Kas Kecil'),
    ('1200', 'Piutang'),
    ('1205', 'Cadangan Kerugian Piutang'),
    ('1500', 'PERSEDIAAN'),
    ('1520', 'Persediaan / Umum'),
    ('1530', 'Persediaan / Suku Cadang'),
    ('1800', 'AKTIVA TETAP'),
    ('1820', 'Perabot Kantor & Peralatan'),
    ('1825', 'Akumulasi Amortisasi Perabot & Peralatan'),
    ('1840', 'Kendaraan'),
    ('1845', 'Akumulasi Amortisasi Kendaraan'),
    ('2000', 'HUTANG LANCAR'),
    ('2100', 'Hutang Dagang'),
    ('2160', 'Hutang Pajak'),
    ('2190', 'Hutang Pajak Penghasilan'),
    ('2210', 'Hutang Asuransi Tenaga Kerja'),
    ('2220', 'Hutang Tunjangan Liburan'),
    ('2250', 'Hutang Rencana Pensiun'),
    ('2260', 'Hutang Asuransi Karyawan'),
    ('2280', 'Hutang Pajak Gaji'),
    ('2310', 'PPn (10%)'),
    ('2600', 'HUTANG JANGKA PANJANG'),
    ('2620', 'Hutang Bank'),
    ('2680', 'Hutang ke Pemegang Saham'),
    ('3300', 'MODAL'),
    ('3350', 'Modal Umum'),
    ('4000', 'PENDAPATAN PENJUALAN'),
    ('4020', 'Penjualan / Umum'),
    ('4030', 'Penjualan / Suku Cadang'),
    ('4300', 'PENDAPATAN JASA'),
    ('4320', 'Jasa Layanan Internet'),
    ('4400', 'PENDAPATAN LAIN'),
    ('4430', 'Jasa Pengiriman dan Pengepakan'),
    ('4440', 'Bunga'),
    ('4450', 'Keuntungan Selisih Kurs'),
    ('5000', 'BIAYA PENJUALAN'),
    ('5010', 'Pembelian'),
    ('5020', 'Harga Pokok Penjualan / Umum'),
    ('5030', 'Harga Pokok Penjualan / Suku Cadang'),
    ('5100', 'Ongkos Kirim'),
    ('5400', 'BIAYA GAJI'),
    ('5410', 'Biaya Gaji'),
    ('5420', 'Biaya Asuransi Karyawan'),
    ('5430', 'Biaya Rencana Pensiun'),
    ('5440', 'Biaya Asuransi Tenaga Kerja'),
    ('5470', 'Tunjangan Karyawan'),
    ('5600', 'BIAYA UMUM DAN ADMINISTRASI'),
    ('5610', 'Akunting dan Legalitas'),
    ('5615', 'Iklan dan Promosi'),
    ('5620', 'Biaya Piutang Tak Tertagih'),
    ('5650', 'Biaya Penyusutan Pajak'),
    ('5660', 'Biaya Amortisasi'),
    ('5680', 'Biaya Pajak Pendapatan'),
    ('5685', 'Asuransi'),
    ('5690', 'Biaya Bank dan Bunga'),
    ('5700', 'Biaya Keperluan Kantor'),
    ('5760', 'Biaya Sewa'),
    ('5765', 'Reparasi dan Pemeliharaan'),
    ('5780', 'Telepon'),
    ('5785', 'Perjalanan dan Hiburan'),
    ('5790', 'Utilitas'),
    ('5795', 'Registrasi'),
    ('5800', 'Lisensi'),
    ('5810', 'Rugi Selisih Kurs')
  ) AS v(accno, description)
 WHERE c.accno = v.accno
   AND c.description <> v.description;

COMMIT;
