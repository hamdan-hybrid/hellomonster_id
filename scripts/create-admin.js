'use strict';

// Membuat akun Pemilik (owner) pertama. Tidak ada akun demo bawaan di database.
//
//   npm run create-admin
//     interaktif: password diketik operator, tidak pernah ditampilkan atau dicatat.
//   ADMIN_USERNAME=… ADMIN_PASSWORD=… node scripts/create-admin.js
//     tanpa pertanyaan (dipakai setup.sh); opsional ADMIN_FULL_NAME, BUSINESS_NAME, BRANCH_CODE, BRANCH_NAME.
//     ADMIN_PASSWORD adalah password sementara: wajib diganti saat pertama masuk Backoffice, dan password penggantinya
//     yang harus memenuhi aturan password (min. 10 karakter, huruf + angka).

const readline = require('node:readline');
const config = require('../src/config');
const { migrate } = require('../src/db/migrate');
const db = require('../src/db/pool');
const hash = require('../src/security/hash');
const settings = require('../src/services/settings');

// Nama usaha bawaan pada pemasangan baru (struk & kop laporan); bisa diubah di Pengaturan → Profil usaha.
const DEFAULT_BUSINESS_NAME = 'PT HYBRID DAYA CAKRA GLOBAL';

// Satu antarmuka readline untuk semua input (interaktif maupun via pipe).
// Saat mengetik password, gema ke terminal dimatikan.
const rl = readline.createInterface({ input: process.stdin, output: process.stdout, terminal: Boolean(process.stdin.isTTY) });
const lines = rl[Symbol.asyncIterator]();
let muted = false;
rl._writeToOutput = (s) => {
  if (!muted) rl.output.write(s);
};

async function ask(question) {
  process.stdout.write(question);
  const { value, done } = await lines.next();
  if (done) throw new Error('Input berakhir sebelum semua data diisi.');
  return value.trim();
}

async function askHidden(question) {
  muted = true;
  try {
    process.stdout.write(question);
    const { value, done } = await lines.next();
    if (done) throw new Error('Input berakhir sebelum semua data diisi.');
    return value;
  } finally {
    muted = false;
    process.stdout.write('\n');
  }
}

async function main() {
  await migrate(config.databaseUrl, { log: () => {} });
  if (process.env.ADMIN_USERNAME) return createFromEnv();

  console.log('=== DOMPET USAHA — Buat akun Pemilik ===\n');

  // Profil usaha belum pernah disimpan = pemasangan baru: tanyakan nama usaha sekali.
  let businessName = null;
  const { rowCount: hasBusiness } = await db.query("SELECT 1 FROM app_settings WHERE key = 'business'");
  if (!hasBusiness) {
    businessName = (await ask(`Nama usaha (Enter = ${DEFAULT_BUSINESS_NAME}): `)) || DEFAULT_BUSINESS_NAME;
    if (businessName.length < 2 || businessName.length > 120) throw new Error('Nama usaha 2–120 karakter.');
  }

  const { rows: branches } = await db.query('SELECT id, code, name FROM branches ORDER BY id');
  let branchId;
  if (!branches.length) {
    console.log('Belum ada cabang. Buat cabang pertama:');
    const code = (await ask('  Kode cabang (mis. PUSAT): ')).toUpperCase();
    const name = await ask('  Nama cabang: ');
    if (!/^[A-Z0-9-]{2,20}$/.test(code) || !name) throw new Error('Kode/nama cabang tidak valid.');
    const { rows } = await db.query('INSERT INTO branches (code, name) VALUES ($1, $2) RETURNING id', [code, name]);
    branchId = rows[0].id;
  } else {
    console.log('Cabang tersedia:');
    for (const b of branches) console.log(`  [${b.id}] ${b.code} — ${b.name}`);
    branchId = Number(await ask('ID cabang utama pengguna: '));
    if (!branches.some((b) => b.id === branchId)) throw new Error('Cabang tidak ditemukan.');
  }

  const username = (await ask('Username: ')).toLowerCase();
  if (!/^[a-z0-9._-]{3,50}$/.test(username)) throw new Error('Username hanya huruf kecil, angka, titik, garis bawah, strip (3–50).');
  const fullName = await ask('Nama lengkap: ');
  if (fullName.length < 2) throw new Error('Nama lengkap wajib diisi.');
  const email = (await ask('Email (opsional): ')).toLowerCase() || null;

  const password = await askHidden('Password (min. 10 karakter, huruf + angka): ');
  const problem = hash.validateNewPassword(password);
  if (problem) throw new Error(problem);
  if ((await askHidden('Ulangi password: ')) !== password) throw new Error('Password tidak sama.');

  rl.close();
  await createOwner({ username, email, fullName, branchId, password, businessName, source: 'cli' });
}

