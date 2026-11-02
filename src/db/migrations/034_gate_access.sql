-- Aturan keluar-masuk produk playground & pintu tiket (src/services/entryGates.js).
-- exit_limit per tiket (per orang): 0 = sepuasnya, bolak-balik selama tiket berlaku; N = sesuai tiket, boleh keluar
-- N kali (keluar ke-N = pulang, setelah itu tiket tidak bisa dipakai masuk lagi). NULL = bukan produk playground.
-- Produk playground yang sudah ada menjadi sepuasnya.
ALTER TABLE products ADD COLUMN exit_limit INT CHECK (exit_limit BETWEEN 0 AND 99);
UPDATE products SET exit_limit = 0 WHERE product_type = 'playground';

-- Tiket masuk menyalin aturannya saat terjual (transaksi campuran memakai batas paling ketat). Hitungan di pintu:
-- used_count = jumlah masuk, exit_count = jumlah keluar, inside_count = orang yang sedang di dalam.
ALTER TABLE entry_tickets
  ADD COLUMN exit_limit   INT NOT NULL DEFAULT 0 CHECK (exit_limit BETWEEN 0 AND 99),
  ADD COLUMN exit_count   INT NOT NULL DEFAULT 0 CHECK (exit_count >= 0),
  ADD COLUMN inside_count INT NOT NULL DEFAULT 0 CHECK (inside_count >= 0);

-- Pintu tiket: perangkat barrier / pemindai yang memanggil /api/gate dengan kuncinya sendiri. Yang disimpan hanya
-- hash kunci; kuncinya ditampilkan sekali saat dibuat. direction: in = pintu masuk, out = pintu keluar.
CREATE TABLE entry_gates (
  id            BIGSERIAL     PRIMARY KEY,
  branch_id     BIGINT        NOT NULL REFERENCES branches(id),
  name          VARCHAR(120)  NOT NULL,
  direction     VARCHAR(3)    NOT NULL CHECK (direction IN ('in', 'out')),
  key_hash      BYTEA         NOT NULL UNIQUE,
  is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
  last_scan_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX entry_gates_branch_idx ON entry_gates (branch_id);

-- Riwayat scan di pintu, diterima maupun ditolak (reason), untuk pelacakan.
CREATE TABLE entry_gate_scans (
  id          BIGSERIAL     PRIMARY KEY,
  gate_id     BIGINT        NOT NULL REFERENCES entry_gates(id),
  ticket_id   BIGINT        REFERENCES entry_tickets(id),
  code        VARCHAR(20)   NOT NULL,
  direction   VARCHAR(3)    NOT NULL CHECK (direction IN ('in', 'out')),
  allowed     BOOLEAN       NOT NULL,
  reason      VARCHAR(20)   NOT NULL,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX entry_gate_scans_gate_idx ON entry_gate_scans (gate_id, created_at DESC);
CREATE INDEX entry_gate_scans_ticket_idx ON entry_gate_scans (ticket_id);
