# Memasang DOMPET USAHA di server baru

Panduan untuk programmer yang memasang DOMPET USAHA di server Ubuntu baru. Perintah diketik langkah demi langkah di terminal server, memakai akun biasa yang punya hak `sudo` (bukan `root`). Waktu yang dibutuhkan sekitar 15 menit.

Yang dibutuhkan:
- Server **Ubuntu 22.04 atau 24.04** yang terhubung ke internet.
- Paket rilis **`dompet-usaha-playground-<versi>.tar.gz`** beserta berkas **`.sha256`**-nya. Paket dibuat dengan `npm run build` di folder aplikasi yang sudah berjalan (lihat [Membuat paket rilis](#membuat-paket-rilis)). Paket sudah berisi modul Node.js, jadi `npm install` tidak perlu dijalankan.

Contoh di bawah memakai versi `2.0.3`. Ganti dengan nomor versi paket yang Anda pasang.

---

## Cara cepat: `setup.sh`

Ekstrak paket, lalu jalankan satu perintah dari folder aplikasi:

```bash
sha256sum -c dompet-usaha-playground-2.0.3.tar.gz.sha256     # harus tertulis: OK
tar -xzf dompet-usaha-playground-2.0.3.tar.gz -C ~       # → folder ~/dompet-usaha-playground
cd ~/dompet-usaha-playground
./setup.sh --domain playground.dompetusaha.com
```

Skrip ini mengerjakan langkah 1–8 di bawah secara otomatis:
- memasang PostgreSQL 18, Node.js, dan pm2;
- membuat `.env` dan database (pengguna `dompet`, bukan superuser, dengan sandi acak);
- menjalankan aplikasi dan backup harian pukul 02.00 di pm2, lalu mengatur keduanya agar menyala sendiri setiap server restart.

| Situasi | Perintah |
|---|---|
| Server baru, dibuka lewat domain HTTPS | `./setup.sh --domain nama-domain` |
| Server baru, hanya di jaringan lokal (`http://IP-server:3009`) | `./setup.sh` |
| Pindah dari server lama, data ikut | `./setup.sh --env ~/env-lama --restore ~/2026-11-03` |
| Memasang versi baru | Ekstrak paket baru ke folder yang sama, lalu `./setup.sh` |

- **Pindah server.** Salin dua hal dari server lama:
  - berkas `.env`, simpan sebagai `~/env-lama`;
  - folder backup terbaru dari `~/backup-database-playground/`, yang berisi `database.dump`, `storage.tar.gz`, dan `SHA256SUMS`.

  `.env` lama wajib ikut. Tanpa `PIN_PEPPER` yang sama, PIN semua kasir harus diatur ulang, dan sandi Gmail di Notifikasi Email harus diisi lagi. Backup hanya dipulihkan ke database yang masih kosong, jadi data yang sudah ada tidak pernah tertimpa.
- **Domain lewat Cloudflare Tunnel.**
  1. Buat tunnel baru di dasbor Cloudflare Zero Trust (**Networks → Tunnels**), lalu salin tokennya.
  2. Tempel token itu saat `setup.sh` memintanya.
  3. Di tab **Public Hostname** tunnel itu, arahkan domain ke `http://localhost:<port aplikasi>` (bawaan `3009`).

  Satu domain hanya diarahkan ke satu server, jadi hapus rute domain itu dari tunnel server lama setelah server baru siap.
- **Data awal.** Pemasangan baru (tanpa `--restore`) dimulai dengan data kosong dan berisi:
  - nama usaha **PT HYBRID DAYA CAKRA GLOBAL**;
  - cabang `PUSAT`;
  - akun Pemilik **`owner`** dengan password **`owner123`**.

  Password itu sementara. Saat pertama masuk Backoffice, pemilik wajib menggantinya dengan password minimal 10 karakter yang berisi huruf dan angka. **Masuk dan ganti password segera setelah setup**, karena sebelum diganti siapa pun yang tahu password bawaan ini bisa masuk. Nilai bawaan bisa diganti, misalnya `OWNER_PASSWORD=… BUSINESS_NAME="…" ./setup.sh`.
- **Port aplikasi dan port database.** `setup.sh` menanyakan keduanya setiap kali dijalankan. Tekan Enter untuk memakai port yang sedang dipakai (pemasangan baru: aplikasi `3009`, database `5432`), atau ketik port lain antara 1024 dan 65535. Kalau port yang diisi sudah dipakai program lain, misalnya PostgreSQL lain di `5433`, `setup.sh` menolaknya dan menyarankan port bebas terdekat. Saran itu langsung menjadi pilihan Enter.

  Untuk mengganti port nanti, cukup jalankan `./setup.sh` lagi dan isi port baru. Tanpa terminal interaktif, pakai `./setup.sh --port 3000 --db-port 5434`. Setelah port aplikasi diganti, sesuaikan juga:
  - rute Cloudflare Tunnel;
  - alamat API di setiap mesin pintu tiket;
  - perangkat yang membuka `http://IP-server:<port>` langsung.

  Ringkasan di akhir `setup.sh` menampilkan alamat-alamat barunya.
- **PostgreSQL lain di server tidak disentuh.** Database aplikasi memakai PostgreSQL 18. Kalau cluster bawaannya (`18/main`) sudah dipakai database lain, `setup.sh` membuat cluster khusus `18/dompet` di port pilihan Anda, dan port cluster yang dipakai bersama tidak pernah diubah.
- **Nama proses pm2.** Aplikasi berjalan sebagai `dompet-playground`. Backup berjalan sebagai `dompet-playground-backup` dan disimpan di `~/backup-database-playground`.
- **Aman dijalankan ulang.** Saat update, database dibackup dulu. Kalau backup atau migrasi gagal, versi lama tetap berjalan.

---

## 1. Pasang Node.js, PostgreSQL, dan pm2

Langkah ini cukup sekali untuk setiap server.

```bash
sudo apt update
sudo apt install -y curl ca-certificates postgresql

# Node.js 26 dari NodeSource
curl -fsSL https://deb.nodesource.com/setup_26.x -o /tmp/nodesource_setup.sh
sudo -E bash /tmp/nodesource_setup.sh
sudo apt install -y nodejs

# pm2: menjalankan aplikasi di latar belakang dan menyalakannya lagi setelah server restart
sudo npm install -g pm2

node -v && psql --version && pm2 -v
```

Aplikasi butuh Node.js ≥ 20.12 dan PostgreSQL ≥ 13. Kalau server sudah punya keduanya, langsung pasang pm2 saja.

## 2. Ekstrak paket

```bash
cd ~                                          # folder tempat paket .tar.gz disimpan
sha256sum -c dompet-usaha-playground-2.0.3.tar.gz.sha256 # harus tertulis: OK
tar -xzf dompet-usaha-playground-2.0.3.tar.gz -C ~       # → folder ~/dompet-usaha-playground
cd ~/dompet-usaha-playground
```

## 3. Buat `.env` dan database

Ketik keempat perintah ini **di terminal yang sama**, karena sandi database disimpan sementara di variabel `DB_PASS`.

```bash
npm run init-env
DB_PASS=$(openssl rand -hex 24)
(cd / && sudo -u postgres psql -v ON_ERROR_STOP=1 \
  -c "CREATE ROLE dompet LOGIN PASSWORD '$DB_PASS'" \
  -c "CREATE DATABASE dompet_usaha OWNER dompet")
sed -i "s|^DATABASE_URL=.*|DATABASE_URL=postgres://dompet:$DB_PASS@localhost:5432/dompet_usaha|" .env && unset DB_PASS
```

Yang terjadi:
- `npm run init-env` membuat `.env` berisi `CSRF_SECRET` dan `PIN_PEPPER` acak.
- Pengguna database `dompet` dibuat dengan sandi acak. Pengguna ini bukan superuser dan hanya memiliki database `dompet_usaha`.
- Sandi itu langsung ditulis ke `DATABASE_URL` di `.env`, jadi tidak perlu dicatat.

Simpan salinan `.env` di tempat aman, **terpisah dari backup database**. Kalau `PIN_PEPPER` hilang, PIN semua kasir harus diatur ulang.

## 4. Sesuaikan `.env` dengan cara aplikasi diakses

Buka berkasnya dengan `nano .env`, lalu ubah baris-baris berikut sesuai cara pengguna membuka aplikasi:

| Diakses lewat | Isi di `.env` |
|---|---|
| **Domain HTTPS**, lewat Cloudflare Tunnel atau Nginx di server yang sama | `NODE_ENV=production`<br>`TRUST_PROXY=loopback`<br>`PUBLIC_URL=https://nama-domain-anda`<br>`HOST=127.0.0.1` (bila tidak ada perangkat yang membuka `http://IP:3009` langsung) |
| **Jaringan lokal saja**, di `http://IP-server:3009` | `NODE_ENV=production`<br>`COOKIE_SECURE=false` |

Pengaturan lain, seperti `PORT` (bawaan `3009`), `APP_TIMEZONE` (bawaan `Asia/Jakarta`), dan batas waktu sesi, dijelaskan di `.env.example`.

## 5. Buat akun Pemilik

```bash
npm run create-admin
```

Perintah ini membuat tabel database (migrasi), lalu menanyakan:

| Pertanyaan | Isi |
|---|---|
| Nama usaha | Tekan Enter untuk **PT HYBRID DAYA CAKRA GLOBAL**, atau ketik nama lain. Nama ini tercetak di struk dan kop laporan. |
| Kode & nama cabang | Cabang pertama, misalnya `PUSAT` dan `Toko Pusat` |
| Username, nama lengkap, email | Akun Pemilik. Email boleh dikosongkan. |
| Password | Minimal 10 karakter, berisi huruf dan angka. Tidak tampil saat diketik. |

Pertanyaan nama usaha hanya muncul pada pemasangan pertama. Nama usaha bisa diubah kapan saja di **Pengaturan → Profil usaha**.

## 6. Jalankan dengan pm2

```bash
pm2 start ecosystem.config.cjs --only dompet-usaha
pm2 save
pm2 startup
```

`pm2 startup` menampilkan satu perintah yang diawali `sudo env PATH=...`. Salin perintah itu, lalu jalankan. Setelah itu aplikasi menyala sendiri setiap server restart.

Pakai `--only dompet-usaha`. Aplikasi `dompet-db` di `ecosystem.config.cjs` adalah database untuk pengembangan, dan tidak dipakai di server yang sudah memasang PostgreSQL.

## 7. Periksa

```bash
curl -s http://127.0.0.1:3009/api/health      # {"ok":true,...}
pm2 ls                                        # dompet-usaha: online
pm2 logs dompet-usaha --lines 20              # tidak ada galat
```

Buka `http://IP-server:3009/login` atau domain Anda, lalu masuk dengan akun Pemilik. Setelah itu:
1. Lengkapi alamat dan telepon di **Pengaturan → Profil usaha**.
2. Buat akun staf dan kasir di **Pengguna & Kasir**.
3. Pasangkan setiap komputer atau tablet kasir lewat `/pos/setup`. Untuk perangkat Android dengan printer struk, pasang APK **Kasir DU** (`Kasir-DU-<versi>.apk`, disertakan bersama paket rilis).

## 8. Backup (wajib)

Yang perlu dibackup:
- database;
- folder `storage/`, berisi foto produk dan foto profil;
- `.env`, cukup sekali dan disimpan terpisah.

Database dan `storage/` dibackup oleh `scripts/backup-db.mjs` ke `~/backup-database/<tanggal>/`, dijadwalkan PM2
setiap pukul 02.00 (tanpa crontab):

```bash
cd ~/dompet-usaha-playground
pm2 start ecosystem.config.cjs --only dompet-backup     # langsung backup sekali, lalu tiap 02.00
pm2 save
pm2 logs dompet-backup --lines 20 --nostream            # hasil backup
```

Yang disimpan adalah 3 hari terakhir. Salin folder `~/backup-database` secara berkala ke komputer atau penyimpanan
lain. Pengaturan lain dan cara memulihkan ada di [docs/backup.md](docs/backup.md).

## 9. Memperbarui ke versi baru

```bash
cd ~/dompet-usaha-playground
npm run backup                      # backup hari ini sebelum update
tar -xzf ~/dompet-usaha-playground-2.0.9.tar.gz --strip-components=1
pm2 restart dompet-usaha
```

`.env`, `storage/`, dan database tidak tersentuh. Migrasi database berjalan otomatis saat aplikasi start. Versi yang terpasang tampil di halaman login.

Node.js khusus aplikasi yang diperbarui otomatis setiap malam bersifat opsional. Caranya ada di [docs/node-update.md](docs/node-update.md).

## Masalah umum

| Gejala | Penyebab & solusi |
|---|---|
| Login gagal dengan pesan "Origin permintaan tidak diizinkan" | Aplikasi berada di belakang proxy HTTPS, tapi `TRUST_PROXY` belum diisi. Isi `TRUST_PROXY=loopback` dan `PUBLIC_URL`, lalu `pm2 restart dompet-usaha`. |
| Login berhasil, tapi langsung kembali ke halaman login (akses lewat `http://`) | Cookie hanya dikirim lewat HTTPS. Tambahkan `COOKIE_SECURE=false`, atau pakai domain HTTPS. |
| `password authentication failed for user "dompet"` di log | Sandi di `DATABASE_URL` (`.env`) tidak cocok dengan sandi database. Samakan dengan `sudo -u postgres psql -c "ALTER ROLE dompet PASSWORD 'sandi-di-env'"`. |
| `EADDRINUSE` di log | Port aplikasi sudah dipakai program lain. Jalankan `./setup.sh` lagi dan pilih port lain. |
| Halaman tidak terbuka dari komputer lain | Buka port di firewall (`sudo ufw allow 3009/tcp`), atau akses lewat domain. |

---

## Membuat paket rilis

Jalankan di folder aplikasi yang sudah berjalan, misalnya `~/Desktop/DOMPET-USAHA`:

```bash
npm run build
```

Hasilnya ada di folder `release/`:
- `dompet-usaha-playground-<versi>.tar.gz`, berisi kode aplikasi dan modul Node.js produksi;
- `dompet-usaha-playground-<versi>.tar.gz.sha256`, sidik jari untuk memeriksa keutuhan paket;
- `dompet-usaha-playground/`, isi paket yang sama dalam bentuk folder, untuk diunggah ke git repo rilis. Isinya diganti setiap kali build, kecuali folder `.git` di dalamnya. Jadi cukup sekali `git init` (atau `git clone`) di folder ini, lalu setiap selesai build tinggal commit dan push;
- `Kasir-DU-<versi>.apk`, aplikasi kasir Android terbaru.

Hanya berkas aplikasi yang diambil (`src/`, `public/`, `scripts/`, `docs/`, dan berkas pengaturan di folder utama). `.env`, database, foto (`storage/`), folder pengujian, dan SDK Android tidak pernah ikut. Kalau foldernya memakai git, isi paket diambil dari commit terakhir.

`README.md` di dalam paket bukan README pengembangan ini. Isinya diambil dari `docs/README-rilis.md` dan hanya memuat cara instal singkat; versi dan nomor build diisi otomatis. Berkas kerja terjemahan (`docs/i18n*`) tidak ikut ke paket.

Kode di dalam paket **dipadatkan dan diacak** (`scripts/build-protect.mjs`), sementara folder sumber tidak berubah:
- `src/` (kode server): nama variabel dan fungsi diacak, teks dipindah ke tabel tersandi. Kode ini tidak pernah diunduh browser.
- `public/js/` (kode yang diunduh browser): dipadatkan, lalu nama variabel dan fungsi diacak. Hasilnya lebih ringan sekitar 16% dibanding sumbernya (setelah kompresi). Kamus bahasa (`locale-*.js`) hanya dipadatkan.
- `public/css/`: dipadatkan, sekitar 25% lebih ringan.
- Halaman HTML dipadatkan dan dikompresi oleh server saat dikirim.

Untuk melacak masalah dengan kode apa adanya, buat paket tanpa pengacakan: `PROTECT=0 npm run build`.

Naikkan `version` di `package.json` setiap kali membuat paket baru. Paket dengan nomor versi yang sama akan ditimpa.

© PT HYBRID DAYA CAKRA GLOBAL — DOMPET USAHA
