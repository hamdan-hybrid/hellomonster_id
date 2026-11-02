// Backup harian: database (pg_dump format custom) + folder storage/ (foto produk & profil), satu folder per tanggal
// di BACKUP_DIR (bawaan ~/backup-database/YYYY-MM-DD/). Hanya BACKUP_KEEP backup terbaru yang disimpan (bawaan 3):
// saat backup hari ke-4 selesai, backup hari ke-1 dihapus. Backup lama baru dihapus SETELAH backup baru lolos
// verifikasi, jadi backup yang gagal tidak pernah menghapus riwayat.
//   node scripts/backup-db.mjs            (cron 02.00 — lihat docs/backup.md)
// pg_dump minimal versi server (PostgreSQL 18): dicari di PG_BIN, /usr/lib/postgresql/18/bin, lalu PATH.
// BACKUP_DATE=YYYY-MM-DD hanya untuk uji (menamai folder dengan tanggal lain).

import { spawn } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..');
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;
const STALE_LOCK_MS = 6 * 60 * 60 * 1000;

const stamp = () => new Date().toLocaleString('sv-SE'); // 2026-10-25 02:00:03, waktu lokal server
const log = (msg) => console.log(`[${stamp()}] ${msg}`);
const mb = (bytes) => `${(bytes / 1048576).toFixed(2)} MB`;

function pgBin(name) {
  for (const dir of [process.env.PG_BIN, '/usr/lib/postgresql/18/bin'].filter(Boolean)) {
    if (fs.existsSync(path.join(dir, name))) return path.join(dir, name);
  }
  return name;
}

// Jalankan program; gagal bila kode keluar ≠ 0 (pesan berisi baris terakhir stderr, tanpa sandi).
function run(cmd, args, env = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { env: { ...process.env, ...env }, stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    let err = '';
    child.stdout.on('data', (d) => { out += d; });
    child.stderr.on('data', (d) => { err += d; });
    child.on('error', (e) => reject(new Error(e.code === 'ENOENT' ? `${cmd} tidak ditemukan (lihat docs/backup.md)` : e.message)));
    child.on('close', (code) => (code === 0
      ? resolve(out)
      : reject(new Error(`${path.basename(cmd)} gagal (kode ${code}): ${err.trim().split('\n').slice(-2).join(' | ')}`))));
  });
}

const sha256 = (file) => new Promise((resolve, reject) => {
  const h = crypto.createHash('sha256');
  fs.createReadStream(file).on('data', (d) => h.update(d)).on('end', () => resolve(h.digest('hex'))).on('error', reject);
});

// Koneksi dari DATABASE_URL (.env aplikasi) lewat variabel PG* — sandi tidak muncul di daftar proses.
function dbEnv() {
  try {
    process.loadEnvFile(process.env.ENV_FILE || path.join(ROOT, '.env'));
  } catch {
    // .env opsional bila DATABASE_URL sudah ada di environment.
  }
  let url;
  try {
    url = new URL(process.env.DATABASE_URL);
  } catch {
    throw new Error('DATABASE_URL tidak ada atau tidak valid di .env');
  }
  return {
    PGHOST: url.searchParams.get('host') || url.hostname || 'localhost',
    PGPORT: url.port || '5432',
    PGUSER: decodeURIComponent(url.username),
    PGPASSWORD: decodeURIComponent(url.password),
    PGDATABASE: decodeURIComponent(url.pathname.slice(1)),
    ...(url.searchParams.get('sslmode') ? { PGSSLMODE: url.searchParams.get('sslmode') } : {}),
  };
}

// Satu backup pada satu waktu; kunci yang tertinggal dari proses yang mati (> 6 jam) diabaikan.
function lock(dir) {
  const file = path.join(dir, '.lock');
  try {
    fs.mkdirSync(file);
  } catch {
    if (Date.now() - fs.statSync(file).mtimeMs < STALE_LOCK_MS) throw new Error(`backup lain sedang berjalan (${file})`);
    fs.rmSync(file, { recursive: true, force: true });
    fs.mkdirSync(file);
  }
  return () => fs.rmSync(file, { recursive: true, force: true });
}

