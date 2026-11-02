// PM2 untuk server production — dipakai setup.sh: aplikasi (tanpa watch) + backup harian 02.00.
// Database memakai PostgreSQL server yang dipasang setup.sh, bukan dompet-db pengembangan di ecosystem.config.cjs.
//   pm2 ls                                                   → status
//   pm2 logs dompet-playground                               → log aplikasi
//   pm2 restart dompet-playground                            → muat ulang (mis. setelah .env diubah)
//   pm2 logs dompet-playground-backup --lines 20 --nostream  → hasil backup
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

// Node.js khusus aplikasi (~/.dompet-node/current, opsional — docs/node-update.md); belum dipasang → Node.js sistem.
const APP_NODE = path.join(process.env.DOMPET_NODE_DIR || path.join(os.homedir(), '.dompet-node'), 'current', 'bin', 'node');
const interpreter = fs.existsSync(APP_NODE) ? APP_NODE : 'node';

module.exports = {
  apps: [
    {
      name: 'dompet-playground',
      script: 'src/server.js',
      cwd: __dirname,
      interpreter,
      // Bila database belum siap saat server baru menyala, coba lagi beberapa detik kemudian.
      restart_delay: 3000,
    },
    {
      // Backup database + foto setiap 02.00, simpan 3 hari (docs/backup.md). Bukan proses yang terus berjalan:
      // status "stopped" di sela jadwal itu normal. Saat pertama dijalankan, backup langsung dibuat sekali.
      name: 'dompet-playground-backup',
      script: 'scripts/backup-db.mjs',
      cwd: __dirname,
      interpreter,
      cron_restart: '0 2 * * *',
      autorestart: false,
      env: { BACKUP_DIR: process.env.BACKUP_DIR || path.join(os.homedir(), 'backup-database-playground') },
    },
  ],
};
