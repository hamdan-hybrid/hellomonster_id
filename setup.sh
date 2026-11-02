#!/usr/bin/env bash
# Pemasangan otomatis DOMPET USAHA di server Ubuntu 22.04 / 24.04. Jalankan dari folder paket rilis yang sudah
# diekstrak. Satu perintah menyiapkan semuanya: PostgreSQL 18, Node.js, pm2, .env, database + migrasi, aplikasi
# dan backup harian 02.00 di pm2, serta menyala sendiri setiap server restart.
#   ./setup.sh                                          pemasangan baru, dibuka di jaringan lokal (http://IP-server:2026)
#   ./setup.sh --domain playground.dompetusaha.com      pemasangan baru, dibuka lewat domain HTTPS (Cloudflare Tunnel)
#   ./setup.sh --env ~/env-lama --restore ~/2026-11-03  pindah server: .env + backup (database & foto) server lama
#   ./setup.sh                                          lagi, setelah paket versi baru diekstrak ke folder ini = update
# Pemasangan baru (tanpa --restore) dimulai dengan data kosong: nama usaha PT HYBRID DAYA CAKRA GLOBAL, cabang PUSAT,
# dan akun Pemilik owner / owner123. Password itu sementara: wajib diganti saat pertama masuk Backoffice. Nilai bawaan
# bisa diganti lewat environment: OWNER_USERNAME=… OWNER_PASSWORD=… BUSINESS_NAME="…" ./setup.sh
# Pilihan lain: --port N (bawaan 2026). Dengan --domain, token Cloudflare Tunnel ditanyakan bila cloudflared belum
# berjalan (tanpa terminal interaktif: CLOUDFLARE_TUNNEL_TOKEN=... ./setup.sh ...).
# Aman dijalankan ulang: yang sudah ada tidak dibuat ulang, data tidak pernah dihapus atau ditimpa, dan sebelum versi
# baru dimuat database dibackup dulu. Jalankan sebagai pengguna biasa yang punya sudo, bukan root. Panduan: INSTALL.md.
set -Eeuo pipefail

APP=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$APP"
ENV_FILE="$APP/.env"
ECOSYSTEM=ecosystem.production.config.cjs
APP_NAME=dompet-playground
BACKUP_NAME=dompet-playground-backup
DB_NAME=dompet_usaha
DB_USER=dompet
PG_VERSION=18
PGBIN=/usr/lib/postgresql/$PG_VERSION/bin
NODE_MAJOR=26
# Harus sama dengan bawaan di ecosystem.production.config.cjs.
BACKUP_DIR=${BACKUP_DIR:-$HOME/backup-database-playground}
# Data awal pemasangan baru (lihat keterangan di atas).
OWNER_USERNAME=${OWNER_USERNAME:-owner}
OWNER_PASSWORD=${OWNER_PASSWORD:-owner123}
BUSINESS_NAME=${BUSINESS_NAME:-PT HYBRID DAYA CAKRA GLOBAL}
ME=$(id -un)

if [ -t 1 ]; then BOLD=$'\e[1m' RED=$'\e[31m' RESET=$'\e[0m'; else BOLD='' RED='' RESET=''; fi
step() { printf '\n%s== %s%s\n' "$BOLD" "$*" "$RESET"; }
ok() { printf '   ✓ %s\n' "$*"; }
note() { printf '   • %s\n' "$*"; }
die() { printf '\n%sGAGAL: %s%s\n' "$RED" "$*" "$RESET" >&2; exit 1; }
usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; }
trap 'printf "\n%sGAGAL di baris %s: %s%s\n" "$RED" "$LINENO" "$BASH_COMMAND" "$RESET" >&2' ERR

DOMAIN='' PORT_ARG='' ENV_IMPORT='' RESTORE=''
while [ $# -gt 0 ]; do
  case $1 in
    --domain | --port | --env | --restore)
      [ $# -ge 2 ] && [ -n "$2" ] || die "$1 butuh nilai (lihat ./setup.sh --help)"
      case $1 in
        --domain) DOMAIN=$2 ;;
        --port) PORT_ARG=$2 ;;
        --env) ENV_IMPORT=$(realpath -m "$2") ;;
        --restore) RESTORE=$(realpath -m "$2") ;;
      esac
      shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) die "pilihan tidak dikenal: $1 (lihat ./setup.sh --help)" ;;
  esac
