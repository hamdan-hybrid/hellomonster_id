// Pemadat & pengacak kode untuk paket rilis. Dipanggil scripts/build-release.sh atas SALINAN aplikasi di folder
// kerja build — tidak pernah atas folder sumber:
//   node scripts/build-protect.mjs <folder-paket>
//  - public/js (kecuali vendor/ dan locale-*.js): dipadatkan esbuild, lalu nama variabel & fungsi diacak
//    javascript-obfuscator. Tanpa tabel teks tersandi: tabel itu memperbesar unduhan ±30% (terukur pada pos.js,
//    setelah brotli), padahal tujuan build ini juga halaman yang lebih ringan.
//  - public/js/locale-*.js: dipadatkan saja (isinya kamus teks, tetap JSON).
//  - public/css: dipadatkan.
//  - src/**/*.js: dipadatkan & diacak penuh — nama acak + teks dipindah ke tabel tersandi (base64). Kode server tidak
//    pernah diunduh browser, jadi ukurannya tidak berpengaruh. SQL migrasi & JSON tidak diubah.
// Rujukan modul './x.js' dibiarkan apa adanya agar versi aset (?v=, src/services/assets.js) tetap bekerja.
// HTML tidak diubah di sini: server memadatkan halaman saat dikirim (src/utils/html.js) dan mengompresnya.
// Pengacakan memakai pengaturan ringan (tanpa control-flow flattening / dead code) agar aplikasi tetap cepat.
import fs from 'node:fs';
import path from 'node:path';
import { transform } from 'esbuild';
import JavaScriptObfuscator from 'javascript-obfuscator';

const root = process.argv[2] && path.resolve(process.argv[2]);
if (!root || !fs.existsSync(path.join(root, 'package.json'))) {
  console.error('Pemakaian: node scripts/build-protect.mjs <folder-paket>');
  process.exit(1);
}

const OBFUSCATE = {
  compact: true,
  simplify: true,
  identifierNamesGenerator: 'mangled-shuffled',
  renameGlobals: false,
  stringArray: true,
  stringArrayEncoding: ['base64'],
  stringArrayThreshold: 0.75,
  stringArrayRotate: true,
  stringArrayShuffle: true,
  stringArrayIndexShift: true,
  stringArrayWrappersCount: 1,
  stringArrayWrappersType: 'function',
  splitStrings: false,
  controlFlowFlattening: false,
  deadCodeInjection: false,
  selfDefending: false,
  debugProtection: false,
  numbersToExpressions: false,
  transformObjectKeys: false,
  unicodeEscapeSequence: false,
  // Rujukan modul tetap teks biasa (dibaca versionJs untuk ?v=).
  reservedStrings: ['^\\./[\\w.-]+\\.m?js$'],
};
const BROWSER = { target: 'browser', stringArray: false };
const SERVER = { target: 'node', sourceType: 'script' };

const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
  const p = path.join(dir, e.name);
  return e.isDirectory() ? walk(p) : [p];
});

const stats = { files: 0, before: 0, after: 0 };
async function rewrite(file, fn) {
  const src = fs.readFileSync(file, 'utf8');
  const out = await fn(src);
  // Hasil harus tetap kode yang valid (esbuild mengurai ulang; galat = build gagal).
  await transform(out, { loader: file.endsWith('.css') ? 'css' : 'js', logLevel: 'silent' });
  fs.writeFileSync(file, out);
  stats.files += 1;
  stats.before += Buffer.byteLength(src);
  stats.after += Buffer.byteLength(out);
}

const minify = async (code, loader) => (await transform(code, { loader, minify: true, legalComments: 'none', target: 'es2022', charset: 'utf8' })).code;
const obfuscate = (code, options) => JavaScriptObfuscator.obfuscate(code, { ...OBFUSCATE, ...options }).getObfuscatedCode();

const jsDir = path.join(root, 'public', 'js');
for (const file of walk(jsDir)) {
  if (!/\.m?js$/.test(file) || file.includes(`${path.sep}vendor${path.sep}`)) continue;
  const name = path.basename(file);
  if (name.startsWith('locale-')) {
    // Tetap JSON murni dalam `export default …;` (format yang dijaga test/i18n.test.js), hanya tanpa spasi & komentar.
    await rewrite(file, (src) => `export default ${JSON.stringify(JSON.parse(src.slice(src.indexOf('{'), src.lastIndexOf('}') + 1)))};`);
    continue;
  }
  // theme-boot.js dimuat sebagai skrip biasa; lainnya modul ES.
  const sourceType = name === 'theme-boot.js' ? 'script' : 'module';
  await rewrite(file, async (src) => obfuscate(await minify(src, 'js'), { ...BROWSER, sourceType }));
}

for (const file of walk(path.join(root, 'public', 'css'))) {
  if (file.endsWith('.css')) await rewrite(file, (src) => minify(src, 'css'));
}

for (const file of walk(path.join(root, 'src'))) {
  if (file.endsWith('.js')) await rewrite(file, async (src) => obfuscate(await minify(src, 'js'), SERVER));
}

const kb = (n) => `${(n / 1024).toFixed(0)} KB`;
console.log(`Kode dipadatkan & diacak: ${stats.files} berkas, ${kb(stats.before)} → ${kb(stats.after)}`);
