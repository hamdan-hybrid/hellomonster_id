'use strict';

// Membuat file .env berisi rahasia acak (sekali saja; tidak menimpa .env yang sudah ada).
//   npm run init-env

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const target = path.join(__dirname, '..', '.env');
if (fs.existsSync(target)) {
  console.log('.env sudah ada — tidak diubah.');
  process.exit(0);
}

const secret = () => crypto.randomBytes(48).toString('base64url');
const template = fs.readFileSync(path.join(__dirname, '..', '.env.example'), 'utf8');
const content = template
  .replace(/^CSRF_SECRET=.*$/m, `CSRF_SECRET=${secret()}`)
  .replace(/^PIN_PEPPER=.*$/m, `PIN_PEPPER=${secret()}`);
fs.writeFileSync(target, content, { mode: 0o600 });
console.log('.env dibuat dengan CSRF_SECRET dan PIN_PEPPER acak. Simpan PIN_PEPPER dengan aman — jika hilang, semua PIN harus di-reset.');
