-- Foto pelanggan baru di display pelanggan (src/services/customerDisplay.js): foto dari HP pelanggan (daftar lewat QR)
-- atau kamera kasir yang belum menjadi foto member (member baru dibuat saat transaksi selesai). Satu foto per terminal,
-- diganti setiap ada foto baru dan dihapus begitu tampilan kasir tidak lagi memakainya. photo_key = penanda acak dari
-- layar kasir yang juga tertulis di tampilan (state.customer.photo); display hanya bisa meminta foto yang sedang tampil.
CREATE TABLE terminal_display_photos (
  terminal_id  BIGINT       PRIMARY KEY REFERENCES pos_terminals(id) ON DELETE CASCADE,
  photo_key    TEXT         NOT NULL,
  mime         TEXT         NOT NULL,
  data         BYTEA        NOT NULL,
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);
