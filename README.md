# SQL-Ledger (Fork fixmenu) - Panduan Instalasi & Migrasi

Repository ini adalah fork SQL-Ledger 3.2.x dengan penyesuaian operasional (menu fix, Sales Commission, Payment Commission, ekspor/import customer, template invoice ISP, dll). Panduan ini ditulis agar orang awam bisa install server baru atau migrasi dari server lama.

> **Penting:** Setelah deploy/update file web, selalu minta user melakukan **Ctrl+F5** (hard refresh browser).

## 1. Isi Repository

Yang **di-backup di Git** (aman untuk repo):
- Kode aplikasi SQL-Ledger (`*.pl`, `SL/*.pm`, `bin/`, `locale/`, dll).
- Template/report (`templates/` yang relevan; beberapa template di-track dengan force karena `.gitignore` default SQL-Ledger).
- Skema/migrasi SQL (`sql/*.sql`), termasuk migrasi custom fitur ini.
- Konfigurasi contoh: `sql-ledger.conf.example`, `sql-ledger-httpd.conf.example`, `config/examples/*`.
- Script bantu: `scripts/install-ubuntu.sh`, `scripts/backup.sh`, `scripts/restore.sh`.

Yang **tidak boleh di-commit ke Git publik** (berisi password/rahasia):
- `sql-ledger.conf` (konfigurasi site lokal).
- `users/members` (daftar user, password crypt, password DB terenkripsi).
- `users/*.conf` (konfigurasi per user/session).
- Backup database (`*.dump`, `*.sql` hasil dump data produksi).
- File credential internal seperti `/image/userpass.txt` atau token/password lain.

`.gitignore` sudah mengabaikan file sensitif utama di atas. Jangan paksa `git add -f` untuk file credential.

## 2. Kebutuhan Server (Ubuntu/Debian)

Paket minimum:
- Apache2 + mod_cgi
- PostgreSQL
- Perl + DBI + DBD::Pg
- LaTeX/TeX Live (untuk PDF/PostScript/cek/invoice template)
- git

Contoh paket Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y apache2 postgresql postgresql-contrib \
  perl libdbi-perl libdbd-pg-perl libmail-sendmail-perl \
  texlive-latex-base texlive-latex-extra texlive-fonts-recommended \
  texlive-lang-other texlive-xetex fonts-dejavu git
sudo a2enmod cgi
```

## 3. Instalasi Baru (Server Kosong)

### Opsi A - Script cepat

```bash
cd /
sudo git clone --branch fixmenu https://github.com/rsuhaendi/sql-ledger-fixmenu.git /sql-ledger
cd /sql-ledger
sudo DB_NAME=ledger DB_USER=sql-ledger DB_PASS='PasswordKuatAnda' bash scripts/install-ubuntu.sh
```

Script akan install paket, setup Apache conf, buat role/database PostgreSQL, dan set permission dasar.

### Opsi B - Manual (disarankan untuk paham)

1. **Clone repo**
   ```bash
   sudo git clone --branch fixmenu https://github.com/rsuhaendi/sql-ledger-fixmenu.git /sql-ledger
   cd /sql-ledger
   ```

2. **Buat config site**
   ```bash
   sudo cp sql-ledger.conf.default sql-ledger.conf
   ```
   Edit `sql-ledger.conf` bila perlu (path sendmail, latex, dll). File ini jangan di-commit.

3. **Permission direktori runtime**
   ```bash
   sudo mkdir -p users templates spool
   sudo chown -R www-data:www-data /sql-ledger
   sudo chmod 711 /sql-ledger/users /sql-ledger/templates /sql-ledger/spool
   ```

4. **Apache config**
   ```bash
   sudo cp config/examples/sql-ledger-apache.conf /etc/apache2/conf-available/sql-ledger.conf
   sudo a2enconf sql-ledger
   sudo a2enmod cgi
   sudo systemctl reload apache2
   ```

5. **PostgreSQL role & database**
   ```bash
   sudo -u postgres psql -c "CREATE ROLE \"sql-ledger\" WITH LOGIN PASSWORD 'PasswordKuatAnda';"
   sudo -u postgres psql -c "CREATE DATABASE ledger OWNER \"sql-ledger\" ENCODING 'UTF8' TEMPLATE template0;"
   ```

6. **Akses awal**
   - Buka: `http://SERVER/sql-ledger/admin.pl`
   - **Segera set password admin**. Sebelum password diset, `admin.pl` berisiko jika terbuka publik.
   - Buat dataset/login user dari admin.pl, arahkan ke DB `ledger`, user `sql-ledger`, password DB yang tadi dibuat.
   - Login normal: `http://SERVER/sql-ledger/login.pl`

## 4. Migrasi ke Server Baru (Pindah Server)

Gunakan ini jika sudah ada data produksi.

### Di server lama

1. **Backup database PostgreSQL**
   ```bash
   sudo -u postgres pg_dump -Fc ledger > /tmp/ledger.dump
   ```

2. **Backup file penting SQL-Ledger**
   ```bash
   cd /sql-ledger
   sudo tar -czf /tmp/sql-ledger-files.tar.gz \
     sql-ledger.conf users templates spool images menu.ini
   ```
   > File ini berisi credential. Simpan aman, jangan upload ke repo publik.

3. **Opsional: backup full repo state**
   ```bash
   cd /sql-ledger
   git status
   git log --oneline -5
   ```
   Pastikan semua perubahan penting sudah di-push ke branch `fixmenu`.

