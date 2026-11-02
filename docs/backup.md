# Backup database harian

`scripts/backup-db.mjs` mem-backup **database** (pg_dump, format custom) dan **folder `storage/`** (foto produk & profil)
ke satu folder per tanggal:

```
~/backup-database/
├── 2026-10-26/   database.dump  storage.tar.gz  SHA256SUMS  INFO.txt
├── 2026-10-27/
└── 2026-10-28/
```

- Dijalankan otomatis oleh **PM2 setiap pukul 02.00** (waktu server), lewat entri `dompet-backup` di
  `ecosystem.config.cjs`. Tidak memakai crontab.
- Disimpan **3 hari terakhir**: saat backup hari ke-4 selesai, backup hari ke-1 dihapus.
- Backup lama baru dihapus **setelah** backup baru berhasil dan terverifikasi (`pg_restore --list`). Kalau backup gagal (mis. database mati), tidak ada yang dihapus dan log PM2 mencatat `GAGAL`.
- Folder dan isinya hanya bisa dibaca pemilik (izin 700/600), karena berisi data usaha dan hash password.
- Hanya folder bernama tanggal (`YYYY-MM-DD`) yang pernah dihapus.

Pengaturan opsional lewat environment: `BACKUP_DIR` (folder backup), `BACKUP_KEEP` (jumlah hari, bawaan 3),
`PG_BIN` (folder `pg_dump`).

## 1. Pasang pg_dump (sekali)

`pg_dump` harus versi yang sama atau lebih baru dari server database. Server bawaan aplikasi (embedded) adalah
PostgreSQL 18, sedangkan Ubuntu 24.04 hanya menyediakan versi 16. Pasang versi 18 dari repositori resmi PostgreSQL:

```bash
sudo apt install -y postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
sudo apt install -y postgresql-client-18
/usr/lib/postgresql/18/bin/pg_dump --version      # pg_dump (PostgreSQL) 18.x
```

Server dengan PostgreSQL sistem (mis. versi 16) cukup memakai `pg_dump` bawaannya.

## 2. Coba sekali secara manual

```bash
cd <folder aplikasi>
npm run backup
ls ~/backup-database
```

Hasil yang benar diawali `OK <tanggal>: database … MB (… tabel)`.

## 3. Jadwalkan pukul 02.00 lewat PM2

```bash
cd <folder aplikasi>
pm2 start ecosystem.config.cjs --only dompet-backup
pm2 save
```

- Saat perintah ini dijalankan, PM2 langsung membuat backup sekali, lalu mengulanginya setiap pukul 02.00.
- Di `pm2 ls`, status `dompet-backup` adalah `stopped` di sela jadwal. Itu **normal**, karena backup bukan proses yang terus berjalan.
- Setelah komputer restart, PM2 juga langsung membuat backup sekali. Skrip menunggu database siap (maks. 1 menit).
- Cek hasil: `pm2 logs dompet-backup --lines 20 --nostream`.

Server tanpa PM2 bisa memakai crontab:
`0 2 * * * cd <folder aplikasi> && /usr/bin/node scripts/backup-db.mjs >> ~/backup-database/backup.log 2>&1`

## 4. Memulihkan

1. Hentikan aplikasi: `pm2 stop dompet-usaha`
2. Pilih tanggal dan cek keutuhan arsip:
   ```bash
   cd <folder aplikasi>
   D=~/backup-database/2026-10-28
   (cd $D && sha256sum -c SHA256SUMS)
   ```
3. Pulihkan database (isi database saat ini **diganti** isi backup):
   ```bash
   /usr/lib/postgresql/18/bin/pg_restore --clean --if-exists --no-owner --single-transaction \
     -d "$(grep '^DATABASE_URL=' .env | cut -d= -f2-)" $D/database.dump
   ```
   `--single-transaction`: bila ada galat, database kembali ke keadaan sebelum pemulihan.
4. Pulihkan foto: `tar -xzf $D/storage.tar.gz -C .`
5. Jalankan lagi: `pm2 start dompet-usaha`

Untuk sekadar memeriksa isi backup tanpa mengganggu database yang berjalan, pulihkan ke database terpisah
(`createdb`, lalu `pg_restore -d <database baru>`), lalu hapus lagi setelah selesai.

## Penting

Backup di komputer yang sama hanya melindungi dari kesalahan data atau aplikasi. Bila disk rusak, komputer hilang,
atau terkena ransomware, backup ikut hilang. **Salin folder `~/backup-database` secara berkala ke tempat lain**
(disk eksternal atau penyimpanan cloud).
