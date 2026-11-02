// PostgreSQL lokal untuk pengembangan, tanpa instalasi sistem (paket embedded-postgres).
// Production WAJIB memakai server PostgreSQL sungguhan.
//   npm run dev-db   → postgres://postgres:<sandi>@localhost:5433/dompet_usaha
// Sandi diambil dari DATABASE_URL di .env (bawaan "postgres"), agar database yang baru dibuat
// tetap cocok dengan .env setelah sandinya diganti.

import fs from 'node:fs';
import path from 'node:path';
import EmbeddedPostgres from 'embedded-postgres';

try {
  process.loadEnvFile(path.resolve(import.meta.dirname, '..', '.env'));
} catch {
  // .env opsional.
}
let password = 'postgres';
try {
  password = decodeURIComponent(new URL(process.env.DATABASE_URL).password) || password;
} catch {
  // DATABASE_URL kosong/tidak valid → sandi bawaan.
}

const dataDir = path.resolve(import.meta.dirname, '..', '.data', 'pg');
const fresh = !fs.existsSync(path.join(dataDir, 'PG_VERSION'));
const pg = new EmbeddedPostgres({ databaseDir: dataDir, user: 'postgres', password, port: 5433, persistent: true });

if (fresh) await pg.initialise();
await pg.start();
if (fresh) await pg.createDatabase('dompet_usaha');
console.log('PostgreSQL dev berjalan: postgres://postgres:***@localhost:5433/dompet_usaha (Ctrl+C untuk berhenti)');

const stop = async () => {
  await pg.stop();
  process.exit(0);
};
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