done

# ── .env & database: pembantu ────────────────────────────────────────────────────────────────────────────────────
env_get() { { sed -n "s/^$1=//p" "${2:-$ENV_FILE}" 2>/dev/null || true; } | tail -n 1; }
# Ganti baris KUNCI= (atau "# KUNCI=" bawaan .env.example), atau tambahkan di akhir. Nilai lewat environment,
# bukan argumen, agar sandi database tidak tampil di daftar proses.
env_set() {
  ENV_KEY=$1 ENV_VALUE=$2 ENV_PATH=$ENV_FILE node -e '
    const fs = require("node:fs");
    const { ENV_KEY: key, ENV_VALUE: value, ENV_PATH: file } = process.env;
    const lines = fs.readFileSync(file, "utf8").replace(/\n$/, "").split("\n");
    let i = lines.findLastIndex((l) => l.startsWith(`${key}=`));
    if (i < 0) i = lines.findLastIndex((l) => l.startsWith(`# ${key}=`));
    if (i < 0) lines.push(`${key}=${value}`);
    else lines[i] = `${key}=${value}`;
    fs.writeFileSync(file, `${lines.join("\n")}\n`, { mode: 0o600 });'
}
env_disable() { sed -i "s|^$1=\(.*\)\$|# $1=\1  (dinonaktifkan setup.sh: $2)|" "$ENV_FILE"; }

cluster() { { pg_lsclusters -h 2>/dev/null || true; } | awk -v v="$PG_VERSION" '$1 == v && $2 == "main"'; }
pg_admin() { (cd / && sudo -u postgres "$PGBIN/psql" -X -q -v ON_ERROR_STOP=1 -p "$PG_PORT" "$@"); }
# Sandi aplikasi dari DATABASE_URL buatan skrip ini (hex); bentuk lain dianggap belum disiapkan.
db_pass() { env_get DATABASE_URL | sed -n "s|^postgres://$DB_USER:\([0-9a-f]\{32,\}\)@localhost:$PG_PORT/$DB_NAME\$|\1|p"; }
app_psql() { PGPASSWORD=$(db_pass) "$PGBIN/psql" -X -qAt -h localhost -p "$PG_PORT" -U "$DB_USER" -d "$DB_NAME" "$@"; }
db_ok() { [ -n "$(db_pass)" ] && app_psql -c 'SELECT 1' >/dev/null 2>&1; }
table_count() { app_psql -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'"; }

# Nama proses terdaftar di pm2. JSON jlist ada di baris terakhir: sebelumnya bisa ada peringatan, atau pesan
# "Spawning PM2 daemon" saat pm2 pertama kali dipakai di server baru.
pm2_has() {
  pm2 jlist 2>/dev/null | node -e '
    let s = "";
    process.stdin.on("data", (c) => { s += c; }).on("end", () => {
      let list = [];
      try { list = JSON.parse(s.trim().split("\n").pop() || "[]"); } catch {}
      process.exit(list.some((p) => p.name === process.argv[1]) ? 0 : 1);
    });' "$1"
}

has_pkg() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }
apt_install() { sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -q "$@" >/dev/null; }
node_ok() {
  command -v node >/dev/null &&
    node -e 'const [a, b] = process.versions.node.split(".").map(Number); process.exit(a > 20 || (a === 20 && b >= 12) ? 0 : 1)'
}

# Cloudflare Tunnel: paket resmi cloudflared, token di berkas khusus root (bukan di baris perintah layanan, yang
# terbaca semua pengguna). Rute domain → http://localhost:PORT diatur di dasbor Cloudflare.
install_tunnel() {
  if ! command -v cloudflared >/dev/null; then
    sudo install -d -m 0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' |
      sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
    sudo apt-get update -q >/dev/null
    apt_install cloudflared
  fi
  printf '%s\n' "$1" | sudo sh -c 'umask 077 && mkdir -p /etc/cloudflared && cat > /etc/cloudflared/token'
  sudo tee /etc/systemd/system/cloudflared.service >/dev/null <<'UNIT'
[Unit]
Description=Cloudflare Tunnel client
After=network-online.target
Wants=network-online.target

[Service]
TimeoutStartSec=15
Type=notify
ExecStart=/usr/bin/cloudflared --no-autoupdate tunnel run --token-file /etc/cloudflared/token
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
UNIT
  sudo systemctl daemon-reload
  sudo systemctl enable --now cloudflared >/dev/null 2>&1 ||
    die 'cloudflared gagal berjalan — periksa tokennya (sudo journalctl -u cloudflared -n 20), lalu jalankan ./setup.sh lagi.'
}

