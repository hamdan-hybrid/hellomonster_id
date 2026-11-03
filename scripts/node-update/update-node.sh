#!/usr/bin/env bash
# Pembaruan otomatis Node.js khusus DOMPET USAHA (tanpa sudo; Node.js sistem & aplikasi lain tidak disentuh).
#
# Node.js aplikasi dipasang di ~/.dompet-node/v<versi>, dipakai lewat tautan ~/.dompet-node/current
# (ecosystem.config.cjs → interpreter pm2). Dijalankan jadwal cron tiap malam yang dipasang pemilik server
# (docs/node-update.md):
#   1. Cari rilis terbaru dalam satu versi besar (bawaan 26.x — rilis keamanan & perbaikan) di nodejs.org.
#   2. Unduh, cocokkan SHA-256 dengan SHASUMS256.txt yang tanda tangan GPG-nya diperiksa terhadap kunci rilis
#      resmi Node.js (github.com/nodejs/release-keys). Gagal verifikasi → tidak dipasang.
#   3. Uji cepat (node -v, modul aplikasi termuat, sintaks src/), pindahkan tautan current, restart aplikasi pm2,
#      lalu cek kesehatan (proses memakai Node baru + /api/health menjawab). Gagal → kembali ke versi sebelumnya.
#   4. Simpan 3 versi terakhir untuk cadangan; catatan di ~/.dompet-node/update.log.
# Versi besar baru (mis. 28 LTS) hanya dicatat sebagai pemberitahuan: naik versi besar dilakukan manual setelah diuji,
# karena bisa membawa perubahan yang merusak.
#
# Pemakaian:
#   update-node.sh                 periksa & perbarui bila ada rilis baru
#   update-node.sh --check         hanya tampilkan versi terpasang & terbaru
#   update-node.sh --version 26.12.1   pasang versi tertentu (dalam versi besar yang sama)
#   update-node.sh --no-restart    pasang & pindahkan tautan tanpa restart pm2 (pemasangan awal / uji)
# Pengaturan (variabel lingkungan): DOMPET_NODE_MAJOR (26), DOMPET_NODE_DIR (~/.dompet-node),
#   DOMPET_PM2_APP (dompet-usaha; kosong = tanpa pm2), DOMPET_HEALTH_URL (http://127.0.0.1:<PORT di .env, bawaan 3009>/api/health).
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin:${PATH:-}"
umask 022

MAJOR="${DOMPET_NODE_MAJOR:-26}"
BASE="${DOMPET_NODE_DIR:-$HOME/.dompet-node}"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PM2_APP="${DOMPET_PM2_APP-dompet-usaha}"
# Port aplikasi dari .env-nya (bisa diganti lewat setup.sh).
APP_PORT="$({ sed -n 's/^PORT=//p' "$APP_DIR/.env" 2>/dev/null || true; } | tail -n 1)"
HEALTH_URL="${DOMPET_HEALTH_URL:-http://127.0.0.1:${APP_PORT:-3009}/api/health}"
DIST="https://nodejs.org/dist"
KEYS_URL="https://raw.githubusercontent.com/nodejs/release-keys/HEAD/gpg-only-active-keys/pubring.kbx"
KEEP=3
ARCH="linux-x64"
case "$(uname -m)" in aarch64 | arm64) ARCH="linux-arm64" ;; esac

MODE="update"
WANT=""
RESTART=1
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --version) WANT="${2#v}"; shift ;;
    --no-restart) RESTART=0 ;;
    *) echo "Pilihan tidak dikenal: $1" >&2; exit 2 ;;
  esac
  shift
done

mkdir -p "$BASE"
LOG="$BASE/update.log"
log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }

# Satu proses dalam satu waktu (cron & manual tidak bertabrakan).
exec 9>"$BASE/.lock"
flock -n 9 || { log "Pembaruan lain sedang berjalan; dilewati."; exit 0; }

TMP="$(mktemp -d "$BASE/.tmp-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

