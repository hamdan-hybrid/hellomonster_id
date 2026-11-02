-- Metode persediaan FIFO (first in, first out).
-- Setiap barang masuk membentuk satu lapisan dengan harga pokoknya sendiri; barang keluar
-- mengambil dari lapisan tertua lebih dulu. HPP penjualan = jumlah (qty diambil × harga lapisan).
-- product_stocks.qty tetap saldo total; product_stocks.avg_cost kini = nilai sisa lapisan / qty sisa
-- (hanya untuk tampilan nilai per unit), bukan dasar perhitungan HPP.

CREATE TABLE stock_layers (
  id             BIGSERIAL PRIMARY KEY,
  product_id     BIGINT        NOT NULL REFERENCES products(id),
  branch_id      BIGINT        NOT NULL REFERENCES branches(id),
  unit_cost      NUMERIC(14,4) NOT NULL CHECK (unit_cost >= 0),
  qty_in         NUMERIC(14,3) NOT NULL CHECK (qty_in > 0),
  qty_remaining  NUMERIC(14,3) NOT NULL CHECK (qty_remaining >= 0 AND qty_remaining <= qty_in),
  movement_id    BIGINT        REFERENCES stock_movements(id),
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
);
-- Urutan FIFO = urutan id (lapisan tertua lebih dulu).
CREATE INDEX stock_layers_open_idx ON stock_layers (product_id, branch_id, id) WHERE qty_remaining > 0;
CREATE INDEX stock_layers_product_idx ON stock_layers (product_id, branch_id, id DESC);

-- Jejak lapisan mana yang terpakai oleh setiap mutasi keluar (audit HPP).
CREATE TABLE stock_movement_layers (
  movement_id  BIGINT        NOT NULL REFERENCES stock_movements(id),
  layer_id     BIGINT        REFERENCES stock_layers(id),
  qty          NUMERIC(14,3) NOT NULL CHECK (qty > 0),
  unit_cost    NUMERIC(14,4) NOT NULL
);
CREATE INDEX stock_movement_layers_movement_idx ON stock_movement_layers (movement_id);

-- Saldo yang sudah ada menjadi satu lapisan awal dengan harga pokok rata-rata saat migrasi.
INSERT INTO stock_layers (product_id, branch_id, unit_cost, qty_in, qty_remaining, created_at)
SELECT product_id, branch_id, avg_cost, qty, qty, now()
  FROM product_stocks WHERE qty > 0;