# ── Pemeriksaan awal ─────────────────────────────────────────────────────────────────────────────────────────────
[ "$(id -u)" -ne 0 ] || die 'jalankan sebagai pengguna biasa yang punya sudo, bukan root (aplikasi & pm2 berjalan atas nama pengguna itu).'
[ -f package.json ] && [ -f src/server.js ] && [ -f "$ECOSYSTEM" ] || die "jalankan dari folder paket rilis DOMPET USAHA (berisi package.json, src/, $ECOSYSTEM)."
command -v apt-get >/dev/null && command -v sudo >/dev/null || die 'skrip ini untuk Ubuntu/Debian (apt + sudo). Sistem lain: ikuti INSTALL.md.'
[ -z "$PORT_ARG" ] || [[ $PORT_ARG =~ ^[0-9]+$ && $PORT_ARG -ge 1024 && $PORT_ARG -le 65535 ]] || die '--port harus angka 1024–65535.'
if [ -n "$DOMAIN" ]; then
  DOMAIN=${DOMAIN#http://} DOMAIN=${DOMAIN#https://} DOMAIN=${DOMAIN%%/*}
  [[ $DOMAIN =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || die "--domain tidak valid: $DOMAIN"
fi
[ -z "$ENV_IMPORT" ] || [ -f "$ENV_IMPORT" ] || die "file .env lama tidak ada: $ENV_IMPORT"
[ -z "$RESTORE" ] || [ -f "$RESTORE/database.dump" ] || die "folder backup harus berisi database.dump: $RESTORE"
# .env yang sedang dipakai tidak pernah ditimpa: rahasianya mengunci PIN kasir & sandi email yang tersimpan.
if [ -n "$ENV_IMPORT" ] && [ -f "$ENV_FILE" ]; then
  for key in CSRF_SECRET PIN_PEPPER; do
    [ "$(env_get $key)" = "$(env_get $key "$ENV_IMPORT")" ] ||
      die ".env di folder ini sudah ada dan $key-nya berbeda dengan $ENV_IMPORT — tidak ditimpa. Hapus .env ini dulu bila memang belum dipakai."
  done
fi

step 'Hak sudo'
sudo -v || die 'butuh hak sudo.'
ok "pengguna $ME"

# ── Program pendukung ────────────────────────────────────────────────────────────────────────────────────────────
step 'Program pendukung'
missing=()
for pkg in curl ca-certificates gnupg postgresql-common; do has_pkg "$pkg" || missing+=("$pkg"); done
if [ ${#missing[@]} -gt 0 ]; then
  sudo apt-get update -q >/dev/null
  apt_install "${missing[@]}"
fi
if ! has_pkg "postgresql-$PG_VERSION"; then
  # Repositori resmi PostgreSQL: versi yang sama dengan server pembuat backup (pg_restore tidak membaca arsip versi
  # yang lebih baru darinya).
  sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y >/dev/null
  apt_install "postgresql-$PG_VERSION"
fi
ok "PostgreSQL $PG_VERSION"
if ! node_ok; then
  installer=$(mktemp)
  curl -fsSL "https://deb.nodesource.com/setup_$NODE_MAJOR.x" -o "$installer"
  sudo bash "$installer" >/dev/null
  rm -f "$installer"
  apt_install nodejs
  hash -r
  node_ok || die 'Node.js ≥ 20.12 gagal dipasang.'
fi
ok "Node.js $(node -v)"
if ! command -v pm2 >/dev/null; then
  if [ -w "$(npm prefix -g)" ]; then npm install -g pm2 --no-audit --no-fund --loglevel=error >/dev/null
  else sudo npm install -g pm2 --no-audit --no-fund --loglevel=error >/dev/null; fi
  hash -r
fi
# Versi dari package.json pm2: `pm2 -v` pertama kali juga menyalakan daemon pm2 dan mencetak pesannya.
ok "pm2 $(node -p "require('$(dirname "$(readlink -f "$(command -v pm2)")")/../package.json').version" 2>/dev/null || true)"
# Paket rilis sudah membawa node_modules; folder sumber belum.
[ -d node_modules/express ] || npm ci --omit=dev --no-audit --no-fund --loglevel=error >/dev/null

# ── .env ─────────────────────────────────────────────────────────────────────────────────────────────────────────
step 'Konfigurasi .env'
if [ ! -f "$ENV_FILE" ]; then
  if [ -n "$ENV_IMPORT" ]; then
    install -m 600 "$ENV_IMPORT" "$ENV_FILE"
    ok '.env server lama dipakai: CSRF_SECRET & PIN_PEPPER tetap, jadi PIN kasir dan sandi email tetap berlaku'
  else
    node scripts/init-env.js >/dev/null
    ok '.env baru dengan CSRF_SECRET & PIN_PEPPER acak'
  fi
fi
chmod 600 "$ENV_FILE"
[ -z "$PORT_ARG" ] || env_set PORT "$PORT_ARG"
PORT=$(env_get PORT)
PORT=${PORT:-2026}
[ "$(env_get NODE_ENV)" = production ] || env_set NODE_ENV production
[ -z "$DOMAIN" ] || env_set PUBLIC_URL "https://$DOMAIN"
PUBLIC_URL=$(env_get PUBLIC_URL)
if [ -n "$PUBLIC_URL" ]; then
  # Domain HTTPS lewat Cloudflare Tunnel di server ini: proxy datang dari loopback (cek Origin & IP pengunjung asli).
  case $(env_get TRUST_PROXY) in '' | 0) env_set TRUST_PROXY loopback ;; esac
  ok "dibuka lewat $PUBLIC_URL, port aplikasi $PORT"
else
  # Jaringan lokal saja (http://IP-server:PORT): cookie login harus jalan tanpa HTTPS.
  [ -n "$(env_get COOKIE_SECURE)" ] || env_set COOKIE_SECURE false
  ok "dibuka di jaringan lokal, port $PORT (tanpa domain)"
fi
case $(env_get HOST) in
  127.0.0.1 | localhost | ::1) note "HOST=$(env_get HOST): mesin pintu tiket di jaringan lokal tidak bisa menjangkau server ini. Kosongkan HOST bila memakai pintu tiket." ;;
esac
if [ -n "$ENV_IMPORT" ] && [ -n "$(env_get STORAGE_DIR)" ] && [ ! -d "$(env_get STORAGE_DIR)" ]; then
  env_disable STORAGE_DIR 'folder di server lama'
  note 'STORAGE_DIR server lama dinonaktifkan: foto disimpan di storage/ folder ini'
fi

# ── Database ─────────────────────────────────────────────────────────────────────────────────────────────────────
step 'Database PostgreSQL'
[ -n "$(cluster)" ] || sudo pg_createcluster "$PG_VERSION" main >/dev/null
case $(cluster | awk '{print $4}') in online*) ;; *) sudo pg_ctlcluster "$PG_VERSION" main start ;; esac
sudo systemctl enable postgresql >/dev/null 2>&1 || true
PG_PORT=$(cluster | awk '{print $3}')
[ -n "$PG_PORT" ] || die "cluster PostgreSQL $PG_VERSION tidak ditemukan (pg_lsclusters)."
if db_ok; then
  ok "database $DB_NAME tersambung (pengguna $DB_USER, port $PG_PORT)"
else
  DB_PASS=$(node -e 'process.stdout.write(require("node:crypto").randomBytes(24).toString("hex"))')
  # Pengguna khusus aplikasi: bukan superuser, hanya pemilik database-nya sendiri. SQL lewat stdin agar sandi tidak
  # tampil di daftar proses.
  pg_admin <<SQL
SELECT format('CREATE ROLE %I LOGIN', '$DB_USER') WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER') \gexec
ALTER ROLE $DB_USER WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '$DB_PASS';
SELECT format('CREATE DATABASE %I OWNER %I', '$DB_NAME', '$DB_USER') WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '$DB_NAME') \gexec
SQL
  env_set DATABASE_URL "postgres://$DB_USER:$DB_PASS@localhost:$PG_PORT/$DB_NAME"
  unset DB_PASS
  db_ok || die "aplikasi belum bisa masuk ke database $DB_NAME dengan DATABASE_URL baru."
  ok "pengguna $DB_USER (bukan superuser, sandi acak tersimpan di .env) & database $DB_NAME, port $PG_PORT"
