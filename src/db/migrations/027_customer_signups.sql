-- Pendaftaran mandiri pelanggan lewat QR di layar kasir (src/services/customerSignups.js).
-- Kasir menampilkan QR berisi tautan sekali pakai (berlaku 15 menit); pelanggan membuka tautan itu di HP sendiri
-- dan mengisi datanya; layar kasir langsung memakai data itu sebagai pelanggan baru transaksi. Pelanggannya baru
-- dibuat bersama transaksi (sama seperti pendaftaran di kasir), jadi data di sini hanya titipan sementara: dihapus
-- setelah diambil kasir, dibatalkan, atau kedaluwarsa. Token tautan hanya disimpan sebagai SHA-256.
CREATE TABLE customer_signups (
  id            BIGSERIAL    PRIMARY KEY,
  token_hash    BYTEA        NOT NULL UNIQUE,
  terminal_id   BIGINT       NOT NULL REFERENCES pos_terminals(id) ON DELETE CASCADE,
  branch_id     BIGINT       NOT NULL REFERENCES branches(id),
  created_by    BIGINT       REFERENCES users(id),
  -- Transaksi membeli membership: pelanggan boleh menyertakan foto untuk kartu member.
  with_photo    BOOLEAN      NOT NULL DEFAULT FALSE,
  -- { name, phone, email, birthDate } dan foto (data URL JPEG) setelah dikirim pelanggan.
  data          JSONB,
  photo         TEXT,
  opened_at     TIMESTAMPTZ,
  submitted_at  TIMESTAMPTZ,
  expires_at    TIMESTAMPTZ  NOT NULL,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CHECK ((submitted_at IS NULL) = (data IS NULL))
);
CREATE INDEX customer_signups_terminal_idx ON customer_signups (terminal_id);
CREATE INDEX customer_signups_expires_idx ON customer_signups (expires_at);
