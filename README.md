# DOMPET USAHA — Backoffice & Kasir POS

**PT HYBRID DAYA CAKRA GLOBAL**

Aplikasi usaha DOMPET USAHA: login Backoffice (username/email + password) dan Kasir POS (PIN 6 digit pada terminal terdaftar), manajemen pengguna & kasir, shift kasir, **master data, stok & inventori, pembelian, pengeluaran, pengaturan, dan laporan keuangan**. Dibangun dengan **Node.js + Express.js** dan **PostgreSQL**.

---

## Daftar isi

1. [Fitur](#fitur)
2. [Struktur proyek](#struktur-proyek)
3. [Instalasi](#instalasi)
4. [Backup database](#backup-database)
5. [Panduan penggunaan](#panduan-penggunaan)
6. [Modul bisnis](#modul-bisnis)
7. [Keamanan](#keamanan)
8. [Hak akses (role & permission)](#hak-akses)
9. [Referensi API](#referensi-api)
10. [Skema database](#skema-database)
11. [Menambah modul baru](#menambah-modul-baru)
12. [Pengujian](#pengujian)
13. [Checklist production](#checklist-production)

---

## Fitur

| Area | Yang tersedia |
|---|---|
| Login Backoffice | Halaman dua kolom (ilustrasi brand + formulir), username **atau** email, tampil/sembunyikan password, "Ingat saya" (sesi persisten 30 hari, bukan menyimpan kredensial), validasi, indikator loading, hitung mundur saat terkunci, peringatan Caps Lock. |
| Login Kasir POS | Layar fullscreen untuk monitor sentuh/tablet: logo, nama cabang & terminal, jam & tanggal, status koneksi, pilihan akun kasir, PIN tersamar, keypad besar, hapus satu digit, bersihkan, tombol **MASUK**, dukungan keyboard/numpad. |
| Terminal POS | Perangkat kasir harus **dipasangkan** (pairing) lewat kode sekali pakai dari Backoffice; sesi kasir terikat ke terminal & cabang. |
| Manajemen kasir | Tambah/ubah, aktif/nonaktif, tetapkan & reset PIN (dengan konfirmasi password admin), tetapkan cabang & terminal, atur role, buka blokir, riwayat login, riwayat aktivitas, sesi aktif & akhiri sesi. |
| Shift kasir | Login ≠ buka shift. Buka shift dengan modal awal, transaksi, kas masuk/keluar, retur (uang kembali ke pelanggan), tutup shift dengan hitung kas aktual **disetujui supervisor** (PIN POS-nya, atau username & password atasan tanpa PIN), laporan & selisih kas, tutup paksa oleh supervisor. |
| Kasir POS | **Layar penuh**: menu di bar atas (Riwayat, Display pelanggan, Kas Masuk, Kas Keluar), Retur & Tutup Shift di kaki katalog; katalog produk **berhalaman** — jumlah kartu per halaman menyesuaikan ukuran layar (PageUp/PageDown untuk pindah halaman) — dengan pencarian, filter kategori & **scan barcode**; keranjang dengan +/− (desimal untuk kg/liter) setinggi layar, tombol Bayar selalu terlihat; harga coret & label promo; diskon, promo, dan **voucher** dihitung otomatis; metode bayar dari Master Data; **harga selalu dari server**; stok berkurang otomatis; setelah bayar tampil dialog **Pembayaran berhasil** (animasi sukses, kembalian, cetak ulang struk); struk siap cetak (printer termal — langsung ke printer LAN/Bluetooth lewat aplikasi Android **Kasir DU**) dengan rincian potongan; **tutup shift buta** — kasir tidak melihat angka kas selama shift, ringkasan kas & selisih baru tampil di struk laporan tutup shift. |
| Master Data | Produk (SKU otomatis, barcode, harga jual & beli, margin, stok minimum, lacak stok on/off), **multi-satuan dengan konversi** (mis. kg + pack), **produk paket (bundling)** yang mengurangi stok isinya, kategori, satuan (bulat/desimal), pemasok, **metode pembayaran** (tambah/ubah/hapus, urutan & aktif/nonaktif; berlaku semua cabang). |
| Pajak | Tarif pajak **dinamis** di Profil usaha (mis. 8%, 10%, 11%), bisa diganti **per cabang**. Produk dicentang **Kena pajak** dan dipilih **harga sudah termasuk pajak** atau **pajak ditambahkan saat bayar**. Pajak tampil di kasir, display pelanggan, dan struk (beserta NPWP); **laporan pajak** per tarif/hari/produk (dikurangi retur), dan laba rugi dihitung tanpa pajak. |
| Promo & Diskon | **Diskon produk** (persen / nominal untuk produk atau kategori), **paket kombinasi** harga spesial, **beli X gratis Y**, dan **voucher** (minimal belanja, potongan maksimal, kuota). Semua bisa dibatasi periode, **jam berlaku harian** (mis. 10:00–12:00), & cabang; statistik pemakaian per promo. |
| Stok & Inventori | Saldo per cabang, nilai persediaan (**metode FIFO**), peringatan stok menipis, **kartu stok** (lapisan FIFO & rincian HPP), penyesuaian, **stok opname**, transfer antar cabang, **konversi / pecah produk** (mis. 2 pack produk A → 10 kg produk B). |
| Membership | Produk **Membership** dijual di POS: pembayaran berhasil otomatis membuat member, nomor member, dan **kartu digital ber-QR** (bisa dicetak). Perpanjangan, upgrade/pindah tipe, aturan mulai & perpanjangan, diskon member per tipe & produk, kartu dipindai di POS (status selalu dicek server), retur membatalkan membership, Backoffice untuk pemantauan & koreksi berizin khusus. |
| Pembelian | Draft → terima barang (stok masuk, HPP diperbarui) → pembayaran bertahap; hutang & jatuh tempo pemasok. Baris *Biaya langsung* tidak masuk stok dan menjadi beban laba rugi. |
| Pengeluaran | Biaya operasional per kategori & cabang; pembatalan dengan alasan (tidak pernah dihapus). |
| Dashboard | Kartu utama **penjualan hari ini** dengan grafik kumulatif per jam (hari ini vs kemarin pada jam yang sama); 4 KPI sesuai izin (penjualan bulan ini vs bulan lalu, laba kotor & margin, pengeluaran & perkiraan laba bersih, nilai persediaan; cadangan: hutang pemasok, transaksi, rata-rata harian); tren 7/14/30 hari (penjualan / laba kotor / transaksi) dibanding periode sebelumnya; **analisa otomatis**; peta jam ramai (hari × jam); metode pembayaran; penjualan per kategori; produk terlaris (dengan foto); stok menipis; hutang pemasok; filter cabang untuk Pemilik. |
| Laporan | Tiga menu dengan izin masing-masing. **Operasional**: ringkasan vs periode sebelumnya, penjualan harian, jam & hari ramai, per produk, per kategori, kasir & shift (rekap kas & selisih), promo & diskon, daftar transaksi + rincian. **Stok**: ringkasan nilai persediaan, posisi stok, mutasi persediaan (awal → masuk/keluar → akhir), stok menipis + saran beli, barang tidak laku, opname & penyesuaian, pembelian. **Keuangan**: laba rugi vs periode sebelumnya, tren laba, laba per produk & kategori, arus kas per metode, pengeluaran, hutang pemasok (umur hutang), perbandingan cabang. Semua bisa **diunduh sebagai PDF** (kop usaha, siap dibagikan) atau **untuk Excel (CSV)**, dan **dicetak**. |
| Pengaturan | Profil usaha untuk struk, izinkan stok minus, izinkan barang manual di POS, kelola cabang, matriks role & izin. |
| Keamanan | Hash scrypt, PIN ber-*pepper*, pembatasan percobaan di PostgreSQL dengan penundaan bertahap (tidak permanen), regenerasi sesi, CSRF, cek Origin, CSP & header keamanan, audit log tanpa data rahasia, RBAC + cakupan cabang di setiap endpoint. |

---

## Struktur proyek

```
src/
  server.js                 Entrypoint: migrasi otomatis, start HTTP, pembersihan sesi berkala
  app.js                    Express app: helmet/CSP, routing, halaman, error handler
  config.js                 Konfigurasi dari environment (.env)
  db/
    pool.js                 Koneksi PostgreSQL + helper transaksi
    migrate.js              Runner migrasi SQL
    migrations/001_auth_schema.sql   Tabel, indeks, fungsi throttle
    migrations/002_rbac_seed.sql     Role & permission (tanpa akun pengguna)
  security/
    hash.js                 Hash password & PIN (scrypt, pepper PIN), validasi PIN/password
    throttle.js             Pembatasan percobaan login (PostgreSQL)
    csrf.js                 Token CSRF & cek Origin
    tokens.js               Token acak, kode pairing
  middleware/
    auth.js                 authenticate(kanal), requirePermission(), cakupan cabang
    rateLimit.js            Pembatas laju kasar per IP (anti-banjir)
  services/                 sessions, audit, users, terminals, shifts,
                            stock (saldo + kartu stok + HPP), settings,
                            pricing (promo/voucher per cabang + mesin harga bersama), branchList,
                            reportScope (filter periode & cabang laporan),
                            salesRollup (ringkasan penjualan harian untuk laporan & dashboard),
                            storage (file foto di storage/), media (validasi & simpan foto produk),
                            assets (versi otomatis ?v= untuk JS/CSS — cache browser/CDN selalu benar)
  utils/                    validate, http, docno (nomor dokumen), time (zona waktu usaha),
                            html (pengecil HTML halaman: satu baris saat dikirim)
  routes/
    auth.backoffice.js      /api/auth/*
    pos.js                  /api/pos/* (terminal, login PIN, shift, katalog, penjualan, struk)
    admin.users.js          /api/admin/users/* (manajemen pengguna & kasir)
    backoffice.js           /api/backoffice/* (dashboard, cabang, terminal, shift, audit)
    master.js               /api/backoffice/master/*     (produk & paket, kategori, satuan, pemasok, metode bayar)
    promotions.js           /api/backoffice/promotions/* (diskon, kombinasi, beli X gratis Y, voucher)
    inventory.js            /api/backoffice/inventory/*  (saldo, kartu stok, penyesuaian, transfer)
    purchasing.js           /api/backoffice/purchases/*
    expenses.js             /api/backoffice/expenses/*
    settings.js             /api/backoffice/settings/*
    reports.js              /api/backoffice/reports/* → reports.ops.js, reports.stock.js, reports.finance.js
public/
  pages/                    login.html, backoffice.html, pos-login.html, pos-setup.html, pos.html
  js/backoffice.js          Shell Backoffice: navigasi, dashboard, pengguna, terminal, shift, audit
  js/bo-core.js             State & komponen bersama (tabel, form, editor baris barang)
  js/bo-*.js                Satu file per modul: master, promos, inventory, purchasing, expenses, settings, reports
                            (diunduh saat menunya dibuka; setelah halaman pertama tampil, sisanya diunduh diam-diam)
  js/pos.js                 Layar kasir (katalog, keranjang, pembayaran, struk)
  js/pricing.mjs            Mesin harga bersama (diskon, promo, voucher) — dipakai POS dan server
  css/, img/
  docs/panduan-dompet-usaha.pdf  Buku panduan pengguna (menu akun → Buku panduan), dibuat dari manual/
manual/                     Sumber buku panduan PDF: panduan.html + panduan.css, gambar (img/), font,
                            build.mjs (node manual/build.mjs → public/docs/). Tidak ikut paket rilis.
scripts/
  create-admin.js           Membuat akun Pemilik pertama (interaktif); nama usaha saat pemasangan baru
  build-release.sh          npm run build → paket rilis release/dompet-usaha-playground-<versi>.tar.gz (lihat INSTALL.md)
  build-protect.mjs         Dipanggil build-release.sh: memadatkan & mengacak kode di salinan paket (PROTECT=0 → mati)
  init-env.js               Membuat .env dengan rahasia acak
  dev-db.mjs                PostgreSQL lokal untuk pengembangan
  backup-db.mjs             npm run backup → database + storage/ ke ~/backup-database/<tanggal> (PM2 tiap 02.00, simpan 3 hari)
test/                       Pengujian keamanan & integrasi (PostgreSQL sungguhan)
storage/                    File unggahan (tidak masuk git, wajib di-backup bersama database):
  products/<ab>/<sha256>.jpg  foto produk — nama = sha256 isi, foto identik dipakai bersama
  avatars/<id>.jpg            foto profil pengguna
```

---

## Instalasi

Persyaratan: **Node.js ≥ 20.12** dan **PostgreSQL ≥ 13**.

**Memasang di server baru (production):** ikuti [INSTALL.md](INSTALL.md), dari paket rilis `npm run build` sampai pm2 dan backup.

### Pengembangan lokal

```bash
npm install
npm run init-env        # membuat .env berisi CSRF_SECRET & PIN_PEPPER acak
npm run dev-db          # (terminal terpisah) PostgreSQL lokal di port 5433 — opsional jika sudah punya PostgreSQL
npm run create-admin    # membuat cabang pertama + akun Pemilik (password Anda ketik sendiri)
npm run dev             # http://localhost:2026
```

Jika memakai PostgreSQL sendiri, ubah `DATABASE_URL` di `.env`. Migrasi berjalan otomatis saat server start (atau manual: `npm run migrate`).

| URL | Kegunaan |
|---|---|
| `/login` | Login Backoffice |
| `/backoffice` | Dashboard Backoffice |
| `/pos/setup` | Pemasangan perangkat sebagai terminal POS |
| `/pos/login` | Login Kasir POS (PIN) |
| `/pos` | Layar kasir |

### Variabel environment

| Variabel | Wajib | Keterangan |
|---|---|---|
| `DATABASE_URL` | ya | Koneksi PostgreSQL |
| `CSRF_SECRET` | ya | Min. 32 karakter acak; kunci HMAC token CSRF |
| `PIN_PEPPER` | ya | Min. 32 karakter acak; **disimpan di luar database**. Jika hilang/diganti, semua PIN harus di-reset. |
| `NODE_ENV` | — | `production` mengaktifkan cookie `Secure` + awalan `__Host-` dan HSTS |
| `TRUST_PROXY` | — | Proxy tepercaya di depan aplikasi: jumlah hop (mis. `1` untuk Nginx) atau `loopback` bila proxy berjalan di mesin yang sama (Nginx/Cloudflare Tunnel). Wajib di belakang HTTPS: tanpa ini login ditolak "Origin permintaan tidak diizinkan" dan semua pengunjung terbaca ber-IP 127.0.0.1 untuk rate limit. |
| `COOKIE_SECURE` | — | Paksa cookie Secure (default mengikuti `NODE_ENV`) |
| `PUBLIC_URL` | — | Alamat publik aplikasi, mis. `https://app.dompetusaha.id`. Dipakai untuk URL absolut di tag SEO (canonical, Open Graph) dan `sitemap.xml`. Tanpa ini, gambar pratinjau tautan di WhatsApp/Facebook tidak tampil. |
| `APP_TIMEZONE` | — | Zona waktu usaha (default `Asia/Jakarta`). Menentukan tanggal di nomor dokumen, batas "hari ini", dan rentang laporan — juga dipakai sebagai zona waktu sesi database. |
| `STORAGE_DIR` | — | Folder foto produk & foto profil (default `storage/` di folder aplikasi). Di luar `public/`, jadi foto hanya bisa dibuka lewat API dengan sesi aktif. Saat start, foto lama yang masih di database dipindah otomatis ke folder ini. |
| `BO_IDLE_TIMEOUT_SEC` dll. | — | Batas waktu sesi; lihat `.env.example` |

### SEO halaman masuk

Hanya `/login`, `/pos/login`, dan `/pos/setup` yang boleh diindeks mesin pencari; Backoffice, layar kasir, dan API diblokir lewat `/robots.txt`. Ketiga halaman itu punya meta deskripsi, canonical, Open Graph/Twitter Card dengan gambar pratinjau (`public/img/og-backoffice.jpg`, `og-pos.jpg`, 1200×630), dan `/login` membawa data terstruktur (JSON-LD `WebSite` + `Organization`). Server mengganti `{{BASE_URL}}` di HTML dengan `PUBLIC_URL`.

- Robot mesin pencari tidak punya cookie terminal, jadi `/pos/login` selalu dialihkan ke `/pos/setup` — halaman itulah yang terindeks untuk Kasir POS (perangkat yang sudah terpasang langsung diteruskan ke `/pos/login`).
- `sitemap.xml` hanya tersedia bila `PUBLIC_URL` diisi; daftarkan di Google Search Console.

> **Tidak ada akun demo.** Migrasi hanya membuat role & permission. Akun pertama dibuat dengan `npm run create-admin`; akun lain dibuat dari Backoffice.

---

## Backup database

`scripts/backup-db.mjs` mem-backup **database** dan **folder `storage/`** (foto produk & profil), dijadwalkan **PM2
setiap pukul 02.00** lewat entri `dompet-backup` di `ecosystem.config.cjs`. Tidak memakai crontab.

```
~/backup-database/
├── 2026-10-26/   database.dump  storage.tar.gz  SHA256SUMS  INFO.txt
├── 2026-10-27/
└── 2026-10-28/
```

- Disimpan **3 hari terakhir**: setelah backup hari ke-4 berhasil, backup hari ke-1 dihapus.
- Backup lama baru dihapus setelah backup baru lolos verifikasi, jadi backup yang gagal tidak menghapus apa pun.
- Isi folder hanya bisa dibaca pemilik (izin 700/600).

Mengaktifkan (sekali). `pg_dump` harus sama atau lebih baru dari versi server; database embedded adalah PostgreSQL 18:

```bash
sudo apt install -y postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
sudo apt install -y postgresql-client-18

pm2 start ecosystem.config.cjs --only dompet-backup   # langsung backup sekali, lalu tiap 02.00
pm2 save                                              # tetap terjadwal setelah komputer restart
```

| Perintah | Kegunaan |
|---|---|
| `npm run backup` | Backup sekarang (manual) |
| `pm2 logs dompet-backup --lines 20 --nostream` | Hasil backup terakhir (`OK …` atau `GAGAL …`) |
| `pm2 ls` | `dompet-backup` berstatus `stopped` di sela jadwal, dan itu normal |

Cara memulihkan dan pengaturan lain (`BACKUP_DIR`, `BACKUP_KEEP`, `PG_BIN`) ada di [docs/backup.md](docs/backup.md).
Salin `~/backup-database` secara berkala ke luar komputer (disk eksternal atau cloud). Backup di mesin yang sama ikut
hilang bila disk rusak atau terkena ransomware.

---

## Panduan penggunaan

Buku panduan lengkap untuk pengguna (PDF, bahasa Indonesia) dibuka dari Backoffice lewat **menu akun → Buku panduan**
(`/docs/panduan-dompet-usaha.pdf`). Cara memperbaruinya ada di [manual/README.md](manual/README.md). Ringkasan untuk administrator:

### 1. Administrator — menyiapkan kasir

1. Login di `/login` dengan akun Pemilik/Administrator.
2. **Terminal POS → + Tambah terminal**: pilih cabang, isi kode (mis. `KASIR-01`) dan nama. Kode pairing langsung ditampilkan (berlaku 10 menit, sekali pakai).
3. Di komputer/tablet kasir buka `/pos/setup`, masukkan kode pairing → perangkat terpasang sebagai terminal tersebut.
4. **Pengguna & Kasir → + Tambah pengguna**: isi nama & username, pilih cabang, centang role **Kasir**, aktifkan *Akses Kasir POS*, isi PIN awal 6 digit (opsional — bisa ditetapkan nanti). Opsional: batasi ke terminal tertentu.
5. Sampaikan PIN langsung ke kasir. PIN tidak bisa dilihat lagi oleh siapa pun.

Satu orang bisa punya **akses Backoffice dan POS sekaligus** pada satu akun (mis. supervisor): centang kedua akses; ia login Backoffice dengan password dan POS dengan PIN.

### 2. Kasir — alur kerja

1. Di `/pos/login`, ketuk nama Anda, masukkan PIN di keypad (atau keyboard), tekan **MASUK**.
2. Konfirmasi terminal, isi **modal awal**, tekan **Buka Shift**.
3. Bertransaksi. Kas masuk/keluar dicatat lewat tombol di toolbar.
   - **Member**: pindai QR kartu (scanner atau kamera) atau ketuk *Member / pelanggan* untuk mencari nama/nomor HP/nomor member → diskon member langsung terhitung bila masa aktifnya berlaku hari ini.
   - **Jual membership**: ketuk produk membership → pilih pelanggan (cari, pindai kartu, atau *Daftarkan pelanggan baru*: tampil QR yang dipindai pelanggan untuk mengisi datanya sendiri di HP — data langsung terpasang di transaksi — atau *Isi di kasir*) → keranjang menampilkan jenisnya (baru / perpanjangan / upgrade) beserta tanggal mulai & berakhir → bayar. Setelah pembayaran berhasil, kartu member (QR, nomor, tipe, status, masa aktif) langsung tampil dan bisa dicetak.
4. **Tutup Shift**: hitung uang di laci, masukkan kas aktual, lalu **supervisor menyetujui** di layar yang sama — pilih nama supervisor dan ia mengetik PIN POS-nya (6 digit). Atasan tanpa PIN (mis. pemilik) memakai tab *Username & password* dengan akun Backoffice-nya. → laporan shift (dapat dicetak) termasuk selisih kas dan nama yang menyetujui.
   - Yang bisa menyetujui: akun aktif berizin `shifts.manage` (bawaan: supervisor, admin, pemilik) dari cabang terminal itu (atau berizin semua cabang), bukan kasir yang menutup shift. Untuk cara PIN, akun perlu **Akses POS + PIN** — atur di Backoffice › Pengguna & Kasir.
   - PIN/password salah dihitung bersama percobaan login akun tersebut (dan per terminal), jadi tidak bisa ditebak berulang; setiap persetujuan & penolakan tercatat di Audit Log.
5. **Selesai & Keluar**.

Logout tidak menutup shift. Shift yang tertinggal terbuka dapat ditutup oleh kasir yang sama saat login kembali, atau **ditutup paksa** oleh supervisor di *Backoffice → Shift Kasir*.

#### Aplikasi Android "Kasir DU" & printer termal

Folder [`SDK-KASIR-ANDROID/`](SDK-KASIR-ANDROID/README.md) berisi aplikasi Android **Kasir DU** (APK siap pasang di `SDK-KASIR-ANDROID/dist/`). Aplikasi membuka web kasir lewat domain di dalam WebView dan mencetak **struk belanja** serta **slip tutup shift** langsung ke printer termal **LAN/Wi-Fi (port 9100)** atau **Bluetooth**, kertas **58 mm (32 karakter)** atau **80 mm (48 karakter)** — dipilih di halaman pertama aplikasi beserta URL kasir.

- Web mengirim *dokumen cetak* (JSON berisi baris teks, dua kolom, garis, tanda tangan) ke `window.KasirDU`; aplikasi menyusunnya sesuai lebar kertas dan mengirim perintah ESC/POS. Pratinjau struk di layar dibuat dari dokumen yang sama (`public/js/pos-print.js`).
- Di aplikasi, menu kasir mendapat tombol **Printer** (pengaturan printer) dan struk bisa dicetak otomatis setelah transaksi.
- Di browser biasa, tombol cetak tetap memakai dialog cetak browser.

### 3. Alur operasional harian

1. **Master Data → Produk**: tambahkan produk (harga jual, harga beli acuan, satuan, stok minimum). Produk jasa/non-barang: matikan *Lacak stok*.
2. **Pembelian → + Pembelian baru**: pilih pemasok, cari/scan barang, isi jumlah & harga beli. Centang *Barang sudah diterima* agar stok langsung masuk. Nyalakan *Biaya langsung* pada baris barang yang dibeli untuk dipakai habis (bukan dijual) agar tidak masuk stok. Catat pembayaran saat melunasi pemasok.
3. **Kasir POS**: kasir memilih barang dari katalog (atau scan barcode) — harga dan stok mengikuti Backoffice.
4. **Stok & Inventori**: pantau stok menipis, lihat kartu stok, lakukan **stok opname** berkala (kolom terisi saldo sistem — cukup ubah yang berbeda).
5. **Pengeluaran**: catat biaya di luar laci kasir (gaji, sewa, listrik).
6. **Laporan → Laba rugi**: lihat penjualan bersih, HPP, laba kotor, beban, dan laba bersih per periode/cabang.

### 4. Pemulihan akses

| Situasi | Tindakan |
|---|---|
| Kasir terkunci karena salah PIN | Tunggu (kunci sementara 30 dtk → maks. 15 mnt), **atau** admin: *Detail kasir → Keamanan & PIN → Buka blokir*. |
| Kasir lupa PIN | Admin: *Reset PIN* (perlu password admin). Semua sesi POS kasir itu diakhiri. |
| Pengguna lupa password | Admin: *Reset password* → password sementara, wajib diganti saat login. |
| Perangkat kasir hilang/diganti | *Terminal POS → Lepas* lalu pasangkan perangkat baru. |
| Karyawan keluar | *Nonaktifkan* — semua sesinya langsung berakhir. |

---

## Modul bisnis

### Stok & HPP
- Semua perubahan stok lewat satu layanan (`src/services/stock.js`) dalam transaksi database yang sama dengan dokumennya: saldo (`product_stocks`) dan kartu stok (`stock_movements`) selalu konsisten.
- **Metode FIFO per cabang** (*first in, first out*): setiap barang masuk (pembelian, penyesuaian tambah, transfer masuk) membentuk **lapisan** (`stock_layers`) dengan harga pokoknya sendiri. Barang keluar (penjualan, opname/penyesuaian kurang, transfer keluar) mengambil dari lapisan **tertua** lebih dulu; HPP = Σ (qty diambil × harga lapisan). Lapisan yang dipakai setiap mutasi tercatat di `stock_movement_layers`.
  - Contoh: beli 10 @ Rp 6.000, lalu 10 @ Rp 8.000, jual 15 → HPP = 10 × 6.000 + 5 × 8.000 = **Rp 100.000**; sisa 5 @ Rp 8.000 = Rp 40.000.
  - Penambahan stok tanpa harga (penyesuaian/opname naik) memakai harga pokok lapisan terakhir, atau harga beli produk bila belum pernah ada lapisan.
  - Transfer antar cabang memindahkan lapisan beserta harga aslinya.
  - Bila stok minus diizinkan, kekurangan dibebankan pada harga pokok terakhir, dan barang masuk berikutnya menutup saldo minus lebih dulu sebelum membentuk lapisan baru.
  - `product_stocks.avg_cost` hanya nilai per unit sisa stok (nilai lapisan ÷ qty) untuk tampilan; `sale_items.unit_cost` = HPP FIFO per satuan yang dijual.
  - Saat migrasi `005_fifo_layers.sql`, saldo yang sudah ada dijadikan satu lapisan awal dengan harga pokok saat itu.
- Kartu stok menampilkan lapisan FIFO yang tersisa beserta dokumen asalnya, serta untuk tiap mutasi: harga pokok per unit, rincian lapisan yang dipakai (mis. `98 × Rp 1.100`, `2 × Rp 1.000`), dan total HPP/nilai.

### Konversi / pecah produk
- *Stok & Inventori → Konversi produk*: produk sumber keluar dalam satuan apa pun, produk hasil masuk dalam satuan lain, di cabang yang sama. Contoh: Ayam Utuh 2 pack → Ayam Potong 10 kg.
- Sumber dikurangi secara **FIFO**; **total HPP** lapisan yang terpakai menjadi nilai lapisan baru produk hasil (harga pokok hasil = total HPP ÷ jumlah hasil dalam satuan dasar). Nilai persediaan tidak bertambah/berkurang.
- Tercatat sebagai dokumen `KNV-…` (`stock_conversions`) dengan mutasi `conversion_out`/`conversion_in` di kartu stok kedua produk.
- Endpoint: `POST /api/backoffice/inventory/conversions` `{ branchId, sourceProductId, sourceUnitId, sourceQty, targetProductId, targetUnitId, targetQty, note }` (`inventory.manage`); `GET /conversions`, `GET /conversions/:id` (`inventory.view`).
- Baris saldo **dikunci** (`SELECT … FOR UPDATE`, urut `product_id` agar tidak deadlock) sebelum diubah, sehingga penjualan paralel tidak dapat menjual melebihi stok (diuji: 6 transaksi paralel untuk 3 unit → tepat 3 berhasil).
- Default **stok minus tidak diizinkan**: penjualan/penyesuaian/transfer yang membuat saldo negatif ditolak (`409 INSUFFICIENT_STOCK`) dan seluruh transaksi dibatalkan. Dapat diubah di *Pengaturan → Stok & POS*.
- Penyesuaian & opname disimpan sebagai dokumen (`stock_adjustments`) beserta saldo sebelum/sesudah per barang; transfer memindahkan saldo **beserta HPP** cabang asal.

### Multi-satuan (konversi)
- Setiap produk punya **satuan dasar** (stok disimpan dalam satuan ini) dan boleh punya satuan lain dengan faktor: `1 <satuan lain> = faktor <satuan dasar>`. Contoh Ayam Pop: dasar `kg`, `pack` = 0,5 kg.
- Satuan lain boleh punya **harga jual khusus** dan **barcode sendiri**; tanpa harga khusus, harga = harga dasar × faktor.
- POS, pembelian, penyesuaian, opname, dan transfer dapat memakai satuan mana pun; server mengonversi ke satuan dasar sebelum mengubah stok. Contoh: jual 1 pack → stok berkurang 0,5 kg; beli 10 pack @ Rp 30.000 → stok +5 kg dengan HPP Rp 60.000/kg.
- Transaksi menyimpan satuan & faktor saat itu (`sale_items.unit_name/unit_factor`, `purchase_items.unit_id/unit_factor`), sehingga riwayat tidak berubah bila konversi produk diubah kemudian. Laporan menjumlahkan kuantitas dalam satuan dasar.
- Mengganti **satuan dasar** produk tidak mengonversi saldo lama — lakukan stok opname setelahnya.

### POS ↔ katalog
- Barang katalog dikirim sebagai `{ productId, qty }`; **harga diambil dari database**, harga dari klien diabaikan.
- Barang manual (nama + harga diketik kasir) **ditolak** kecuali diaktifkan di Pengaturan; barang manual tidak mengurangi stok dan HPP-nya tidak diketahui (ditandai di laporan).
- Struk memakai profil usaha dari Pengaturan dan dapat dicetak ulang dari daftar transaksi shift.

### Produk paket (bundling)
- Di *Master Data → Produk*, pilih jenis **Paket (bundling)** lalu isi produk-produk di dalamnya (mis. Paket Nasi Ayam = 1 Nasi Putih + 1 Ayam Bakar). Jumlah isi dalam satuan dasar produk isi.
- Paket dijual sebagai satu barang dengan harganya sendiri. Saat terjual, **stok setiap isinya berkurang** (FIFO, tercatat di kartu stok dengan nomor invoice & nama paket) dan **HPP paket = jumlah HPP isinya**. Paket tidak punya stok sendiri, tidak bisa dibeli, dan tidak boleh berisi paket lain.
- POS menampilkan sisa paket yang bisa dibuat dari stok isinya (memperhitungkan isi yang sudah ada di keranjang). Paket bisa dibatasi **cabang** tempat dijual.

### Promo & Diskon
Menu *Promo & Diskon* (izin `promotions.view` / `promotions.manage`). Setiap promo punya periode opsional (tanggal usaha, inklusif), jam berlaku harian opsional (mis. 10:00–12:00 setiap hari; jam selesai tidak ikut; boleh lewat tengah malam seperti 22:00–02:00), cabang (semua / tertentu), status aktif, dan statistik pemakaian. Layar POS memuat ulang promo sendiri tepat saat jam berlaku mulai/berakhir; voucher di luar jamnya ditolak (`VOUCHER_INVALID`).

| Jenis | Cara kerja |
|---|---|
| Diskon produk | Potongan per barang (persen, atau Rupiah per satuan dasar) untuk produk dan/atau kategori tertentu. Bila beberapa berlaku, dipakai **potongan terbesar**. |
| Paket kombinasi | Semua produk promo ada di keranjang → dibayar **harga promo per set**; berlaku kelipatan. |
| Beli X gratis Y | Beli produk X sejumlah n → produk Y sejumlah m mendapat potongan (100% = gratis, mis. 50% = "item kedua setengah harga"). X dan Y boleh produk yang sama (beli 2 gratis 1). POS memberi petunjuk bila barang gratis belum dimasukkan. |
| Voucher | Kode yang dimasukkan kasir; memotong total setelah diskon & promo (persen dengan potongan maksimal, atau nominal). Minimal belanja, kuota pemakaian (dikunci per transaksi sehingga tidak terlampaui oleh transaksi paralel). |

- Urutan: diskon produk → promo kombinasi / beli-dapat (dari harga setelah diskon; setiap unit hanya dipakai satu promo; potongan terbesar per set lebih dulu) → voucher. Potongan dibulatkan ke Rupiah utuh.
- Perhitungan memakai **satu mesin harga** (`public/js/pricing.mjs`) di layar POS dan di server. POS mengirim `expectedTotal`; bila harga/promo berubah di antara keduanya, transaksi ditolak (`PRICE_CHANGED`) dan POS memuat ulang keranjang.
- Potongan promo & voucher dibagi ke baris barang, sehingga `sale_items.subtotal` bernilai bersih dan Σ subtotal = total transaksi; laporan per produk & laba kotor otomatis memakai nilai bersih. Rincian tersimpan di `discount_amount`, `promo_amount`, `voucher_amount`.
- Promo yang sudah dipakai tidak bisa dihapus (hanya dinonaktifkan) agar riwayat tetap utuh.

### Pajak
Logika: `src/services/tax.js` & mesin harga bersama `public/js/pricing.mjs` (langkah 4). Migrasi `030_tax.sql`.

- **Tarif**: *Pengaturan → Profil usaha → Pajak* (`business.taxRate`, 0–100%, maks. 2 desimal; NPWP opsional dicetak di struk). Cabang di daerah dengan tarif lain mengisi *Tarif pajak cabang* (`branches.tax_rate`; kosong = ikut Profil usaha). Layar kasir menerima tarif cabangnya bersama katalog.
- **Produk**: centang *Kena pajak* (`products.taxable`), lalu *Harga jual sudah termasuk pajak?* (`price_includes_tax`). Barang manual tidak kena pajak.
- **Hitungan**: per baris, dari harga **setelah semua potongan** (diskon, promo, voucher, member), dibulatkan ke Rupiah utuh. Termasuk pajak: pajak = bersih × tarif / (100 + tarif), total tetap. Ditambahkan: pajak = bersih × tarif / 100, total naik. Contoh Rp 11.000 termasuk 10% → pajak Rp 1.000; Rp 20.000 + 10% → bayar Rp 22.000.
- **Tersimpan per baris saat terjual** (`sale_items.tax_rate`, `tax_included`, `tax_amount`; `sales.tax_amount`, `tax_added`), jadi transaksi lama tetap benar walau tarif diubah. `sale_items.subtotal` = yang dibayar untuk baris itu (termasuk pajak yang ditambahkan), sehingga Σ subtotal = total transaksi.
- **Kasir & struk**: kartu produk "+pajak" untuk pajak yang ditambahkan; baris "+ Pajak 10%" di keranjang; catatan *Termasuk pajak Rp …* di bawah total; rincian di dialog bayar & display pelanggan; struk mencetak NPWP, *Pajak 10%* sebelum TOTAL, dan *Harga sudah termasuk pajak Rp …*.
- **Retur**: uang kembali termasuk pajaknya (sebanding nilai baris); pajak atas retur = nominal retur × pajak baris / subtotal baris.
- **Laporan**: *Laporan Keuangan → Pajak* — pajak terutang (pajak penjualan − pajak retur), penjualan kena pajak (DPP), pajak di dalam harga vs ditambahkan, per tarif, per hari, per produk; unduh PDF/Excel. **Laba rugi**, tren, laba per produk/kategori, dan per cabang memakai penjualan **tanpa pajak** (baris *Pajak penjualan* di laba rugi). Ringkasan harian (`report_*`) ikut menyimpan pajak.

### Membership
Produk membership dijual lewat POS; Backoffice (*Membership*) untuk pemantauan & administrasi. Logika inti: `src/services/membership.js`.

- **Jenis produk** (*Master Data → Produk*): Barang/Retail, Paket, Membership, Playground, Jasa lainnya. Hanya barang yang bisa melacak stok. Produk membership punya pengaturan: **tipe member** yang diberikan, **masa aktif** (angka + hari/bulan/tahun), **aturan mulai** (tanggal pembayaran, atau saat kartu pertama kali dipakai di POS), dan **ketentuan perpanjangan** (langsung dari tanggal transaksi, atau setelah masa aktif lama berakhir). Produk membership tidak bisa dibeli dari pemasok dan tidak bisa menjadi isi paket.
- **Tipe member** (Basic, Silver, Gold, Family — bisa diubah/ditambah): *level* menentukan upgrade/downgrade, *diskon bawaan* (%) berlaku untuk semua produk. Per produk & tipe bisa diganti di form produk: diskon persen lain (0 = tanpa diskon) atau **harga khusus member** per satuan dasar.
- **Pembayaran → membership**: membership dibuat di transaksi database yang sama dengan penjualan, jadi pembayaran gagal/ditolak tidak pernah membuat atau memperpanjang membership. Satu pelanggan = satu member = satu kartu (`customer_id` unik); setiap pembelian = satu periode di `member_periods` (`sale_item_id` unik). POS mengirim `clientRef` per percobaan bayar; request yang dikirim ulang (koneksi putus, klik ganda, dua request bersamaan) mengembalikan transaksi yang sama, tanpa kartu atau periode ganda.
- **Jenis pembelian** dibandingkan dengan tipe yang sedang/akan dipegang: tipe sama → *perpanjangan* (aturan produk); level lebih tinggi → *upgrade*, setara → *pindah tipe* (aturan di *Membership → Pengaturan*: langsung atau setelah masa aktif berakhir); level lebih rendah → *turun tipe* (selalu setelah masa aktif berakhir). "Setelah berakhir" = mulai sehari setelah periode terakhir; "langsung" = mulai hari ini, periode berjalan dihentikan (bukan dihapus) dan periode yang sudah terjadwal digeser ke belakang. Opsional: **kredit upgrade** (sisa hari periode berjalan × harga yang dibayar menjadi potongan produk membership baru).
- **Kartu**: nomor member berurutan (awalan bisa diatur, mis. `MBR-000123`) + kode kartu acak 12 karakter. QR berisi `DUMEMBER:<kode kartu>` — identitas saja, bukan bukti aktif: setiap pemindaian & transaksi memeriksa status di server. *Ganti kartu* membuat kode baru (kartu lama tidak berlaku). Aplikasi Kasir DU yang belum mendukung QR mencetak nomor member di tempat QR.
- **Tiket masuk playground** (`src/services/entryTickets.js`, migrasi `031_entry_tickets.sql`): transaksi berisi produk jenis **Playground** tanpa member mendapat **satu QR** berisi kode **10 digit acak** (1.000.000.000–3.800.000.000, batas angka pembaca swing barrier; tidak berurutan sehingga tidak bisa ditebak) yang berlaku untuk **jumlah orang = jumlah tiket playground** pada **hari transaksi**. QR tercetak di struk (*TIKET MASUK*), tampil di dialog *Pembayaran berhasil* dan di display pelanggan (bisa difoto). Member masuk dengan kartunya sendiri, jadi transaksi dengan member — termasuk yang baru membeli membership — tidak mendapat QR. Retur tiket mengurangi jumlah orangnya; semua diretur = QR batal. Kolom `used_count`/`last_used_at`/`status` disiapkan untuk integrasi pembaca swing barrier.
- **Display pelanggan** (`src/services/customerDisplay.js`, halaman `/display`): menu *Display pelanggan* di bar atas kasir. Layar menghadap pelanggan bertema taman bermain yang sama dengan halaman daftar member (`public/js/park.js`): sapaan + promo hari ini saat menunggu; barang yang sedang diinput (baris baru menyala), potongan per barang, rincian diskon/promo/voucher, nama & tipe member beserta **fotonya** (foto member, atau selfie/foto kamera kasir untuk pelanggan baru), dan total; saat dialog bayar terbuka: metode, saldo member yang dipakai, uang diterima & kembalian; setelah bayar: ucapan terima kasih, kembalian, sambutan member baru; dan QR daftar member tampil besar selama QR-nya terbuka di kasir. Pasang di **monitor kedua** (jendela baru di browser kasir, tampilan seketika lewat BroadcastChannel) atau **tablet/TV** (kode pasang 8 karakter / QR dari layar kasir, berlaku 10 menit, satu display per terminal, bisa dilepas; cookie display hanya bisa membaca tampilan terminalnya). Layar kasir mengirim tampilan ke server (`PUT /api/pos/display`) hanya bila ada display; display menanyakan versinya tiap detik, kembali ke sapaan bila kasir 30 menit tidak mengirim apa pun, dan menjaga layar tetap menyala (Wake Lock). **Klik/ketuk di mana saja → layar penuh** (kursor mouse hilang saat diam). Foto: server hanya memberikan foto pelanggan yang sedang tampil di display terminal itu (`GET /api/display/photo?k=`); foto pelanggan baru dikirim terpisah (`PUT /api/pos/display/photo`, migrasi `032_display_photo.sql`) dan dihapus begitu tidak tampil lagi.
- **Daftar mandiri lewat QR** (`src/services/customerSignups.js`): *Daftarkan pelanggan baru* di POS menampilkan QR berisi tautan sekali pakai `/daftar/<token>` (berlaku 15 menit, satu QR aktif per terminal, token disimpan sebagai SHA-256). Pelanggan membukanya di HP — halaman pendaftaran member bertema taman bermain (langit mengikuti jam: pagi/siang/senja/malam, 4 bahasa) — lalu mengisi nama, nomor HP, email & tanggal lahir (opsional), dan foto kartu member (selfie atau pilih dari galeri HP) bila transaksinya membeli membership. Layar kasir memantau status (menunggu dipindai → sedang mengisi → diterima) dan langsung memasang datanya sebagai pelanggan baru transaksi; pelanggan & member tetap dibuat bersama transaksinya, dan titipan datanya dihapus setelah dipakai, dibatalkan, atau kedaluwarsa. Tautan dibentuk dari `PUBLIC_URL`; bila kosong, dari alamat layar kasir (localhost diganti IP jaringan lokal server agar bisa dibuka HP di Wi-Fi yang sama). `/api/join/*` tanpa login, dibatasi 30 permintaan/menit per IP. *Isi di kasir* tetap tersedia.
- **Diskon member** dihitung mesin harga yang sama di POS & server (`pricing.mjs`): hanya untuk member yang masa aktifnya berlaku hari ini (atau periode yang aktif oleh transaksi itu), tidak untuk kartu kedaluwarsa/diblokir, dan tidak pernah untuk produk membership. Gabungan dengan diskon produk: *pakai yang lebih besar* (bawaan) atau *gabungkan*. Membership yang dibeli tidak memberi diskon ke barang lain di transaksi yang sama, kecuali diaktifkan di pengaturan. Tersimpan di `sale_items.member_amount` & `sales.member_amount`, tampil di struk dan laporan (rincian potongan laba rugi, promo, detail transaksi).
- **Retur** baris membership di POS membatalkan periodenya (periode yang dihentikan dipulihkan, yang digeser dikembalikan); ditolak bila member sudah punya periode yang lebih baru — koreksi lewat Backoffice.
- **Backoffice → Membership**: daftar member (status aktif/segera berakhir/kedaluwarsa/menunggu/diblokir, cari nama/HP/nomor), detail dengan kartu & QR (cetak), riwayat membership (pembelian, perpanjangan, perubahan tipe), riwayat transaksi & diskon, riwayat perubahan (pengguna, waktu, alasan, data sebelum → sesudah). *Ubah data pelanggan* & *ganti kartu*: izin `membership.manage` + alasan. **Koreksi** (ubah tanggal berakhir/tipe, batalkan, beri masa aktif tanpa pembayaran, aktifkan, blokir/buka): izin khusus `membership.adjust` + alasan + **konfirmasi password**; tercatat di `member_events` dan Audit Log.

### Pembelian
- **Draft** dapat diubah/dibatalkan dan tidak memengaruhi stok. **Diterima** → stok masuk sebagai lapisan FIFO baru, harga beli acuan produk = harga terakhir; dokumen terkunci.
- Pembayaran pemasok (`purchase_payments`) bertahap, tidak boleh melebihi sisa hutang, dan **tidak** memengaruhi kas laci POS.
- Baris **Biaya langsung** (`purchase_items.expensed`), dipilih per baris saat membuat/mengubah pembelian: saat diterima tidak menambah stok dan tidak mengubah harga beli acuan; subtotalnya menjadi beban *Pembelian biaya langsung* di laba rugi pada tanggal pembelian. Total, hutang, dan pembayaran tetap lewat pembelian (arus kas = pembayaran pemasok, tidak dobel dengan pengeluaran). Produk yang sama boleh dua baris bila satu masuk stok dan satu biaya langsung.

### Pengeluaran & laporan
- Pengeluaran operasional terpisah dari *Kas Keluar* shift (uang yang diambil dari laci kasir). Pembatalan memakai status `void` + alasan.
- **Laba rugi** = penjualan − refund − pajak penjualan − HPP − pengeluaran − pemakaian stok − pembelian biaya langsung. Penjualan sudah bersih dari diskon, promo, dan voucher (dirinci di laporan). Pembelian stok bukan beban; beban muncul sebagai HPP saat barang terjual.

### Laporan
Di sidebar (bagian *Utama*, di bawah Dashboard) ada tiga menu laporan, masing-masing dengan beberapa tab. Filter bersama: rentang tanggal (Hari ini, Kemarin, 7/30 hari, Bulan ini, Bulan lalu, Tahun ini) dan cabang (bagi pengguna yang boleh melihat semua cabang). Laporan "per saat ini" (posisi stok, stok menipis, ringkasan stok, hutang) tidak memakai rentang tanggal. Setiap laporan punya tombol **Unduh PDF**, **Unduh Excel** (CSV, pemisah `;`, desimal koma, UTF-8 BOM), dan **Cetak** (hanya isi laporan + judul, periode, cabang, waktu cetak).

**Unduh PDF** membuat file A4 langsung di browser (`public/js/bo-pdf.mjs`): kop berisi logo dan identitas usaha dari *Pengaturan → Usaha* (nama, alamat, telepon — sama dengan struk), judul laporan, periode/posisi, cabang, waktu cetak, dan pencetak; filter aktif (pencarian, kategori, status, urutan); kartu ringkasan seperti di layar; lalu tabel dengan **seluruh baris** (sama dengan unduhan Excel), angka rata kanan, baris total, judul kolom yang diulang di setiap halaman, dan nomor "Halaman X dari Y". Orientasi dipilih otomatis — landscape bila tabel terlalu lebar untuk portrait — begitu juga ukuran huruf (≥ 7 pt bila memungkinkan). Pustakanya, [jsPDF](https://github.com/parallax/jsPDF) 4.2.1 dan [jspdf-autotable](https://github.com/simonbengtsson/jsPDF-AutoTable) 5.0.9 (MIT, di `public/js/vendor/` beserta lisensinya), baru dimuat saat tombol ditekan, sehingga halaman laporan tetap ringan. Nama file pustaka memuat versinya, jadi disajikan dengan cache permanen; untuk memperbarui, ganti file dan path di `bo-pdf.mjs`. Font PDF standar (Helvetica) hanya memuat karakter Latin; simbol lain (▲, −, ≤, emoji) otomatis diganti padanannya.

| Menu (izin) | Laporan |
|---|---|
| **Operasional** (`reports.operations.view`) | Ringkasan (omzet, transaksi, rata-rata vs periode sebelumnya; metode bayar, kategori, produk terlaris, per cabang, jam/hari terbaik) · Penjualan harian (per metode & diskon) · Jam & hari ramai · Per produk · Per kategori · Kasir & shift (kinerja kasir, rekap kas tiap shift: modal, tunai, non-tunai, kas masuk/keluar, refund, seharusnya, aktual, selisih) · Promo & diskon · Transaksi (cari invoice, filter metode, rincian barang & pembayaran) |
| **Stok** (`reports.stock.view`) | Ringkasan (nilai FIFO, menipis/habis/minus per cabang & kategori) · Posisi stok · Mutasi persediaan (stok awal + beli/transfer/konversi/penyesuaian − jual/transfer/konversi/penyesuaian = stok akhir, plus nilai beli & HPP terjual) · Stok menipis (terjual/hari 30 hari terakhir, perkiraan habis, saran beli ±14 hari, pemasok & harga terakhir) · Tidak laku (ada stok, tidak terjual dalam periode) · Opname & penyesuaian (nilai selisih) · Pembelian (per pemasok & per produk) |
| **Keuangan** (`reports.finance.view`) | Laba rugi (vs periode sebelumnya, % penjualan) · Tren laba (harian ≤ 62 hari, selebihnya bulanan) · Laba per produk · Laba per kategori · Arus kas per metode (penjualan, kas masuk, refund, kas keluar laci, bayar pemasok, pengeluaran) · Pengeluaran (per kategori, metode, rincian) · Hutang pemasok (umur hutang dari jatuh tempo, per pemasok, faktur belum lunas) · Per cabang |

- Mutasi persediaan menghitung stok akhir = saldo kini − mutasi setelah periode, sehingga tetap benar untuk periode lampau. Untuk "semua cabang", transfer antar cabang tercatat masuk dan keluar (saling meniadakan).
- Rentang maksimal 2 tahun. Tabel panjang berhalaman; unduhan memuat semua baris (hingga 10.000).
- **Ringkasan harian** (`src/services/salesRollup.js`, tabel `report_*`): agar laporan tetap cepat walau data bertahun-tahun, penjualan setiap hari yang sudah lewat diringkas sekali (per cabang × jam × kasir, per metode bayar, per produk, per kategori, per promo), dan bulan penuh diringkas lagi per produk. Peringkas berjalan di latar belakang — sesaat setelah server menyala, lalu memeriksa tiap menit; hari kemarin siap mulai pukul 01.00. Laporan & dashboard menjumlah ringkasan untuk hari/bulan yang siap dan menghitung langsung dari transaksi untuk hari ini (atau hari yang belum diringkas), dalam satu query — angkanya identik dengan hitungan per transaksi (diuji). Nama produk, satuan, dan nama kategori dibaca saat laporan dibuka. Bila data hari lampau berubah (transaksi diubah/dihapus), hari itu otomatis ditandai (`report_dirty_days`) dan dihitung langsung sampai diringkas ulang; bila kategori produk dipindah, hanya ringkasan per kategori pada hari-hari penjualannya yang dihitung ulang (`report_stale_categories`). Jalur kasir tidak terpengaruh. Untuk meringkas ulang semuanya (mis. setelah mengubah barang transaksi lama langsung di database): `TRUNCATE report_days CASCADE;`.

### Nomor dokumen
`<JENIS>-<KODE CABANG>-<YYYYMMDD>-<ID>`, mis. `PB-PUSAT-20261019-000012` (pembelian), `BY-…` (pengeluaran), `ADJ-…`/`SO-…` (penyesuaian/opname), `TRF-…` (transfer), `INV-…` (penjualan). Tanggal mengikuti `APP_TIMEZONE`. ID berasal dari sequence sehingga unik; nomor dapat melompat bila transaksi gagal (mis. stok tidak cukup).

---

## Keamanan

### Penyimpanan kredensial
- **Password**: `scrypt` (N=2¹⁵, r=8, p=1, salt 16 byte). Parameter disimpan bersama hash sehingga biaya dapat dinaikkan tanpa migrasi.
- **PIN**: ruang PIN 6 digit hanya 10⁶, jadi hash lambat saja tidak cukup. PIN di-`HMAC-SHA256` dengan **`PIN_PEPPER`** (rahasia di luar database) lalu di-`scrypt`. Database yang bocor tanpa pepper tidak dapat di-*brute force* secara offline.
- PIN tidak pernah disimpan di `localStorage`, `sessionStorage`, cookie, maupun log. Di frontend PIN hanya ada di variabel memori dan dihapus setelah dikirim.
- PIN lemah ditolak (angka sama semua, berurutan naik/turun, pola umum).
- Akun yang tidak ada diverifikasi terhadap hash tiruan agar waktu respons sama (anti-enumerasi).

### Pembatasan percobaan (backend, PostgreSQL)
Percobaan dicatat **sebelum** verifikasi secara atomik (fungsi `auth_throttle_hit`, row lock), sehingga request paralel atau request langsung ke API tidak dapat melewatinya.

| Kunci | Ambang | Kunci pertama | Maksimum |
|---|---|---|---|
| Identitas Backoffice (username/email yang diketik) | 5 | 30 dtk | 15 mnt |
| IP Backoffice | 30 | 60 dtk | 30 mnt |
| Akun kasir (PIN) | 5 | 30 dtk | 15 mnt |
| Terminal POS | 20 | 30 dtk | 10 mnt |
| IP POS | 40 | 60 dtk | 30 mnt |
| IP pairing terminal | 10 | 60 dtk | 60 mnt |

Durasi kunci **berlipat dua** tiap kegagalan setelah ambang (penundaan bertahap) dan **tidak pernah permanen**. Login berhasil mereset hitungan akun. Admin berizin `users.unlock` dapat membuka blokir kapan saja. Ditambah pembatas laju umum 60 request/menit/IP untuk endpoint login.

### Sesi
- Token sesi 256-bit acak di cookie `HttpOnly`, `SameSite=Strict`, `Secure` + awalan `__Host-` di production. Database hanya menyimpan **SHA-256** token.
- **Regenerasi sesi** di setiap login (anti *session fixation*); sesi lama yang dibawa browser dicabut.
- Batas waktu idle & absolut: Backoffice 30 mnt / 12 jam (atau 7 hari / 30 hari dengan "Ingat saya"); POS 30 mnt / 14 jam.
- Setiap request memeriksa ulang status akun, flag akses kanal, dan permission terbaru → penonaktifan/pencabutan izin berlaku seketika.
- Sesi POS terikat ke cookie perangkat terminal: cookie sesi kasir yang dicuri tidak berlaku di perangkat lain. Satu kasir aktif per terminal, satu sesi POS per kasir.
- Ganti/reset password atau PIN mengakhiri sesi terkait.

### CSRF & header
- Token CSRF HMAC (*signed double-submit*): sebelum login terikat ke nonce cookie, setelah login terikat ke sesi. Wajib di header `X-CSRF-Token` untuk semua request non-GET.
- Request non-GET dengan header `Origin` asing ditolak.
- Helmet: CSP ketat (`script-src 'self'`, tanpa inline script), `frame-ancestors 'none'`, `nosniff`, `no-referrer`, HSTS (production).
- Halaman HTML diperkecil otomatis menjadi satu baris saat dikirim (komentar & spasi dibuang; file di `public/pages` tetap rapi untuk diedit), lalu dikirim dengan `Cache-Control: no-store, no-transform` (dikompresi sendiri oleh server): proxy seperti Cloudflare tidak boleh mengubah HTML, sehingga tidak menyisipkan skrip pihak ketiga (mis. beacon Cloudflare Web Analytics) ke halaman login/kasir. Statistik pengunjung tetap tersedia di dashboard Cloudflare (Analytics → Traffic) tanpa skrip.
- Semua teks dari server dirender lewat `textContent` (tanpa `innerHTML`).

### ID publik (tanpa angka urut di tautan)
- Id internal database (1, 2, 3, …) **tidak pernah keluar** dari server. Di setiap respons API, id diganti token 22 karakter, mis. `/api/backoffice/master/products/kZg6n-WR_f8zyHigP0LBhA` dan `/api/media/trM3wRn-yIB8cnKJSuQ91Q`.
- Token = AES-128 atas `[id | penanda rahasia]` (base64url). Tanpa kunci server token tidak bisa ditebak, diurutkan, atau dibalik menjadi angka; token karangan atau yang diubah satu huruf ditolak.
- Request (path, query, body) **hanya menerima token**; id angka mentah ditolak `400`. Penerjemahan dilakukan terpusat (`src/security/publicId.js`): middleware mendekode body/query dan mengenkode respons untuk semua kunci `id`, `*_id`, `*Id`, `*_ids`, `*Ids`, `*_by`; `v.id()` mendekode parameter path.
- Kunci diturunkan dari `CSRF_SECRET` (HKDF, label terpisah) — tidak perlu rahasia baru. Token yang sama selalu untuk id yang sama (gambar tetap ter-cache, halaman tetap bisa dibandingkan); **mengganti `CSRF_SECRET` mengganti semua token** (dan membatalkan token CSRF yang beredar).
- Ini lapisan tambahan, bukan pengganti otorisasi: setiap endpoint tetap memeriksa sesi, izin, dan cakupan cabang. Nomor dokumen yang memang berurutan (invoice, SKU otomatis) tidak berubah.

### Pemisahan Backoffice & POS
- Dua cookie sesi terpisah (`du_bo`, `du_pos`), dua middleware kanal. Sesi POS **tidak pernah** diterima endpoint Backoffice — kasir yang mencoba mendapat **HTTP 403**.
- Login Backoffice hanya menerima password; PIN tidak dapat dipakai sebagai password.
- Setiap endpoint memeriksa sesi → status akun → akses kanal → permission → cakupan cabang. Menu frontend hanya cermin; penegakan ada di backend.
- Pencegahan eskalasi: administrator tidak dapat memberi role berisi izin yang tidak ia miliki, tidak dapat mengubah pengguna yang izinnya lebih tinggi, dan tidak dapat menonaktifkan/mengubah role dirinya sendiri.

### Audit
- `login_attempts`: setiap percobaan login (berhasil/gagal + alasan, IP, user agent, terminal).
- `audit_logs`: login/logout, perubahan pengguna, set/reset PIN & password, buka blokir, pencabutan sesi, pairing terminal, shift, kas, penjualan, perubahan master data (termasuk harga jual sebelumnya), stok, pembelian & pembayaran, pengeluaran & pembatalannya, pengaturan (nilai sebelum/sesudah), cabang.
- Kunci sensitif (`pin`, `password`, `token`, `hash`, …) dibuang otomatis dari detail audit. Log akses HTTP hanya berisi metode, path, status, durasi — tanpa body/query.

---

## Hak akses

| Role | Cakupan | Ringkasan izin |
|---|---|---|
| **Pemilik** (`owner`) | Semua cabang | Semua izin |
| **Administrator** (`admin`) | Cabangnya | Semua kecuali `branches.manage`, `settings.manage`, `branches.all` — termasuk master data, promo & diskon, stok, pembelian, pengeluaran, ketiga menu laporan |
| **Supervisor** (`supervisor`) | Cabangnya | Backoffice: dashboard, lihat pengguna, buka blokir, lihat sesi/terminal, laporan & tutup paksa shift, **lihat** master data, promo, stok, dan pembelian, **laporan operasional & stok** (tanpa laporan keuangan). POS: semua termasuk retur tanpa persetujuan atasan |
| **Kasir** (`cashier`) | Cabangnya | Hanya POS: `pos.access`, `pos.transaction`, `pos.shift.open`, `pos.shift.close`, `pos.cash_movement` |

Daftar permission lengkap ada di `src/db/migrations/002_rbac_seed.sql` dan `003_business_modules.sql` (dapat dilihat di *Pengaturan → Role & izin*). Setiap modul punya izin **lihat** dan **kelola** terpisah: `master_data.view/manage`, `promotions.view/manage`, `inventory.view/manage`, `purchasing.view/manage`, `expenses.view/manage`, `membership.view/manage`. Koreksi membership di luar transaksi POS memakai izin khusus `membership.adjust` (bawaan: hanya Pemilik). Laporan: `reports.operations.view`, `reports.stock.view`, `reports.finance.view`. Kasir **tidak** otomatis mendapat akses laporan keuangan, manajemen pengguna, atau pengaturan sistem.

Selain role, setiap pengguna punya flag `backoffice_access` dan `pos_access`. Login kanal membutuhkan flag **dan** permission (`backoffice.access` / `pos.access`).

---

## Referensi API

Semua respons JSON. Error: `{ "error": { "code": "...", "message": "..." } }` (+ `retryAfter` & header `Retry-After` untuk 429). Request non-GET wajib membawa `X-CSRF-Token`. Semua id (`:id` di path, `productId`, `branchIds`, …) berupa **token publik**, bukan angka — lihat *Keamanan → ID publik*.

### Autentikasi Backoffice — `/api/auth`
| Metode & path | Keterangan |
|---|---|
| `GET /csrf` | Token CSRF pra-login |
| `POST /login` | `{ identifier, password, remember }` → set cookie sesi, `{ user, csrfToken, mustChangePassword, redirect }` |
| `GET /me` | Profil, role, permission, `csrfToken` sesi |
| `POST /logout` | Mengakhiri sesi |
| `POST /password` | `{ currentPassword, newPassword }` |
| `PATCH /me` | `{ fullName, email }` — ubah profil sendiri |
| `GET /me/avatar` · `PUT /me/avatar` `{ image: dataURL }` · `DELETE /me/avatar` | Foto profil (JPG/PNG/WEBP, diperkecil di browser ke 256 px, isi file diverifikasi, maks. 200 KB; disimpan di `storage/avatars/`) |

### POS — `/api/pos`
| Metode & path | Keterangan |
|---|---|
| `GET /terminal` | Info terminal perangkat ini + daftar kasir yang boleh login (404 jika belum dipasang) + `csrfToken` |
| `POST /terminal/pair` | `{ code }` → memasang perangkat |
| `POST /auth/login` | `{ userId, pin }` |
| `GET /auth/me`, `POST /auth/logout` | Sesi kasir |
| `GET /shift/current` | Shift terbuka milik kasir — hanya identitas (kasir, terminal, cabang, jam buka), **tanpa angka kas** (tutup shift buta). Angka lengkap ada di respons `POST /shift/close` dan di Backoffice |
| `POST /shift/open` | `{ openingCash }` |
| `GET /shift/approvers` | Atasan yang bisa menyetujui tutup shift dengan PIN di cabang terminal ini (tanpa kasir itu sendiri) |
| `POST /shift/close` | `{ countedCash, notes, approval }` → laporan shift. `approval` = `{ userId, pin }` (PIN supervisor) atau `{ identifier, password }` (akun Backoffice atasan) |
| `POST /shift/cash-movements` | `{ type: cash_in\|cash_out, amount, reason, saleId? }` — uang kembali ke pelanggan hanya lewat retur (`/api/pos/returns`) |
| `GET /products` | Katalog aktif di cabang terminal + saldo stok + isi paket (`components`) + pengaturan POS. `?q=`, `?code=` (scanner), `?categoryId=`, `?ids=`, `?page=&pageSize=` (1–100, mengikuti layar) → `total` (maks. 10.000, `totalCapped`) untuk nomor halaman |
| `GET /promotions` | Diskon produk, kombinasi, dan beli X gratis Y yang berlaku di cabang ini saat ini (tanggal & jam) + `refreshIn` (detik sampai daftar bisa berubah: jam promo mulai/berakhir atau ganti hari) |
| `GET /payment-methods` | Metode pembayaran dari Master Data (`is_active` = tampil sebagai tombol; semua dipakai untuk label struk) |
| `POST /vouchers/check` | `{ code }` → voucher yang bisa dipakai, atau `VOUCHER_INVALID` beserta alasannya |
| `POST /sales` | `{ items: [{productId, unitId?, qty}] \| [{name, qty, price}]*, payments: [{method, amount, tendered?}], voucherCode?, expectedTotal?, clientRef?, memberId? \| customerId? \| customer?: {name, phone, email?, birthDate?} }` — *barang manual hanya bila diizinkan. Diskon/promo/voucher/diskon member dihitung ulang di server; `PRICE_CHANGED` bila total berbeda dari `expectedTotal`; `method` = kode metode aktif (`PAYMENT_METHOD_UNAVAILABLE` bila tidak ada/nonaktif). Produk membership: satu per transaksi, jumlah 1, wajib pelanggan (`CUSTOMER_REQUIRED`); respons memuat `member` & `membership` (kartu). `clientRef` sama → transaksi yang sudah tersimpan (`replayed: true`) |
| `GET /members/lookup?code=` | Kartu dari QR (`DUMEMBER:…`), kode kartu, atau nomor member → member + status hari ini + aturan diskon tipenya (`MEMBER_NOT_FOUND`) |
| `GET /members/members/:id` | Data member terbaru (sama dengan lookup) |
| `GET /members/customers?q=` | Cari pelanggan (nama, nomor HP, nomor member) beserta status member |
| `GET /display` · `PUT /display` · `POST /display/code` · `DELETE /display` | Display pelanggan: status tablet/TV terpasang; kirim tampilan `{ state }` (mode `idle`/`cart`/`pay`/`paid`, maks. 60 KB); kode pasang `{ code, url, expiresIn }`; lepas display; `PUT /display/photo { key, image }` foto pelanggan baru. Halaman display: `GET /api/display/session`, `POST /api/display/pair { code }`, `GET /api/display/state?v=`, `GET /api/display/photo?k=` |
| `POST /members/signups` · `GET /members/signups/:id` · `DELETE /members/signups/:id` | QR daftar mandiri `{ withPhoto? }` → `{ id, url, expiresIn }`; status `waiting` / `opened` / `submitted` (membawa `customer` & `photo`) / `expired`, hanya untuk terminal pembuatnya; DELETE = data sudah dipakai atau QR ditutup |
| `POST /members/preview` | `{ productId, memberId? \| customerId? }` → rencana pembelian membership (jenis, tanggal mulai & berakhir, kredit upgrade) sebelum dibayar |
| `GET /sales` | Transaksi di shift berjalan |
| `GET /sales/:id` | Detail transaksi terminal ini untuk struk (termasuk potongan per baris, promo, voucher) |

### Manajemen pengguna — `/api/admin/users` (sesi Backoffice)
| Metode & path | Izin |
|---|---|
| `GET /` (`?q=&access=&status=&branchId=`) , `GET /:id` | `users.view` |
| `POST /`, `PATCH /:id`, `POST /:id/status` | `users.manage` |
| `POST /:id/pin` `{ pin, adminPassword }` | `users.reset_pin` |
| `POST /:id/password` `{ password, adminPassword }` | `users.reset_password` |
| `POST /:id/unlock` | `users.unlock` |
| `GET /:id/login-history`, `GET /:id/activity` | `users.view` |
| `GET /:id/sessions` | `sessions.view` |
| `POST /:id/sessions/revoke-all`, `POST /:id/sessions/:sid/revoke` | `sessions.revoke` |

### Backoffice — `/api/backoffice`
| Metode & path | Izin |
|---|---|
| `GET /dashboard` (`?days=7\|14\|30&branchId=`) | `dashboard.view` — bagian keuangan, stok, hutang, pengeluaran hanya disertakan sesuai izin |
| `GET /roles`, `GET /permissions` | `users.view` |
| `GET /branches` · `POST /branches`, `PATCH /branches/:id` | sesi Backoffice · `branches.manage` |
| `GET /payment-methods` (nama metode pembayaran untuk label & filter laporan) | sesi Backoffice |
| `GET /terminals` | `terminals.view` |
| `POST /terminals`, `PATCH /terminals/:id`, `POST /terminals/:id/pairing-code`, `POST /terminals/:id/unpair` | `terminals.manage` |
| `GET /audit-logs` (`?action=&userId=&before=`) | `audit.view` |
| `GET /shifts` (`?status=&from=&to=&branchId=`), `GET /shifts/:id` | `shifts.view` |
| `POST /shifts/:id/force-close` `{ countedCash, notes }` | `shifts.manage` |

### Master data — `/api/backoffice/master`
| Metode & path | Izin |
|---|---|
| `GET /products` (`?q=&categoryId=&active=&branchId=&kind=retail\|bundle\|membership\|playground\|service\|discount&bundles=0`), `GET /products/:id` | lihat master/stok/pembelian |
| `POST /products`, `PATCH /products/:id` (`productType: retail\|bundle\|membership\|playground\|service`; `units: [{unitId, factor, sellingPrice?, barcode?}]`; paket: `components: [{productId, qty}], branchIds: null\|[id]`; membership: `membership: {tierId, durationValue, durationUnit: day\|month\|year, startRule: purchase\|first_use, renewalRule: after_end\|immediate}`; diskon member per produk: `memberPrices: [{tierId, type: percent\|price, value}]`) | `master_data.manage` |
| `GET /member-tiers` | Tipe member (pilihan di form produk) | lihat master/stok/pembelian |
| `GET·POST /categories`, `PATCH /categories/:id` | lihat · `master_data.manage` |
| `GET·POST /units`, `PATCH /units/:id` | lihat · `master_data.manage` |
| `GET·POST /suppliers`, `PATCH /suppliers/:id` | lihat · `master_data.manage` |
| `GET·POST /payment-methods`, `PATCH·DELETE /payment-methods/:id` (`{ name, sortOrder?, isActive? }`; kode dibuat otomatis dari nama; Tunai tidak bisa dinonaktifkan/dihapus; metode yang sudah dipakai transaksi → `METHOD_IN_USE`, nonaktifkan saja) | lihat · `master_data.manage` |

### Promo & Diskon — `/api/backoffice/promotions`
| Metode & path | Izin |
|---|---|
| `GET /` (`?type=discount\|combo\|buy_get\|voucher&status=active\|scheduled\|expired\|inactive&q=`), `GET /:id` | `promotions.view` / `promotions.manage` |
| `POST /` — semua jenis: `{ type, name, startDate?, endDate?, branchIds: null\|[id] }` + per jenis: diskon `{ discountType, discountValue, productIds?, categoryIds? }`, kombinasi `{ items: [{productId, qty}], comboPrice }`, beli-dapat `{ buy: {productId, qty}, get: {productId, qty}, getPercent? }`, voucher `{ code, discountType, discountValue, minPurchase?, maxDiscount?, quota? }` | `promotions.manage` |
| `PATCH /:id` (isi lengkap seperti POST, atau `{ isActive }` saja), `DELETE /:id` (hanya bila belum pernah dipakai) | `promotions.manage` |

### Membership — `/api/backoffice/membership`
| Metode & path | Izin |
|---|---|
| `GET /summary`, `GET /members` (`?q=&status=active\|expiring\|pending\|scheduled\|expired\|suspended&tierId=`), `GET /members/:id`, `GET /members/:id/sales` (`?discounted=1`), `GET /tiers`, `GET /settings` | `membership.view` / `manage` / `adjust` |
| `PATCH /members/:id/customer` `{ name?, phone?, email?, birthDate?, notes?, holderName?, reason }`, `POST /members/:id/card` `{ reason }` | `membership.manage` |
| `POST /tiers` `{ code, name, level, discountPercent, description? }`, `PATCH /tiers/:id` (+ `isActive`), `DELETE /tiers/:id` (hanya tipe yang belum dipakai member/produk/transaksi; selain itu `TIER_IN_USE`), `PUT /settings` `{ upgradeRule, upgradeCredit, stacking, sameSaleDiscount, memberNoPrefix }` | `membership.manage` |
| `POST /members/:id/adjust` `{ action: set_end\|set_tier\|cancel\|grant\|activate\|suspend\|unsuspend, periodId?, tierId?, startsOn?, endsOn?, reason, adminPassword }` | `membership.adjust` |

### Stok — `/api/backoffice/inventory`
| Metode & path | Izin |
|---|---|
| `GET /stocks` (`?branchId=&q=&categoryId=&low=1`) | `inventory.view` |
| `GET /movements?productId=&branchId=&before=` (kartu stok) | `inventory.view` |
| `GET /adjustments`, `GET /adjustments/:id` | `inventory.view` |
| `POST /adjustments` `{ kind: adjustment\|opname, branchId, reason, items: [{productId, qtyChange \| countedQty}] }` | `inventory.manage` |
| `GET /transfers`, `GET /transfers/:id` | `inventory.view` |
| `POST /transfers` `{ fromBranchId, toBranchId, note, items: [{productId, qty}] }` | `inventory.manage` |

### Pembelian — `/api/backoffice/purchases`
| Metode & path | Izin |
|---|---|
| `GET /` (`?status=&payment=outstanding&supplierId=&from=&to=&branchId=`), `GET /:id` | `purchasing.view` |
| `POST /` `{ branchId, supplierId, purchaseDate, dueDate, supplierInvoiceNo, notes, items: [{productId, unitId, qty, unitCost, expensed}], receive, payment }` | `purchasing.manage` |
| `PUT /:id` (draft), `POST /:id/receive`, `POST /:id/cancel` `{ reason }` | `purchasing.manage` |
| `POST /:id/payments` `{ amount, method, paidAt, note }` | `purchasing.manage` |

### Pengeluaran — `/api/backoffice/expenses`
| Metode & path | Izin |
|---|---|
| `GET /` (`?from=&to=&categoryId=&status=&branchId=`), `GET /categories` | `expenses.view` / `reports.finance.view` |
| `POST /` `{ branchId, categoryId, expenseDate, amount, method, description }` | `expenses.manage` |
| `POST /:id/void` `{ reason }`, `POST /categories`, `PATCH /categories/:id` | `expenses.manage` |

### Pengaturan & laporan
| Metode & path | Izin |
|---|---|
| `GET /api/backoffice/settings`, `PUT /api/backoffice/settings/{business\|inventory\|pos}` | `settings.manage` |
| `GET /api/backoffice/reports/ops/{summary\|daily\|hourly\|products\|categories\|cashiers\|shifts\|promotions\|transactions}`, `GET /ops/transactions/:id` | `reports.operations.view` |
| `GET /api/backoffice/reports/stock/{summary\|positions\|movements\|low\|dead\|adjustments\|purchases}` | `reports.stock.view` |
| `GET /api/backoffice/reports/finance/{profit-loss\|trend\|products\|categories\|cashflow\|expenses\|payables\|branches}` | `reports.finance.view` |

Laporan menerima `?from=&to=` (default bulan berjalan) dan `?branchId=`; daftar berhalaman menerima `?page=&pageSize=` atau `?export=1` (semua baris, maks. 10.000).

Semua endpoint di atas menerapkan cakupan cabang: pengguna tanpa `branches.all` hanya membaca/menulis data cabangnya (data cabang lain → 403/404).

---

## Skema database

| Tabel | Isi |
|---|---|
| `users` | Satu identitas per orang: `username`, `email`, `full_name`, `password_hash`, `pin_hash`, `status`, `branch_id`, `backoffice_access`, `pos_access`, `must_change_password` |
| `roles`, `permissions`, `user_roles`, `role_permissions` | RBAC |
| `user_terminals` | Pembatasan opsional kasir ke terminal tertentu |
| `branches` | Cabang |
| `pos_terminals` | Terminal, hash token perangkat, hash kode pairing |
| `user_sessions` | Hash token sesi, kanal, cabang, terminal, idle/absolut, pencabutan |
| `login_attempts` | Riwayat percobaan login |
| `auth_throttles` | Penghitung percobaan gagal & kunci sementara |
| `audit_logs` | Jejak audit |
| `cashier_shifts` | Shift kasir + snapshot perhitungan kas saat ditutup |
| `cash_movements` | Kas masuk / kas keluar / refund (uang retur; dicatat oleh retur) — di luar pembayaran penjualan |
| `payment_methods` | Metode pembayaran penjualan (kode tetap, nama, urutan, aktif). `sale_payments.method` merujuk kode ini; `cash` = Tunai (bawaan) |
| `sales`, `sale_items`, `sale_payments` | Transaksi POS; `sale_items.product_id` + `unit_cost` (HPP saat terjual) + potongan per baris (`discount_amount`, `member_amount`, `promo_amount`, `voucher_amount`); `sales.voucher_code/voucher_amount`, `customer_id`, `member_id`, `member_tier_id`, `member_amount`, `client_ref` (idempotensi, unik per terminal) |
| `sale_promotions` | Promo kombinasi / beli-dapat yang terpakai per transaksi |
| `products`, `product_categories`, `units`, `suppliers` | Master data; `products.product_type` (retail/bundle/membership/playground/service; `is_bundle` = paket) |
| `member_tiers`, `product_memberships`, `member_tier_prices` | Tipe member (level, diskon bawaan); pengaturan produk membership; diskon/harga member per produk & tipe |
| `customers`, `members` | Pelanggan; member & kartu (`member_no`, `card_code` untuk QR, `holder_name`, status blokir) — satu per pelanggan |
| `member_periods`, `member_events` | Periode membership per pembelian/koreksi (tidak pernah dihapus; `superseded`/`cancelled`); riwayat member (pembelian, perpanjangan, perubahan tipe, koreksi dengan alasan & data sebelum/sesudah) |
| `bundle_items`, `product_branches` | Isi paket; cabang tempat paket dijual (bila tidak semua cabang) |
| `promotions`, `promotion_items`, `promotion_branches` | Diskon, kombinasi, beli X gratis Y, voucher; sasaran (produk/kategori + jumlah); pembatasan cabang |
| `product_units` | Satuan tambahan produk: faktor konversi, harga khusus, barcode |
| `product_stocks` | Saldo & nilai per unit sisa per produk per cabang |
| `stock_layers`, `stock_movement_layers` | Lapisan FIFO & jejak lapisan yang dipakai tiap mutasi |
| `stock_conversions` | Konversi / pecah produk |
| `stock_movements` | Kartu stok (append-only) |
| `stock_adjustments`, `stock_adjustment_items` | Penyesuaian & opname |
| `stock_transfers`, `stock_transfer_items` | Transfer antar cabang |
| `purchases`, `purchase_items`, `purchase_payments` | Pembelian & pembayaran pemasok |
| `expense_categories`, `expenses` | Pengeluaran operasional |
| `app_settings` | Pengaturan (JSON per bagian) |

**Perhitungan kas shift** (tanpa penggandaan):

```
kas seharusnya = modal awal
               + penjualan tunai     (sale_payments.method='cash', nilai yang diterapkan ke tagihan — kembalian tidak dihitung)
               + kas masuk lain      (cash_movements.type='cash_in')
               − kas keluar          (cash_movements.type='cash_out')
               − uang retur          (cash_movements.type='refund')
selisih        = kas aktual − kas seharusnya
```
Pembayaran penjualan hanya tercatat di `sale_payments`, tidak pernah di `cash_movements`, sehingga tidak terhitung dua kali. Pembayaran non-tunai tidak masuk kas laci.

---

## Menambah modul baru

Modul baru mengikuti pola modul yang sudah ada (lihat `src/routes/inventory.js`):

```js
// src/app.js
app.use('/api/backoffice/loyalty', backofficeAuth, require('./routes/loyalty'));

// src/routes/loyalty.js
const { requirePermission, requireAny, targetBranch } = require('../middleware/auth');
router.get('/', requireAny('loyalty.view', 'loyalty.manage'), asyncHandler(async (req, res) => { /* filter branchScope(req) */ }));
router.post('/', requirePermission('loyalty.manage'), asyncHandler(async (req, res) => {
  const branchId = targetBranch(req, req.body.branchId);   // default cabang pengguna + cek cakupan
  await db.transaction(async (client) => {
    // ... tulis data; perubahan stok wajib lewat services/stock.js (lock → move)
    await audit({ actorUserId: req.auth.userId, action: 'loyalty.created', branchId, details: { ... }, req }, client);
  });
}));
```

1. Izin baru ditambahkan lewat migrasi SQL baru (`src/db/migrations/004_….sql`) beserta pemberiannya ke role.
2. Frontend: buat `public/js/bo-<modul>.js` yang mengekspor `render…()` memakai komponen dari `bo-core.js` (form: `modal({ title, subtitle, wide })`, `formSection`, `field` + `req`/`opt`, `affix` untuk "Rp"/satuan, `switchRow` untuk saklar — lihat form produk di `bo-master.js`), lalu daftarkan di `ROUTES` pada `public/js/backoffice.js` dengan `render: lazy('./bo-<modul>.js', 'render…')` — modul diunduh saat menunya dibuka (menu tampil otomatis sesuai izin). Jangan di-import statis dan jangan ditambahkan ke `modulepreload` di `backoffice.html`, agar tidak ikut dimuat di awal. Tidak perlu menaikkan `?v=` di HTML: server memberi versi otomatis pada setiap URL JS/CSS dan import antar-modul (berubah setiap kali ada file JS/CSS yang berubah), sehingga browser maupun CDN seperti Cloudflare selalu mengambil file terbaru.
3. Endpoint layar kasir memakai `authenticate('pos')` (otomatis terikat terminal & cabang).

---

## Pengujian

```bash
npm test
```

Test menjalankan PostgreSQL sungguhan (embedded) per file dan menguji lewat HTTP. Cakupan utama (116 test):

- Login Backoffice: cookie aman, pesan generik, CSRF, Origin, *session fixation*, "Ingat saya", akun nonaktif / tanpa akses, logout, wajib ganti password.
- Pembatasan percobaan: kunci setelah ambang (bahkan dengan password benar), penundaan bertahap, tidak permanen, **25–30 request paralel tidak bisa melewati batas**.
- PIN: pairing terminal sekali pakai, daftar kasir yang sah saja, pesan aman, kunci & buka blokir admin, hash ber-pepper, **PIN tidak muncul di log aplikasi, audit, maupun riwayat login**.
- Pemisahan akses: sesi kasir → 403 di endpoint Backoffice, sesi POS tidak berlaku di perangkat lain, cakupan cabang, anti-eskalasi role, satu identitas dengan password + PIN.
- Shift: login ≠ buka shift, transaksi ditolak tanpa shift, perhitungan kas (kembalian & non-tunai tidak dihitung), satu shift per terminal, tutup paksa supervisor, izin laporan keuangan; persetujuan tutup shift dengan PIN atau password atasan — ditolak tanpa persetujuan, PIN salah, kasir biasa, diri sendiri, atau supervisor cabang lain; nama yang menyetujui tersimpan.
- Modul bisnis: master data (SKU otomatis, duplikat, validasi, izin lihat vs kelola), pembelian (draft → terima → lapisan FIFO, pembayaran & kelebihan bayar, dokumen terkunci, cakupan cabang), POS (harga dari server, stok berkurang, HPP tercatat, barang manual ditolak, stok kurang → transaksi tidak tersimpan, **penjualan paralel tidak melebihi stok**), opname/penyesuaian/kartu stok, transfer beserta HPP, pengeluaran & void, laba rugi, pengaturan (hanya Pemilik, diaudit), cabang.
- FIFO: HPP lintas lapisan (beli 10 @6.000 + 10 @8.000, jual 15 → 100.000), penjualan berurutan, opname/penyesuaian, transfer membawa lapisan, pembelian per pack, penjualan paralel tanpa lapisan terpakai ganda, stok minus, konversi produk (HPP FIFO pindah utuh, satuan tambahan, validasi & izin), invarian saldo = jumlah lapisan.
- Multi-satuan: validasi konversi, pembelian per pack → stok kg & HPP terkonversi, POS kg + pack (harga per satuan, struk), opname/penyesuaian dalam pack, ubah konversi.
- Laporan: angka setiap laporan operasional, stok, dan keuangan dicek terhadap data uji yang dihitung manual (diskon, refund, kas masuk/keluar, selisih kas, opname, transfer antar cabang, pembelian & hutang lewat jatuh tempo, pengeluaran), mutasi untuk periode lampau & mendatang, unduhan semua baris, serta izin & cakupan cabang (supervisor tanpa laporan keuangan, admin cabang hanya cabangnya).
- PDF laporan: karakter diganti ke WinAnsi, kop & kartu ringkasan, baris total, portrait/landscape otomatis, judul kolom & nomor halaman di setiap halaman, tabel kosong — memakai pustaka yang sama dengan browser.
- ID publik: respons 25 endpoint utama tanpa id angka, token stabil & tidak berurutan, id angka / token karangan / token diubah ditolak di path, query, dan body, media hanya lewat token + sesi.
- Paket & promo: stok isi paket berkurang FIFO & HPP paket, stok isi kurang ditolak, paket tidak bisa dibeli/bersarang, pembatasan cabang; diskon produk & kategori (potongan terbesar, nominal per satuan, terjadwal, cabang lain), kombinasi berulang, beli 2 gratis 1 & beli A dapat B 50%, `PRICE_CHANGED`, voucher (minimal belanja, potongan maksimal, kuota, cabang, **kuota tidak terlampaui oleh transaksi paralel**), izin & validasi; mesin harga (pembulatan Rupiah, urutan promo, petunjuk kasir, Σ baris = total).
- Metode pembayaran: metode bawaan, kode otomatis & nama unik, urutan, izin lihat vs kelola, dipakai POS (non-tunai tanpa kembalian & tidak masuk kas laci), hapus ditolak bila sudah dipakai, nonaktif ditolak POS, Tunai terkunci, serta muncul di laporan harian, filter transaksi, arus kas, dan dashboard.

---

## Checklist production

- [ ] `NODE_ENV=production`, aplikasi di belakang HTTPS (cookie `Secure` + `__Host-`, HSTS aktif).
- [ ] `CSRF_SECRET` dan `PIN_PEPPER` unik, disimpan di secret manager; **cadangkan `PIN_PEPPER`** terpisah dari backup database.
- [ ] `TRUST_PROXY` sesuai jumlah reverse proxy agar IP klien benar (`loopback` untuk Cloudflare Tunnel/Nginx di mesin yang sama).
- [ ] `APP_TIMEZONE` sesuai lokasi usaha (default `Asia/Jakarta`).
- [ ] `PUBLIC_URL` berisi domain aplikasi agar canonical, gambar pratinjau tautan, dan `sitemap.xml` memakai URL absolut; daftarkan `/sitemap.xml` di Google Search Console.
- [ ] Isi *Pengaturan → Profil usaha* (nama, alamat, telepon) sebelum mencetak struk.
- [ ] Pengguna database aplikasi bukan superuser.
- [ ] Backup harian aktif: `pm2 ls` menampilkan `dompet-backup`, dan `pm2 logs dompet-backup` berisi `OK` (lihat [Backup database](#backup-database)). Backup ini sudah mencakup folder `storage/` (atau `STORAGE_DIR`); tanpa folder itu foto produk & foto profil hilang (tampil 404).
- [ ] Buat akun Pemilik dengan `npm run create-admin`; jangan membuat akun bersama.
- [ ] Pasangkan setiap komputer kasir lewat `/pos/setup`; lepas pasangan perangkat yang tidak dipakai.
- [ ] Pantau `login_attempts` dan `audit_logs` (mis. lonjakan `auth.pos.login_failed`).

© PT HYBRID DAYA CAKRA GLOBAL — DOMPET USAHA