// Tanpa pertanyaan (setup.sh): cabang pertama dibuat bila belum ada, nama usaha diisi bila belum pernah disimpan.
async function createFromEnv() {
  rl.close();
  const env = process.env;
  const username = env.ADMIN_USERNAME.toLowerCase();
  const password = env.ADMIN_PASSWORD ?? '';
  if (!/^[a-z0-9._-]{3,50}$/.test(username)) throw new Error('Username hanya huruf kecil, angka, titik, garis bawah, strip (3–50).');
  if (!password || password.length > 200) throw new Error('ADMIN_PASSWORD wajib diisi (maks. 200 karakter).');

  const { rowCount: hasBusiness } = await db.query("SELECT 1 FROM app_settings WHERE key = 'business'");
  let branchId = (await db.query('SELECT id FROM branches ORDER BY id LIMIT 1')).rows[0]?.id;
  if (!branchId) {
    const code = (env.BRANCH_CODE || 'PUSAT').toUpperCase();
    const name = env.BRANCH_NAME || 'Pusat';
    if (!/^[A-Z0-9-]{2,20}$/.test(code)) throw new Error('Kode/nama cabang tidak valid.');
    branchId = (await db.query('INSERT INTO branches (code, name) VALUES ($1, $2) RETURNING id', [code, name])).rows[0].id;
  }
  await createOwner({
    username,
    email: null,
    fullName: env.ADMIN_FULL_NAME || 'Pemilik',
    branchId,
    password,
    businessName: hasBusiness ? null : env.BUSINESS_NAME || DEFAULT_BUSINESS_NAME,
    mustChangePassword: true,
    source: 'setup',
  });
  console.log('Password ini sementara: wajib diganti saat pertama masuk Backoffice.');
}

async function createOwner({ username, email, fullName, branchId, password, businessName, mustChangePassword = false, source }) {
  const passwordHash = await hash.hashPassword(password);
  await db.transaction(async (client) => {
    const { rows } = await client.query(
      `INSERT INTO users (username, email, full_name, branch_id, password_hash, password_updated_at, must_change_password,
                          backoffice_access, pos_access)
       VALUES ($1, $2, $3, $4, $5, now(), $6, TRUE, FALSE) RETURNING id`,
      [username, email, fullName, branchId, passwordHash, mustChangePassword],
    );
    await client.query("INSERT INTO user_roles (user_id, role_id) SELECT $1, id FROM roles WHERE code = 'owner'", [rows[0].id]);
    if (businessName) await settings.setSection('business', { ...settings.DEFAULTS.business, name: businessName }, rows[0].id, client);
    await client.query(
      `INSERT INTO audit_logs (actor_user_id, action, target_type, target_id, branch_id, details)
       VALUES (NULL, 'user.created', 'user', $1, $2, $3)`,
      [rows[0].id, branchId, { source, role: 'owner' }],
    );
  });
  if (businessName) console.log(`\nNama usaha: ${businessName}`);
  console.log(`\nAkun Pemilik "${username}" berhasil dibuat. Masuk di /login.`);
}

main()
  .catch((err) => {
    console.error(`\nGagal: ${err.code === '23505' ? 'Username atau email sudah digunakan.' : err.message}`);
    process.exitCode = 1;
  })
  .finally(() => {
    rl.close();
    db.pool.end();
  });
