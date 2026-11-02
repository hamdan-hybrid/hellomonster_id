-- Retur penjualan (POS): barang dari sebuah transaksi dikembalikan pelanggan, uangnya dikembalikan tunai dari
-- laci shift yang sedang berjalan. Uang juga dicatat sebagai cash_movements 'refund' (return_id terisi),
-- sehingga kas shift dan penjualan bersih di laporan ikut berkurang.
-- Barang yang kembali ke stok masuk lagi dengan HPP saat terjual; cost_total mengurangi HPP di laporan laba rugi.
CREATE TABLE sale_returns (
  id           BIGSERIAL PRIMARY KEY,
  return_no    VARCHAR(40)   NOT NULL UNIQUE,
  sale_id      BIGINT        NOT NULL REFERENCES sales(id),
  shift_id     BIGINT        NOT NULL REFERENCES cashier_shifts(id),
  branch_id    BIGINT        NOT NULL REFERENCES branches(id),
  terminal_id  BIGINT        NOT NULL REFERENCES pos_terminals(id),
  created_by   BIGINT        NOT NULL REFERENCES users(id),
  -- Atasan yang menyetujui; NULL bila diproses sendiri oleh pengguna berizin pos.refund.
  approved_by  BIGINT        REFERENCES users(id),
  reason       VARCHAR(200)  NOT NULL,
  -- false: barang rusak / tidak layak jual, tidak kembali ke stok (HPP-nya tetap menjadi beban).
  restock      BOOLEAN       NOT NULL,
  total        NUMERIC(14,2) NOT NULL CHECK (total >= 0),
  cost_total   NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (cost_total >= 0),
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX sale_returns_sale_idx ON sale_returns (sale_id);
CREATE INDEX sale_returns_branch_time_idx ON sale_returns (branch_id, created_at);

CREATE TABLE sale_return_items (
  id            BIGSERIAL PRIMARY KEY,
  return_id     BIGINT        NOT NULL REFERENCES sale_returns(id) ON DELETE CASCADE,
  sale_item_id  BIGINT        NOT NULL REFERENCES sale_items(id),
  qty           NUMERIC(12,3) NOT NULL CHECK (qty > 0),
  amount        NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
  cost          NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (cost >= 0)
);
CREATE INDEX sale_return_items_return_idx ON sale_return_items (return_id);
CREATE INDEX sale_return_items_item_idx ON sale_return_items (sale_item_id);

ALTER TABLE cash_movements ADD COLUMN return_id BIGINT REFERENCES sale_returns(id);

ALTER TABLE stock_movements DROP CONSTRAINT stock_movements_type_check;
ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_type_check
  CHECK (type IN ('sale', 'purchase', 'adjustment', 'opname', 'transfer_in', 'transfer_out', 'conversion_out', 'conversion_in', 'return'));

-- Salinan isi paket dilengkapi product_id & track_stock, untuk mengembalikan stok isinya saat retur.
UPDATE sale_items si
   SET components = (
     SELECT jsonb_agg(e.c || jsonb_build_object('product_id', bi.product_id, 'track_stock', cp.track_stock) ORDER BY e.ord)
       FROM jsonb_array_elements(si.components) WITH ORDINALITY AS e(c, ord)
       LEFT JOIN LATERAL (
         SELECT b.product_id FROM bundle_items b JOIN products p ON p.id = b.product_id
          WHERE b.bundle_id = si.product_id AND p.name = e.c->>'name' LIMIT 1
       ) bi ON TRUE
       LEFT JOIN products cp ON cp.id = bi.product_id)
 WHERE si.components IS NOT NULL;
