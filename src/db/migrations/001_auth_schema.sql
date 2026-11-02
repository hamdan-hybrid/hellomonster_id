-- DOMPET USAHA — skema autentikasi, otorisasi, sesi, audit, terminal POS, dan shift kasir.
-- Satu identitas pengguna (users) dapat memiliki metode autentikasi berbeda:
-- password (Backoffice) dan PIN (POS). Tidak ada akun ganda untuk orang yang sama.

CREATE TABLE branches (
  id          BIGSERIAL PRIMARY KEY,
  code        VARCHAR(20)  NOT NULL UNIQUE,
  name        VARCHAR(120) NOT NULL,
  address     TEXT,
  is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE pos_terminals (
  id                  BIGSERIAL PRIMARY KEY,
  branch_id           BIGINT       NOT NULL REFERENCES branches(id),
  code                VARCHAR(30)  NOT NULL,
  name                VARCHAR(120) NOT NULL,
  is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
  -- Token perangkat (cookie HttpOnly) hanya disimpan sebagai SHA-256.
  device_token_hash   BYTEA UNIQUE,
  -- Kode pairing sekali pakai, disimpan sebagai SHA-256, berlaku singkat.
  pairing_code_hash   BYTEA,
  pairing_expires_at  TIMESTAMPTZ,
  paired_at           TIMESTAMPTZ,
  last_seen_at        TIMESTAMPTZ,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
  UNIQUE (branch_id, code)
);

CREATE TABLE users (
  id                    BIGSERIAL PRIMARY KEY,
  username              VARCHAR(50)  NOT NULL,
  email                 VARCHAR(254),
  full_name             VARCHAR(120) NOT NULL,
  password_hash         TEXT,          -- NULL = tidak bisa login Backoffice dengan password
  password_updated_at   TIMESTAMPTZ,
  must_change_password  BOOLEAN      NOT NULL DEFAULT FALSE,
  pin_hash              TEXT,          -- NULL = belum punya PIN POS
  pin_updated_at        TIMESTAMPTZ,
  status                VARCHAR(20)  NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'inactive')),
  branch_id             BIGINT       REFERENCES branches(id),  -- cabang utama; NULL = kantor pusat
  backoffice_access     BOOLEAN      NOT NULL DEFAULT FALSE,
  pos_access            BOOLEAN      NOT NULL DEFAULT FALSE,
  last_login_at         TIMESTAMPTZ,
  created_by            BIGINT       REFERENCES users(id),
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CHECK (username ~ '^[a-z0-9._-]{3,50}$')
);
CREATE UNIQUE INDEX users_username_uq ON users (lower(username));
CREATE UNIQUE INDEX users_email_uq    ON users (lower(email)) WHERE email IS NOT NULL;
CREATE INDEX users_branch_idx         ON users (branch_id);

-- Pembatasan opsional: jika pengguna punya baris di sini, ia hanya boleh login POS di terminal tsb.
CREATE TABLE user_terminals (
  user_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  terminal_id  BIGINT NOT NULL REFERENCES pos_terminals(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, terminal_id)
);

CREATE TABLE roles (
  id           BIGSERIAL PRIMARY KEY,
  code         VARCHAR(50)  NOT NULL UNIQUE,
  name         VARCHAR(100) NOT NULL,
  description  TEXT,
  is_system    BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE permissions (
  id           BIGSERIAL PRIMARY KEY,
  code         VARCHAR(80)  NOT NULL UNIQUE,
  module       VARCHAR(50)  NOT NULL,
  name         VARCHAR(150) NOT NULL
);

CREATE TABLE user_roles (
  user_id  BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id  BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, role_id)
);