fi

if [ -n "$RESTORE" ]; then
  step "Memulihkan backup $RESTORE"
  if [ -f "$RESTORE/SHA256SUMS" ]; then
    (cd "$RESTORE" && sha256sum --quiet -c SHA256SUMS) || die 'arsip backup rusak (SHA256SUMS tidak cocok).'
    ok 'arsip utuh (SHA256SUMS cocok)'
  fi
  tables=$(table_count)
  [ "$tables" = 0 ] || die "database $DB_NAME sudah berisi $tables tabel. Pemulihan otomatis hanya ke database kosong agar data yang ada tidak tertimpa; pulihkan manual: docs/backup.md."
  PGPASSWORD=$(db_pass) "$PGBIN/pg_restore" --no-owner --no-privileges --exit-on-error --single-transaction \
    -h localhost -p "$PG_PORT" -U "$DB_USER" -d "$DB_NAME" "$RESTORE/database.dump" || die 'pg_restore gagal (database dikembalikan kosong).'
  ok "database dipulihkan: $(table_count) tabel"
  if [ -f "$RESTORE/storage.tar.gz" ]; then
    storage=$(env_get STORAGE_DIR)
    storage=${storage:-$APP/storage}
    case $storage in /*) ;; *) storage=$APP/$storage ;; esac
    unpacked=$(mktemp -d)
    tar -xzf "$RESTORE/storage.tar.gz" -C "$unpacked"
    mkdir -p "$storage"
    cp -a "$unpacked"/*/. "$storage"/
    rm -rf "$unpacked"
    ok "foto dipulihkan ke $storage"
  fi
