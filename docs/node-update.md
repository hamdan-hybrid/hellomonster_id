# Node.js aplikasi & pembaruan otomatis

DOMPET USAHA berjalan dengan **Node.js khususnya (26.x)**, terpisah dari Node.js sistem (`/usr/bin/node`, 22.x dari
NodeSource) yang dipakai pm2, database pengembangan (`dompet-db`), dan aplikasi lain di komputer server (mis. `gate`).
Jadi pembaruan Node.js aplikasi tidak bisa merusak aplikasi lain, dan sebaliknya.

| Bagian | Lokasi |
|---|---|
| Node.js aplikasi | `~/.dompet-node/v<versi>`, dipakai lewat tautan `~/.dompet-node/current` |
| Pemilih interpreter pm2 | `ecosystem.config.cjs` — `current` ada → dipakai; tidak ada → Node.js sistem |
| Pembaru | `scripts/node-update/update-node.sh` (bash, tanpa sudo) |
| Catatan | `~/.dompet-node/update.log` |

## Cara kerja pembaruan

Dijalankan jadwal cron tiap malam pukul 03.15 (toko tutup, restart ±5 detik tidak mengganggu kasir):

1. Ambil daftar rilis `nodejs.org/dist/index.json`, pilih versi terbaru **dalam versi besar yang sama** (26.x). Rilis
   keamanan Node.js selalu terbit juga untuk versi besar yang masih didukung, jadi celah keamanan tertutup otomatis.
2. Unduh arsip + `SHASUMS256.txt` + tanda tangannya. Tanda tangan GPG diperiksa terhadap **kunci rilis resmi Node.js**
   (`github.com/nodejs/release-keys`), lalu SHA-256 arsip dicocokkan. Gagal salah satu → tidak dipasang.
3. Uji cepat dengan biner baru (`node -v`, modul aplikasi termuat, `node --check` semua `src/`), pindahkan tautan
   `current`, `pm2 restart dompet-usaha`, lalu cek kesehatan maks. 90 detik: proses pm2 benar-benar memakai biner baru
   **dan** `GET /api/health` menjawab `{"ok":true}`.
4. Tidak sehat → tautan dikembalikan ke versi sebelumnya, aplikasi direstart lagi, versi baru dihapus (rollback otomatis).
5. Tiga versi terakhir disimpan untuk cadangan.

**Naik versi besar (27, 28, …) tidak otomatis**: versi besar bisa membawa perubahan yang merusak. Pembaru hanya mencatat
di log bila versi LTS yang lebih baru tersedia. Lihat [Naik versi besar](#naik-versi-besar).

## Mengaktifkan (sekali, di komputer server, tanpa sudo)

```sh
cd ~/Desktop/DOMPET-USAHA
scripts/node-update/update-node.sh --no-restart        # pasang Node.js 26 terbaru (terverifikasi)
pm2 delete dompet-usaha && pm2 start ecosystem.config.cjs --only dompet-usaha && pm2 save
curl -s http://127.0.0.1:3009/api/health               # {"ok":true,...}
readlink -f /proc/$(pm2 pid dompet-usaha)/exe          # ~/.dompet-node/v26.x.y/bin/node
# Jadwal pembaruan tiap malam 03.15:
( crontab -l 2>/dev/null; echo "15 3 * * * $HOME/Desktop/DOMPET-USAHA/scripts/node-update/update-node.sh >/dev/null 2>&1 # dompet-node-update" ) | crontab -
```

`pm2 delete` + `pm2 start` diperlukan sekali karena interpreter proses pm2 tidak berganti lewat `pm2 restart`;
`pm2 save` membuat pilihan ini tetap berlaku setelah komputer dinyalakan ulang. Database tidak ikut direstart.

## Perintah sehari-hari

```sh
scripts/node-update/update-node.sh --check     # versi terpasang & terbaru
scripts/node-update/update-node.sh             # perbarui sekarang (sama seperti jadwal malam)
tail -n 20 ~/.dompet-node/update.log           # riwayat pembaruan
```

## Kembali ke Node.js sistem

```sh
crontab -l | grep -v dompet-node-update | crontab -
rm ~/.dompet-node/current
cd ~/Desktop/DOMPET-USAHA && pm2 delete dompet-usaha && pm2 start ecosystem.config.cjs --only dompet-usaha && pm2 save
```

## Naik versi besar

Uji dulu di salinan staging, mis. ke Node.js 28:

```sh
DOMPET_NODE_MAJOR=28 DOMPET_NODE_DIR=/tmp/node28 DOMPET_PM2_APP= scripts/node-update/update-node.sh --no-restart
PATH=/tmp/node28/current/bin:$PATH npm test
```

Bila lulus, ganti `MAJOR` bawaan di `update-node.sh` (atau tambahkan `DOMPET_NODE_MAJOR=28` di baris cron), lalu
jalankan `update-node.sh` sekali.

## Node.js sistem (pm2, dompet-db, gate)

Node.js sistem dikelola apt (repositori NodeSource `node_22.x`) dan tidak disentuh pembaru ini. Rilis keamanannya tetap
perlu dipasang, mis. 22.23.3 → 22.23.4 (rilis keamanan 20 Okt 2026):

```sh
sudo apt-get update && sudo apt-get install --only-upgrade nodejs
pm2 restart gate        # aplikasi lain memakai biner baru setelah direstart; pm2 & dompet-db saat komputer dinyalakan ulang
```
