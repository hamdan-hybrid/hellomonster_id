-- Tiket masuk playground (src/services/entryTickets.js): transaksi berisi produk playground tanpa member mendapat QR
-- di struk untuk masuk lewat swing barrier. Kode 10 digit acak 1.000.000.000–3.800.000.000 (batas angka yang dibaca
-- pembaca barrier), berlaku untuk jumlah orang = jumlah tiket playground di transaksi, pada hari transaksi.
-- Member masuk dengan kartunya sendiri. Retur tiket mengurangi jumlah orangnya; habis = batal.
CREATE TABLE entry_tickets (
  id            BIGSERIAL    PRIMARY KEY,
  code          BIGINT       NOT NULL UNIQUE CHECK (code BETWEEN 1000000000 AND 3800000000),
  sale_id       BIGINT       NOT NULL UNIQUE REFERENCES sales(id),
  branch_id     BIGINT       NOT NULL REFERENCES branches(id),
  persons       INT          NOT NULL CHECK (persons >= 0),
  -- Dipakai pembaca barrier (integrasi berikutnya): jumlah orang yang sudah masuk & waktu terakhir.
  used_count    INT          NOT NULL DEFAULT 0 CHECK (used_count >= 0),
  last_used_at  TIMESTAMPTZ,
  valid_on      DATE         NOT NULL,
  status        VARCHAR(10)  NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'used', 'void')),
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX entry_tickets_valid_idx ON entry_tickets (branch_id, valid_on);