fi

# ── Migrasi & akun ───────────────────────────────────────────────────────────────────────────────────────────────
step 'Struktur database (migrasi)'
UPDATE=0
pm2_has "$APP_NAME" && UPDATE=1
if [ $UPDATE = 1 ] && [ "$(table_count)" != 0 ]; then
  # Update: backup dulu. Bila backup atau migrasi gagal, aplikasi versi lama tetap berjalan.
  BACKUP_DIR=$BACKUP_DIR node scripts/backup-db.mjs | sed 's/^/   /' || die 'backup sebelum update gagal — update dihentikan, aplikasi lama tetap berjalan.'
fi
npm run --silent migrate | sed 's/^/   /' || die "migrasi database gagal (pesan di atas).$([ $UPDATE = 1 ] && echo ' Aplikasi lama tetap berjalan.')"
ok 'struktur database terbaru'
NEW_OWNER=''
if [ "$(app_psql -c 'SELECT count(*) FROM users')" = 0 ]; then
  step 'Data awal'
  ADMIN_USERNAME=$OWNER_USERNAME ADMIN_PASSWORD=$OWNER_PASSWORD ADMIN_FULL_NAME=Owner BUSINESS_NAME=$BUSINESS_NAME \
    node scripts/create-admin.js </dev/null | sed '/^$/d; s/^/   /' || die 'akun Pemilik gagal dibuat (pesan di atas).'
  NEW_OWNER=1
fi

# ── pm2 ──────────────────────────────────────────────────────────────────────────────────────────────────────────
step 'Aplikasi & backup harian (pm2)'
pm2 startOrRestart "$ECOSYSTEM" --only "$APP_NAME" --update-env >/dev/null
if ! curl -fs -o /dev/null --retry 30 --retry-connrefused --retry-delay 1 "http://127.0.0.1:$PORT/api/health"; then
  pm2 logs "$APP_NAME" --lines 30 --nostream || true
  die "aplikasi tidak merespons di port $PORT (log di atas)."
