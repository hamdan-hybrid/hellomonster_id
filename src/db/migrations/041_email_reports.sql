-- Email laporan terjadwal (src/services/reportMail.js) lewat akun Gmail usaha (src/services/mailer.js; akun & App
-- Password terenkripsi disimpan di app_settings key 'mail'). Satu jadwal = laporan omset PDF ke beberapa email.
--   frequency: daily (setiap hari), weekly (weekday 1 = Senin … 7 = Minggu), monthly (month_day 1–31; bulan yang lebih
--              pendek → hari terakhirnya), dikirim pukul send_time menurut zona waktu usaha.
--   period   : current = periode berjalan s.d. saat kirim (hari ini / minggu ini sejak Senin / bulan ini sejak tgl 1),
--              previous = periode penuh sebelumnya (kemarin / minggu lalu Senin–Minggu / bulan lalu).
--   branch_id: NULL = semua cabang.
-- next_run_at diklaim dengan UPDATE bersyarat sebelum mengirim, jadi satu jadwal tidak terkirim dua kali.
CREATE TABLE email_schedules (
  id           BIGSERIAL     PRIMARY KEY,
  name         VARCHAR(120)  NOT NULL,
  frequency    VARCHAR(10)   NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly')),
  period       VARCHAR(10)   NOT NULL DEFAULT 'current' CHECK (period IN ('current', 'previous')),
  send_time    TIME          NOT NULL,
  weekday      SMALLINT      CHECK (weekday BETWEEN 1 AND 7),
  month_day    SMALLINT      CHECK (month_day BETWEEN 1 AND 31),
  branch_id    BIGINT        REFERENCES branches(id),
  recipients   TEXT[]        NOT NULL CHECK (cardinality(recipients) BETWEEN 1 AND 20),
  lang         VARCHAR(5)    NOT NULL DEFAULT 'id',
  is_active    BOOLEAN       NOT NULL DEFAULT TRUE,
  next_run_at  TIMESTAMPTZ,
  last_run_at  TIMESTAMPTZ,
  last_status  VARCHAR(10)   CHECK (last_status IN ('sent', 'failed', 'missed')),
  last_error   TEXT,
  created_by   BIGINT        REFERENCES users(id),
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
  CHECK (frequency <> 'weekly' OR weekday IS NOT NULL),
  CHECK (frequency <> 'monthly' OR month_day IS NOT NULL)
);
CREATE INDEX email_schedules_due_idx ON email_schedules (next_run_at) WHERE is_active;

-- Riwayat pengiriman (otomatis, "Kirim sekarang", dan email uji). created_by NULL = terkirim otomatis.
CREATE TABLE email_log (
  id           BIGSERIAL     PRIMARY KEY,
  schedule_id  BIGINT        REFERENCES email_schedules(id) ON DELETE SET NULL,
  kind         VARCHAR(10)   NOT NULL CHECK (kind IN ('report', 'test')),
  subject      VARCHAR(300)  NOT NULL,
  recipients   TEXT[]        NOT NULL,
  status       VARCHAR(10)   NOT NULL CHECK (status IN ('sent', 'failed')),
  error        TEXT,
  created_by   BIGINT        REFERENCES users(id),
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX email_log_created_idx ON email_log (created_at DESC);