### Di server baru

1. Install SQL-Ledger dari Git (bagian 3).
2. Restore DB:
   ```bash
   sudo -u postgres dropdb --if-exists ledger
   sudo -u postgres createdb -O "sql-ledger" -E UTF8 -T template0 ledger
   sudo -u postgres pg_restore -d ledger --no-owner --role="sql-ledger" /tmp/ledger.dump
   ```
3. Restore file config/user/template:
   ```bash
   sudo tar -xzf /tmp/sql-ledger-files.tar.gz -C /sql-ledger
   sudo chown -R www-data:www-data /sql-ledger
   sudo chmod 711 /sql-ledger/users /sql-ledger/templates /sql-ledger/spool
   ```
4. Cek `sql-ledger.conf`, Apache conf, dan koneksi DB.
5. Jalankan migrasi SQL custom yang belum ada di DB lama (lihat bagian 5).
6. Reload Apache dan test login.

## 5. Migrasi SQL Fitur Custom (Penting)

Untuk database lama yang belum punya fitur custom repo ini, jalankan SQL yang diperlukan. Cek dulu sebelum eksekusi.

Lokasi: `sql/`

Migrasi custom yang umum:
- `Pg-upgrade-sales-commission.sql` - tabel/kolom commission dasar.
- `Pg-upgrade-commission-payment.sql` - tabel `commission_payable` / payment commission.
- `Pg-upgrade-commission-employee-deduction.sql` - kolom `employee.commission_deduction` (prospektif).
- `Pg-upgrade-commission-salesperson-import.sql` - koreksi salesperson invoice import lama yang terisi user login.
- `Pg-upgrade-customer-network-fields.sql` / `Pg-upgrade-customer-isp-status.sql` / `Pg-upgrade-contact-ktp.sql` / `Pg-upgrade-add-site.sql` / `Pg-upgrade-register-customer-sites.sql` - field customer/site sesuai kebutuhan.

Contoh menjalankan:

```bash
sudo -u postgres psql -d ledger -f sql/Pg-upgrade-commission-employee-deduction.sql
```

Aturan aman:
- Backup DB dulu.
- Jalankan di jam sepi.
- Baca isi file SQL sebelum run.
- Jika migrasi sudah pernah dijalankan, sebagian sudah idempotent (`IF NOT EXISTS`), tapi tetap cek hasilnya.

## 6. Fitur Custom di Fork Ini

- **Sales Commission**: `AR → Reports → Sales Commission`. Deduction % per Employee (prospektif, transaksi/komisi berikutnya). Layout report compact.
- **Payment Commission**: `Cash → Payment Commission` (bayar hutang komisi, idempotent, pakai `glnumber`).
- **Commission aging/outstanding**: baris komisi tampil di AP Outstanding/AP Aging sebagai display; settlement tetap via Payment Commission.
- **Template invoice ISP**: wording invoice disesuaikan untuk layanan internet, bukan retur barang fisik.
- **Num2text Indonesia**: terbilang amount-in-words Bahasa Indonesia, kapital di awal kata.

## 7. Backup Rutin

Gunakan script:

```bash
sudo APP_DIR=/sql-ledger DB_NAME=ledger OUT_DIR=/var/backups/sql-ledger bash scripts/backup.sh
```

Isi backup:
- Dump DB PostgreSQL (`ledger.dump`)
- `sql-ledger.conf`, `users/`, `templates/`, `spool/`, `menu.ini`, `config/`, `scripts/`, `sql/`

Simpan backup di lokasi aman (terenkripsi/offsite). Jangan commit backup ke Git.

Restore:

```bash
sudo bash scripts/restore.sh /var/backups/sql-ledger/YYYYMMDD-HHMMSS
```

## 8. Update dari Git

```bash
cd /sql-ledger
sudo git pull origin fixmenu
sudo chown -R www-data:www-data /sql-ledger
sudo systemctl reload apache2
```

Lalu cek apakah ada migrasi SQL baru di `sql/`. Setelah update, user harus **Ctrl+F5**.

## 9. Troubleshooting Cepat

- **Layar blank/error Perl**: cek `/var/log/apache2/error.log`.
- **Permission denied users/templates/spool**: pastikan owner `www-data:www-data` dan mode `711`.
- **Tidak bisa connect DB**: cek `sql-ledger.conf`, `users/members`, `pg_hba.conf`, password role PostgreSQL.
- **PDF/LaTeX tidak keluar**: pastikan paket texlive terpasang dan `latex=1` di `sql-ledger.conf`.
- **Perubahan UI tidak muncul**: minta user **Ctrl+F5**.
- **admin.pl terbuka publik**: set password admin dan batasi akses via Apache/firewall/VPN.

## 10. Checklist Keamanan

- Ganti semua password default/admin/DB.
- Jangan commit `users/members`, `users/*.conf`, `sql-ledger.conf`, dump DB.
- Batasi akses `admin.pl` sampai password diset.
- Pakai HTTPS (Let's Encrypt/cert internal).
- Batasi `/sql-ledger/users`, `/sql-ledger/templates`, `/sql-ledger/spool`, `.git` dari HTTP (lihat contoh Apache conf).
- Backup rutin dan uji restore.

## 11. Lisensi

SQL-Ledger adalah software GPL. Lihat `doc/COPYING` dan `doc/COPYRIGHT`.