current_version() { [ -x "$BASE/current/bin/node" ] && "$BASE/current/bin/node" -v | sed 's/^v//' || true; }
# Node.js untuk membaca JSON daftar rilis: versi aplikasi bila ada, selain itu Node.js sistem.
json_node() { if [ -x "$BASE/current/bin/node" ]; then echo "$BASE/current/bin/node"; else command -v node; fi; }

CUR="$(current_version)"
curl -fsSL --retry 3 --max-time 60 "$DIST/index.json" -o "$TMP/index.json"
# Baris: versi-terbaru-dalam-MAJOR, "security"/"", versi besar LTS terbaru.
read -r LATEST SECURITY LTS_MAJOR < <("$(json_node)" -e '
  const list = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const major = process.argv[2];
  const hit = list.find((r) => r.version.startsWith(`v${major}.`) && r.files.includes(process.argv[3]));
  const lts = list.filter((r) => r.lts).map((r) => Number(r.version.slice(1).split(".")[0]));
  console.log(hit ? hit.version.slice(1) : "-", hit && hit.security ? "security" : "-", lts.length ? Math.max(...lts) : 0);
' "$TMP/index.json" "$MAJOR" "$ARCH")

if [ "$MODE" = "check" ]; then
  echo "Terpasang : ${CUR:-belum ada}  ($BASE/current)"
  echo "Terbaru   : $LATEST (Node.js $MAJOR.x)$( [ "$SECURITY" = security ] && echo ' — rilis keamanan')"
  [ "$LTS_MAJOR" -gt "$MAJOR" ] && echo "Catatan   : Node.js $LTS_MAJOR LTS tersedia — naik versi besar dilakukan manual setelah diuji."
  exit 0
fi

TARGET="${WANT:-$LATEST}"
[ "$TARGET" != "-" ] || { log "GAGAL: tidak ada rilis Node.js $MAJOR.x untuk $ARCH."; exit 1; }
[ "${TARGET%%.*}" = "$MAJOR" ] || { log "GAGAL: $TARGET bukan Node.js $MAJOR.x (naik versi besar dilakukan manual)."; exit 1; }
[ "$LTS_MAJOR" -gt "$MAJOR" ] && log "Info: Node.js $LTS_MAJOR LTS tersedia; aplikasi tetap di $MAJOR.x sampai dinaikkan manual."
if [ "$TARGET" = "$CUR" ]; then
  log "Node.js $CUR sudah terbaru (Node.js $MAJOR.x)."
  exit 0
fi

# ---------- Unduh & verifikasi ----------
NAME="node-v$TARGET-$ARCH"
log "Memasang Node.js $TARGET$( [ "$SECURITY" = security ] && [ -z "$WANT" ] && echo ' (rilis keamanan)') — sebelumnya ${CUR:-tidak ada}."
curl -fsSL --retry 3 --max-time 60 "$DIST/v$TARGET/SHASUMS256.txt" -o "$TMP/SHASUMS256.txt"
curl -fsSL --retry 3 --max-time 60 "$DIST/v$TARGET/SHASUMS256.txt.sig" -o "$TMP/SHASUMS256.txt.sig"
# Kunci rilis Node.js: diperbarui dari repositori resmi; bila gagal diunduh, pakai salinan terakhir yang tersimpan.
if curl -fsSL --retry 3 --max-time 60 "$KEYS_URL" -o "$TMP/pubring.kbx" && [ -s "$TMP/pubring.kbx" ]; then
  mv "$TMP/pubring.kbx" "$BASE/release-keys.kbx"
fi
[ -s "$BASE/release-keys.kbx" ] || { log "GAGAL: kunci rilis Node.js tidak tersedia."; exit 1; }
if ! gpgv --keyring "$BASE/release-keys.kbx" "$TMP/SHASUMS256.txt.sig" "$TMP/SHASUMS256.txt" 2>"$TMP/gpg.txt"; then
  log "GAGAL: tanda tangan SHASUMS256.txt tidak sah — tidak dipasang. $(tr '\n' ' ' < "$TMP/gpg.txt")"
  exit 1
fi
curl -fsSL --retry 3 --max-time 600 "$DIST/v$TARGET/$NAME.tar.xz" -o "$TMP/$NAME.tar.xz"
(cd "$TMP" && grep " $NAME.tar.xz\$" SHASUMS256.txt | sha256sum -c --status) || { log "GAGAL: SHA-256 $NAME.tar.xz tidak cocok — tidak dipasang."; exit 1; }
log "Verifikasi lulus: tanda tangan GPG rilis Node.js & SHA-256."

# ---------- Pasang & uji cepat ----------
rm -rf "${TMP:?}/x" && mkdir "$TMP/x"
tar -xJf "$TMP/$NAME.tar.xz" -C "$TMP/x"
NEW="$TMP/x/$NAME/bin/node"
[ "$("$NEW" -v)" = "v$TARGET" ] || { log "GAGAL: biner Node.js $TARGET tidak berjalan."; exit 1; }
if ! (cd "$APP_DIR" && "$NEW" -e 'for (const m of ["express", "pg", "helmet", "compression", "cookie-parser"]) require(m)' &&
  find src -name '*.js' -print0 | xargs -0 -n 1 "$NEW" --check); then
  log "GAGAL: aplikasi tidak lolos uji cepat dengan Node.js $TARGET — tidak dipasang."
  exit 1
fi
rm -rf "${BASE:?}/v$TARGET"
mv "$TMP/x/$NAME" "$BASE/v$TARGET"

switch_to() { ln -sfn "v$1" "$BASE/current.new" && mv -Tf "$BASE/current.new" "$BASE/current"; }

# Proses pm2 benar-benar memakai biner versi itu, dan aplikasi menjawab /api/health (maks. 90 detik).
healthy() {
  local want="$1" pid exe
  for _ in $(seq 1 45); do
    sleep 2
    pid="$(pm2 pid "$PM2_APP" 2>/dev/null | tail -n1)"
    [ -n "$pid" ] && [ "$pid" != "0" ] || continue
    exe="$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)"
    [ "$exe" = "$(readlink -f "$BASE/v$want/bin/node")" ] || continue
    curl -fsS --max-time 5 "$HEALTH_URL" 2>/dev/null | grep -q '"ok":true' && return 0
  done
  return 1
}

switch_to "$TARGET"
if [ "$RESTART" = 1 ] && [ -n "$PM2_APP" ]; then
  pm2 restart "$PM2_APP" >/dev/null
  if healthy "$TARGET"; then
    log "BERHASIL: $PM2_APP berjalan dengan Node.js $TARGET."
  else
    log "GAGAL: $PM2_APP tidak sehat dengan Node.js $TARGET — kembali ke ${CUR:-Node.js sistem}."
    if [ -n "$CUR" ] && [ -x "$BASE/v$CUR/bin/node" ]; then switch_to "$CUR"; else rm -f "$BASE/current"; fi
    pm2 restart "$PM2_APP" >/dev/null
    if [ -n "$CUR" ] && healthy "$CUR"; then log "Dipulihkan: $PM2_APP kembali berjalan dengan Node.js $CUR."; else log "PERHATIAN: periksa $PM2_APP (pm2 logs $PM2_APP)."; fi
    rm -rf "${BASE:?}/v$TARGET"
    exit 1
  fi
else
  log "Node.js $TARGET terpasang di $BASE/current (tanpa restart pm2)."
fi

# ---------- Simpan beberapa versi terakhir ----------
ls -1d "$BASE"/v[0-9]* 2>/dev/null | sed 's|.*/v||' | sort -V | head -n "-$KEEP" | while read -r old; do
  [ "$old" = "$TARGET" ] || [ "$old" = "$CUR" ] || { rm -rf "${BASE:?}/v$old"; log "Versi lama dihapus: $old"; }
done