fi
ok "$APP_NAME $([ $UPDATE = 1 ] && echo 'dimuat ulang' || echo 'berjalan'), port $PORT"
# Proses backup dibuat sekali saja (langsung membuat backup pertama); saat update tidak disentuh, agar backup
# sebelum update di atas tidak tertimpa backup baru bertanggal sama.
pm2_has "$BACKUP_NAME" || pm2 start "$ECOSYSTEM" --only "$BACKUP_NAME" >/dev/null
ok "$BACKUP_NAME: backup setiap 02.00 ke $BACKUP_DIR (simpan 3 hari)"
pm2 save >/dev/null
if [ -d /run/systemd/system ]; then
  if ! systemctl is-enabled --quiet "pm2-$ME" 2>/dev/null; then
    sudo env PATH="$PATH:$(dirname "$(command -v node)")" "$(command -v pm2)" startup systemd -u "$ME" --hp "$HOME" >/dev/null
    pm2 save >/dev/null
  fi
  ok "menyala sendiri setiap server restart (layanan pm2-$ME)"
else
  note 'systemd tidak ditemukan: atur autostart pm2 secara manual (pm2 startup).'
fi
# Firewall aktif: buka port aplikasi untuk jaringan lokal saja (kasir, pintu tiket); dari internet lewat domain.
if command -v ufw >/dev/null && sudo ufw status 2>/dev/null | grep -q '^Status: active'; then
  for net in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do sudo ufw allow from "$net" to any port "$PORT" proto tcp >/dev/null; done
  ok "firewall: port $PORT dibuka untuk jaringan lokal"
fi

# ── Domain ───────────────────────────────────────────────────────────────────────────────────────────────────────
TUNNEL_TODO=''
if [ -n "$PUBLIC_URL" ]; then
  step 'Domain (Cloudflare Tunnel)'
  if systemctl is-active --quiet cloudflared 2>/dev/null; then
    ok 'cloudflared sudah berjalan di server ini'
  else
    token=${CLOUDFLARE_TUNNEL_TOKEN:-}
    if [ -z "$token" ] && [ -t 0 ]; then
      read -rsp '   Token Cloudflare Tunnel untuk server ini (Enter = lewati): ' token
      echo
    fi
    if [ -n "$token" ]; then
      install_tunnel "$token"
      ok "cloudflared terpasang & berjalan"
    else
      TUNNEL_TODO=1
      note 'cloudflared belum dipasang (dilewati)'
    fi
    unset token
  fi
fi

# ── Ringkasan ────────────────────────────────────────────────────────────────────────────────────────────────────
step 'Selesai'
LAN_IP=$({ hostname -I 2>/dev/null || true; } | awk '{print $1}')
LAN_IP=${LAN_IP:-IP-server}
BASE=${PUBLIC_URL:-http://$LAN_IP:$PORT}
echo "   Backoffice    : $BASE/login"
echo "   Kasir (POS)   : $BASE/pos/setup"
echo "   API pintu     : http://$LAN_IP:$PORT/api/gate  (jaringan lokal saja; beri server ini IP tetap)"
echo "   Status & log  : pm2 ls  |  pm2 logs $APP_NAME"
echo "   Backup        : $BACKUP_DIR, setiap 02.00 — salin berkala ke disk atau cloud lain"
if [ -n "$NEW_OWNER" ]; then
  [ "$OWNER_PASSWORD" = owner123 ] && shown=owner123 || shown='(dari OWNER_PASSWORD)'
  echo "   ${BOLD}Akun Pemilik${RESET}  : $OWNER_USERNAME / $shown — password sementara: SEGERA masuk dan ganti,"
  echo "                   sebelum diganti siapa pun yang tahu password ini bisa masuk"
fi
[ -z "$TUNNEL_TODO" ] || echo "   ${BOLD}Domain${RESET}: pasang Cloudflare Tunnel (INSTALL.md), lalu arahkan ${PUBLIC_URL#https://} ke http://localhost:$PORT"
echo "   Simpan salinan .env di tempat aman, terpisah dari backup: tanpa PIN_PEPPER, PIN semua kasir harus diatur ulang."
