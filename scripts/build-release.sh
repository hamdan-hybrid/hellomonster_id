#!/usr/bin/env bash
# Membuat paket rilis siap pasang dari folder aplikasi ini (dengan atau tanpa git):
#   npm run build                      → release/dompet-usaha-playground-<versi>.tar.gz (+ .sha256), folder
#                                        release/dompet-usaha-playground/ berisi hal yang sama (untuk diunggah ke git),
#                                        dan APK Kasir DU terbaru
#   bash scripts/build-release.sh DIR  → hasil ke folder DIR
# Isi paket = berkas aplikasi di daftar SOURCES + node_modules produksi, jadi server tujuan tidak perlu
# `npm install`. Kode di paket dipadatkan & diacak (scripts/build-protect.mjs: src/ dan public/js, CSS dipadatkan);
# PROTECT=0 npm run build → paket dengan kode apa adanya (mis. untuk melacak masalah).
# Hanya daftar itu yang diambil: .env, database (.data/), foto (storage/), test/, dan
# SDK-KASIR-ANDROID/ tidak pernah ikut. Folder git → isi dari commit HEAD; tanpa git → isi folder apa adanya.
# README.md di paket diambil dari docs/README-rilis.md (cara instal singkat). Cara memasang lengkap: INSTALL.md.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SOURCES=(src public scripts docs package.json package-lock.json README.md INSTALL.md setup.sh ecosystem.config.cjs ecosystem.production.config.cjs .env.example .gitignore)

VERSION=$(node -p "require('$ROOT/package.json').version")
# Salinan PLAY_GROUND (taman bermain), dibedakan dari paket RETAIL (dompet-usaha-<versi>): berkas
# dompet-usaha-playground-<versi>.tar.gz berisi satu folder dompet-usaha-playground/, juga nama folder pasang di server.
DIR=dompet-usaha-playground
NAME="dompet-usaha-playground-$VERSION"
OUT=$(realpath -m "${1:-$ROOT/release}")

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/$DIR"

if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  SOURCE=$(git -C "$ROOT" rev-parse --short HEAD)
  git -C "$ROOT" diff --quiet HEAD -- || echo "Catatan: ada perubahan yang belum di-commit; paket dibuat dari HEAD ($SOURCE)." >&2
  git -C "$ROOT" archive --format=tar HEAD -- "${SOURCES[@]}" | tar -x -C "$WORK/$DIR"
  echo "$SOURCE" > "$WORK/$DIR/COMMIT"
else
  SOURCE="tanpa git"
  tar -c -C "$ROOT" --exclude=node_modules --exclude='*.log' "${SOURCES[@]}" | tar -x -C "$WORK/$DIR"
fi
# README paket = docs/README-rilis.md (cara instal singkat, tanpa penjelasan fitur), versi & build terisi;
# README pengembangan dan berkas kerja terjemahan (docs/i18n*) tidak ikut.
mv "$WORK/$DIR/docs/README-rilis.md" "$WORK/$DIR/README.md"
sed -i "s/{{VERSI}}/$VERSION/g; s/{{COMMIT}}/$SOURCE/g" "$WORK/$DIR/README.md"
rm -f "$WORK/$DIR"/docs/i18n*
(cd "$WORK/$DIR" && npm ci --omit=dev --ignore-scripts --no-audit --no-fund --loglevel=error)
# Alat pemadat & pengacak diambil dari node_modules folder sumber (dev dependency), tidak ikut ke paket.
[ "${PROTECT:-1}" = "0" ] || node "$ROOT/scripts/build-protect.mjs" "$WORK/$DIR"

mkdir -p "$OUT"
tar -czf "$OUT/$NAME.tar.gz" -C "$WORK" --sort=name --owner=0 --group=0 "$DIR"
(cd "$OUT" && sha256sum "$NAME.tar.gz" > "$NAME.tar.gz.sha256")
# Isi yang sama sebagai folder, siap diunggah ke git repo rilis. Isinya diganti setiap build kecuali .git di dalamnya:
# git init / clone sekali di folder ini, lalu setiap selesai build cukup commit & push.
FOLDER="$OUT/$DIR"
mkdir -p "$FOLDER"
find "$FOLDER" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a "$WORK/$DIR/." "$FOLDER/"

APK=$(ls "$ROOT"/SDK-KASIR-ANDROID/dist/*.apk 2>/dev/null | sort -V | tail -n 1 || true)
[ -n "$APK" ] && cp "$APK" "$OUT/"

echo "Paket rilis $VERSION ($SOURCE):"
ls -lh "$OUT/$NAME.tar.gz" ${APK:+"$OUT/$(basename "$APK")"} | awk '{print "  " $5 "\t" $9}'
printf '  %s\t%s/\n' "$(du -sh "$FOLDER" | cut -f1)" "$FOLDER"
echo "SHA-256: $(cut -d' ' -f1 "$OUT/$NAME.tar.gz.sha256")"