CREATE TABLE role_permissions (
  role_id        BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id  BIGINT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE user_sessions (
  id                BIGSERIAL PRIMARY KEY,
  token_hash        BYTEA        NOT NULL UNIQUE,   -- SHA-256 dari token cookie; token asli tidak disimpan
  user_id           BIGINT       NOT NULL REFERENCES users(id),
  channel           VARCHAR(12)  NOT NULL CHECK (channel IN ('backoffice', 'pos')),
  branch_id         BIGINT       REFERENCES branches(id),
  terminal_id       BIGINT       REFERENCES pos_terminals(id),
  remember          BOOLEAN      NOT NULL DEFAULT FALSE,
  idle_timeout_sec  INTEGER      NOT NULL,
  ip                VARCHAR(64),
  user_agent        VARCHAR(300),
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
  last_activity_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  expires_at        TIMESTAMPTZ  NOT NULL,           -- batas absolut
  revoked_at        TIMESTAMPTZ,
  revoke_reason     VARCHAR(50),
  CHECK (channel <> 'pos' OR terminal_id IS NOT NULL)
);
CREATE INDEX user_sessions_user_idx     ON user_sessions (user_id) WHERE revoked_at IS NULL;
CREATE INDEX user_sessions_terminal_idx ON user_sessions (terminal_id) WHERE revoked_at IS NULL;

-- Riwayat percobaan login. Tidak pernah menyimpan password / PIN.
CREATE TABLE login_attempts (
  id              BIGSERIAL PRIMARY KEY,
  channel         VARCHAR(20)  NOT NULL CHECK (channel IN ('backoffice', 'pos', 'terminal_pairing')),
  identifier      VARCHAR(254),
  user_id         BIGINT       REFERENCES users(id),
  terminal_id     BIGINT       REFERENCES pos_terminals(id),
  success         BOOLEAN      NOT NULL,
  failure_reason  VARCHAR(50),
  ip              VARCHAR(64),
  user_agent      VARCHAR(300),
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX login_attempts_user_idx ON login_attempts (user_id, created_at DESC);
CREATE INDEX login_attempts_time_idx ON login_attempts (created_at DESC);

-- Penghitung percobaan gagal di backend (per akun, per terminal, per IP).
CREATE TABLE auth_throttles (
  scope            VARCHAR(30)  NOT NULL,
  key              VARCHAR(300) NOT NULL,
  failures         INTEGER      NOT NULL DEFAULT 0,
  last_failure_at  TIMESTAMPTZ,
  locked_until     TIMESTAMPTZ,
  PRIMARY KEY (scope, key)
);

CREATE TABLE audit_logs (
  id             BIGSERIAL PRIMARY KEY,
  actor_user_id  BIGINT       REFERENCES users(id),
  action         VARCHAR(80)  NOT NULL,
  target_type    VARCHAR(40),
  target_id      BIGINT,
  branch_id      BIGINT       REFERENCES branches(id),
  terminal_id    BIGINT       REFERENCES pos_terminals(id),
  ip             VARCHAR(64),
  user_agent     VARCHAR(300),
  details        JSONB        NOT NULL DEFAULT '{}'::jsonb,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX audit_logs_actor_idx  ON audit_logs (actor_user_id, created_at DESC);
CREATE INDEX audit_logs_target_idx ON audit_logs (target_type, target_id, created_at DESC);
CREATE INDEX audit_logs_time_idx   ON audit_logs (created_at DESC);

CREATE TABLE cashier_shifts (
  id               BIGSERIAL PRIMARY KEY,
  user_id          BIGINT        NOT NULL REFERENCES users(id),
  branch_id        BIGINT        NOT NULL REFERENCES branches(id),
  terminal_id      BIGINT        NOT NULL REFERENCES pos_terminals(id),
  opened_session_id BIGINT       REFERENCES user_sessions(id),
  status           VARCHAR(10)   NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  opened_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
  closed_at        TIMESTAMPTZ,
  closed_by        BIGINT        REFERENCES users(id),
  opening_cash     NUMERIC(14,2) NOT NULL CHECK (opening_cash >= 0),
  -- Snapshot saat penutupan:
  cash_sales       NUMERIC(14,2),
  other_cash_in    NUMERIC(14,2),
  cash_out         NUMERIC(14,2),
  refunds          NUMERIC(14,2),
  expected_cash    NUMERIC(14,2),
  counted_cash     NUMERIC(14,2) CHECK (counted_cash IS NULL OR counted_cash >= 0),
  cash_difference  NUMERIC(14,2),
  close_notes      TEXT
);
-- Satu shift terbuka per kasir dan per terminal.
CREATE UNIQUE INDEX cashier_shifts_open_user_uq     ON cashier_shifts (user_id)     WHERE status = 'open';
CREATE UNIQUE INDEX cashier_shifts_open_terminal_uq ON cashier_shifts (terminal_id) WHERE status = 'open';
CREATE INDEX cashier_shifts_branch_idx ON cashier_shifts (branch_id, opened_at DESC);

-- Kas masuk/keluar di luar penjualan. Pembayaran penjualan TIDAK dicatat di sini
-- agar perhitungan kas shift tidak menggandakan penerimaan.
CREATE TABLE cash_movements (
  id          BIGSERIAL PRIMARY KEY,
  shift_id    BIGINT        NOT NULL REFERENCES cashier_shifts(id),
  type        VARCHAR(10)   NOT NULL CHECK (type IN ('cash_in', 'cash_out', 'refund')),
  amount      NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  reason      VARCHAR(200)  NOT NULL,
  sale_id     BIGINT,
  created_by  BIGINT        NOT NULL REFERENCES users(id),
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX cash_movements_shift_idx ON cash_movements (shift_id);

CREATE TABLE sales (
  id           BIGSERIAL PRIMARY KEY,
  invoice_no   VARCHAR(40)   NOT NULL UNIQUE,
  shift_id     BIGINT        NOT NULL REFERENCES cashier_shifts(id),
  branch_id    BIGINT        NOT NULL REFERENCES branches(id),
  terminal_id  BIGINT        NOT NULL REFERENCES pos_terminals(id),
  cashier_id   BIGINT        NOT NULL REFERENCES users(id),
  total        NUMERIC(14,2) NOT NULL CHECK (total >= 0),
  status       VARCHAR(10)   NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'void')),
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX sales_shift_idx  ON sales (shift_id);
CREATE INDEX sales_branch_idx ON sales (branch_id, created_at DESC);

ALTER TABLE cash_movements ADD CONSTRAINT cash_movements_sale_fk FOREIGN KEY (sale_id) REFERENCES sales(id);

CREATE TABLE sale_items (
  id          BIGSERIAL PRIMARY KEY,
  sale_id     BIGINT        NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  name        VARCHAR(150)  NOT NULL,
  qty         NUMERIC(12,3) NOT NULL CHECK (qty > 0),
  unit_price  NUMERIC(14,2) NOT NULL CHECK (unit_price >= 0),
  subtotal    NUMERIC(14,2) NOT NULL
);

-- amount = nilai yang diterapkan ke tagihan (bukan uang yang diserahkan),
-- sehingga kembalian tidak ikut terhitung sebagai kas masuk.
CREATE TABLE sale_payments (
  id        BIGSERIAL PRIMARY KEY,
  sale_id   BIGINT        NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  method    VARCHAR(20)   NOT NULL CHECK (method IN ('cash', 'qris', 'transfer', 'card')),
  amount    NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  tendered  NUMERIC(14,2),
  change    NUMERIC(14,2) NOT NULL DEFAULT 0
);
CREATE INDEX sale_payments_sale_idx ON sale_payments (sale_id);

-- Mencatat satu percobaan login secara atomik (row lock), sehingga request paralel
-- tidak bisa melewati batas. Percobaan dihitung SEBELUM verifikasi; login berhasil
-- mengembalikan hitungan. Kunci bersifat sementara dan bertambah eksponensial.
CREATE FUNCTION auth_throttle_hit(
  p_scope TEXT, p_key TEXT, p_threshold INT, p_base_sec INT, p_max_sec INT, p_window_sec INT
) RETURNS TABLE (o_allowed BOOLEAN, o_failures INT, o_retry_after INT)
LANGUAGE plpgsql AS $$
DECLARE
  r auth_throttles%ROWTYPE;
  n INT;
BEGIN
  INSERT INTO auth_throttles (scope, key) VALUES (p_scope, p_key) ON CONFLICT DO NOTHING;
  SELECT * INTO r FROM auth_throttles t WHERE t.scope = p_scope AND t.key = p_key FOR UPDATE;

  IF r.locked_until IS NOT NULL AND r.locked_until > now() THEN
    RETURN QUERY SELECT FALSE, r.failures, GREATEST(1, CEIL(EXTRACT(EPOCH FROM r.locked_until - now()))::INT);
    RETURN;
  END IF;

  IF r.last_failure_at IS NULL OR r.last_failure_at < now() - make_interval(secs => p_window_sec) THEN
    n := 1;
  ELSE
    n := r.failures + 1;
  END IF;

  UPDATE auth_throttles t
     SET failures = n,
         last_failure_at = now(),
         locked_until = CASE WHEN n >= p_threshold
                             THEN now() + make_interval(secs => LEAST(p_max_sec, p_base_sec * power(2, n - p_threshold)))
                             ELSE NULL END
   WHERE t.scope = p_scope AND t.key = p_key;

  RETURN QUERY SELECT TRUE, n, 0;
END $$;