async function main() {
  process.umask(0o077); // isi backup (data pelanggan, hash password) hanya terbaca pemilik
  const backupDir = path.resolve(process.env.BACKUP_DIR || path.join(os.homedir(), 'backup-database'));
  const keep = Number(process.env.BACKUP_KEEP || 3);
  if (!Number.isInteger(keep) || keep < 1) throw new Error('BACKUP_KEEP harus bilangan bulat ≥ 1');
  const day = process.env.BACKUP_DATE || new Date().toLocaleDateString('en-CA');
  if (!DAY_RE.test(day)) throw new Error('BACKUP_DATE harus berformat YYYY-MM-DD');
  const env = dbEnv();
  const storage = path.resolve(process.env.STORAGE_DIR || path.join(ROOT, 'storage'));

  fs.mkdirSync(backupDir, { recursive: true, mode: 0o700 });
  fs.chmodSync(backupDir, 0o700);
  const unlock = lock(backupDir);
  let tmp = null;
  try {
    // Sisa folder sementara dari backup yang terputus.
    for (const name of fs.readdirSync(backupDir)) {
      if (name.startsWith('.tmp-') || name.startsWith('.old-')) fs.rmSync(path.join(backupDir, name), { recursive: true, force: true });
    }
    tmp = fs.mkdtempSync(path.join(backupDir, `.tmp-${day}-`));

    const pgDump = pgBin('pg_dump');
    const dump = path.join(tmp, 'database.dump');
    // Komputer baru menyala: PM2 menjalankan backup bersamaan dengan database, jadi tunggu database siap (≤ 1 menit).
    // Galat lain (mis. sandi salah) langsung dilaporkan.
    for (let attempt = 1; ; attempt += 1) {
      try {
        await run(pgDump, ['--format=custom', '--compress=6', `--file=${dump}`], env);
        break;
      } catch (err) {
        if (attempt >= 7 || !/Connection refused|could not connect|starting up|shutting down/i.test(err.message)) throw err;
        await new Promise((resolve) => setTimeout(resolve, 10_000));
      }
    }
    // Verifikasi: arsip terbaca utuh oleh pg_restore dan berisi data tabel.
    const list = await run(pgBin('pg_restore'), ['--list', dump]);
    const tables = (list.match(/ TABLE DATA /g) || []).length;
    if (!tables) throw new Error('arsip database tidak berisi data tabel');

    const files = ['database.dump'];
    if (fs.existsSync(storage)) {
      await run('tar', ['-czf', path.join(tmp, 'storage.tar.gz'), '-C', path.dirname(storage), path.basename(storage)]);
      files.push('storage.tar.gz');
    }
    const sums = [];
    for (const f of files) sums.push(`${await sha256(path.join(tmp, f))}  ${f}`);
    fs.writeFileSync(path.join(tmp, 'SHA256SUMS'), `${sums.join('\n')}\n`);
    const version = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8')).version;
    fs.writeFileSync(path.join(tmp, 'INFO.txt'), [
      `DOMPET USAHA — backup ${day} (dibuat ${stamp()})`,
      `Aplikasi       : versi ${version}`,
      `Database       : ${env.PGDATABASE} di ${env.PGHOST}:${env.PGPORT}, ${tables} tabel berisi data`,
      `pg_dump        : ${(await run(pgDump, ['--version'])).trim()}`,
      `Isi            : ${files.join(', ')}, SHA256SUMS (cek: sha256sum -c SHA256SUMS)`,
      'Cara memulihkan: docs/backup.md di folder aplikasi.',
      '',
    ].join('\n'));

    // Resmikan; backup hari yang sama (dijalankan ulang) diganti.
    const target = path.join(backupDir, day);
    const old = path.join(backupDir, `.old-${day}`);
    if (fs.existsSync(target)) fs.renameSync(target, old);
    fs.renameSync(tmp, target);
    tmp = null;
    fs.rmSync(old, { recursive: true, force: true });

    // Simpan backup ini + (keep - 1) tanggal terbaru lainnya; hanya folder bernama tanggal yang pernah dihapus.
    // Backup yang baru dibuat tidak pernah ikut terhapus, walau ada folder bertanggal lebih baru (jam server salah).
    const others = fs.readdirSync(backupDir)
      .filter((n) => n !== day && DAY_RE.test(n) && fs.statSync(path.join(backupDir, n)).isDirectory())
      .sort()
      .reverse();
    const kept = [day, ...others.slice(0, keep - 1)];
    const removed = others.slice(keep - 1);
    for (const d of removed) fs.rmSync(path.join(backupDir, d), { recursive: true, force: true });

    const size = (f) => (fs.existsSync(path.join(target, f)) ? fs.statSync(path.join(target, f)).size : 0);
    log(`OK ${day}: database ${mb(size('database.dump'))} (${tables} tabel), foto ${mb(size('storage.tar.gz'))} → ${target}`);
    log(`   disimpan: ${kept.sort().join(', ')}${removed.length ? ` | dihapus: ${removed.sort().join(', ')}` : ''}`);
  } finally {
    if (tmp) fs.rmSync(tmp, { recursive: true, force: true });
    unlock();
  }
}

main().catch((err) => {
  log(`GAGAL: ${err.message}`);
  process.exitCode = 1;
});
