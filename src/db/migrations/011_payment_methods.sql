-- Metode pembayaran penjualan dikelola di Master Data (berlaku sama untuk semua cabang).
-- sale_payments.method tetap menyimpan KODE metode, sehingga mengganti nama metode tidak mengubah riwayat.
-- Kode 'cash' (Tunai) adalah metode bawaan: uang masuk laci kasir dan bisa ada kembalian,
-- jadi tidak bisa dihapus maupun dinonaktifkan.
CREATE TABLE payment_methods (
  id          BIGSERIAL    PRIMARY KEY,
  code        VARCHAR(20)  NOT NULL UNIQUE CHECK (code ~ '^[a-z0-9_]{2,20}$'),
  name        VARCHAR(60)  NOT NULL,
  is_active   BOOLEAN      NOT NULL DEFAULT true,
  sort_order  INT          NOT NULL DEFAULT 100 CHECK (sort_order BETWEEN 0 AND 9999),
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CHECK (code <> 'cash' OR is_active)
);
CREATE UNIQUE INDEX payment_methods_name_key ON payment_methods (lower(name));

INSERT INTO payment_methods (code, name, sort_order) VALUES
  ('cash', 'Tunai', 1),
  ('qris', 'QRIS', 2),
  ('transfer', 'Transfer', 3),
  ('card', 'Kartu', 4);

-- Daftar tetap diganti rujukan ke master: metode yang sudah dipakai transaksi tidak bisa dihapus.
ALTER TABLE sale_payments DROP CONSTRAINT sale_payments_method_check;
ALTER TABLE sale_payments ADD CONSTRAINT sale_payments_method_fkey FOREIGN KEY (method) REFERENCES payment_methods (code);
CREATE INDEX sale_payments_method_idx ON sale_payments (method);
