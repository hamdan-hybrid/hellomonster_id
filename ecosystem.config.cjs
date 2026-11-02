// PM2: database pengembangan (embedded PostgreSQL) + aplikasi DOMPET USAHA + backup harian.
//   pm2 start ecosystem.config.cjs   → jalankan semuanya
//   pm2 logs dompet-usaha            → lihat log aplikasi
//   pm2 logs dompet-backup           → hasil backup harian
//   pm2 restart dompet-usaha         → muat ulang aplikasi
//   pm2 save                         → ingat daftar ini agar menyala lagi setelah komputer restart
// .env dibaca dari folder ini (cwd), sama seperti `npm run dev`.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

// Aplikasi memakai Node.js khususnya (~/.dompet-node/current, diperbarui otomatis oleh scripts/node-update),
// terpisah dari Node.js sistem yang dipakai pm2 & aplikasi lain. Belum dipasang → Node.js sistem.
const APP_NODE = path.join(process.env.DOMPET_NODE_DIR || path.join(os.homedir(), '.dompet-node'), 'current', 'bin', 'node');

module.exports = {
  apps: [
    {
      name: 'dompet-db',
      script: 'scripts/dev-db.mjs',
      cwd: __dirname,
      // dev-db.mjs menghentikan PostgreSQL dengan rapi saat menerima SIGINT; beri waktu cukup sebelum dipaksa.
      kill_timeout: 20000,
      restart_delay: 3000,
    },
    {
      name: 'dompet-usaha',
      script: 'src/server.js',
      cwd: __dirname,
      interpreter: fs.existsSync(APP_NODE) ? APP_NODE : 'node',
      // Muat ulang otomatis saat kode server berubah (pengganti `node --watch`); folder public/ dilayani langsung.
      watch: ['src'],
      watch_delay: 1500,
      // Bila database belum siap saat start, coba lagi beberapa detik kemudian.
      restart_delay: 3000,
    },
    {
      // Backup harian pukul 02.00 (scripts/backup-db.mjs, simpan 3 hari — docs/backup.md), tanpa crontab.
      // Bukan proses yang terus berjalan: PM2 menjalankannya sesuai jadwal, skrip selesai, lalu menunggu jadwal
      // berikutnya ("stopped" itu normal). Saat PM2 menyala (start / komputer restart) backup juga langsung dibuat
      // sekali; backup di tanggal yang sama diganti, jadi aman.
      name: 'dompet-backup',
      script: 'scripts/backup-db.mjs',
      cwd: __dirname,
      interpreter: fs.existsSync(APP_NODE) ? APP_NODE : 'node',
      cron_restart: '0 2 * * *',
      autorestart: false,
    },
  ],
};
