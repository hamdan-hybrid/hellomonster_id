-- Display pelanggan (src/services/customerDisplay.js): layar yang menghadap pelanggan menampilkan isi keranjang,
-- total, pembayaran, dan QR daftar member dari terminal kasir secara langsung.
--  - Di browser terminal itu sendiri (monitor kedua) display dikenali dari cookie perangkat terminal.
--  - Perangkat lain (tablet/TV) dipasangkan dengan kode sekali pakai dari layar kasir (berlaku 10 menit) dan
--    mendapat cookie display sendiri. Satu display terpasang per terminal; kode & token hanya disimpan sebagai SHA-256.
ALTER TABLE pos_terminals
  ADD COLUMN display_token_hash      BYTEA UNIQUE,
  ADD COLUMN display_code_hash       BYTEA,
  ADD COLUMN display_code_expires_at TIMESTAMPTZ,
  ADD COLUMN display_paired_at       TIMESTAMPTZ,
  ADD COLUMN display_seen_at         TIMESTAMPTZ;
CREATE UNIQUE INDEX pos_terminals_display_code_uq ON pos_terminals (display_code_hash) WHERE display_code_hash IS NOT NULL;

-- Tampilan terakhir yang dikirim layar kasir; version naik setiap pembaruan (display cukup menanyakan versinya).
CREATE TABLE terminal_displays (
  terminal_id  BIGINT       PRIMARY KEY REFERENCES pos_terminals(id) ON DELETE CASCADE,
  state        JSONB        NOT NULL,
  version      BIGINT       NOT NULL DEFAULT 1,
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);
