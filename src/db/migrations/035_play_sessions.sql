-- Sesi bermain playground untuk Monitor Bermain (src/services/playSessions.js): satu per transaksi berisi produk
-- playground, termasuk transaksi member (yang tidak mendapat tiket masuk). label = nama panggilan dari kasir (bawaan
-- nama pelanggan/member). Waktu mulai = saat terjual, atau saat pertama masuk lewat pintu tiket bila ada.
-- play_minutes = waktu bermain terpendek di transaksi (0 = sepuasnya). Selesai: ditandai kasir, keluar terakhir di
-- pintu tiket, atau semua tiketnya diretur.
CREATE TABLE play_sessions (
  id            BIGSERIAL     PRIMARY KEY,
  sale_id       BIGINT        NOT NULL UNIQUE REFERENCES sales(id),
  branch_id     BIGINT        NOT NULL REFERENCES branches(id),
  label         VARCHAR(60),
  persons       INT           NOT NULL CHECK (persons >= 0),
  play_minutes  INT           NOT NULL CHECK (play_minutes BETWEEN 0 AND 1440),
  play_day      DATE          NOT NULL,
  started_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  ended_at      TIMESTAMPTZ,
  end_reason    VARCHAR(10)   CHECK (end_reason IN ('manual', 'gate', 'void')),
  called_at     TIMESTAMPTZ,
  call_count    INT           NOT NULL DEFAULT 0 CHECK (call_count >= 0),
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX play_sessions_active_idx ON play_sessions (branch_id, play_day) WHERE ended_at IS NULL;
