-- Pemakaian stok: barang keluar bukan karena dijual — rusak, kedaluwarsa, dipakai sendiri (pemilik/karyawan),
-- sampel/promosi, hilang, atau lainnya. Stok berkurang lewat FIFO (stock_movements 'usage'); nilai HPP barang
-- (cost_total) menjadi beban "Pemakaian stok" di laporan laba rugi pada tanggal pemakaian.
CREATE TABLE IF NOT EXISTS stock_usages (
  id          BIGSERIAL PRIMARY KEY,
  doc_no      VARCHAR(40)   NOT NULL UNIQUE,
  branch_id   BIGINT        NOT NULL REFERENCES branches(id),
  category    VARCHAR(12)   NOT NULL CHECK (category IN ('damaged', 'expired', 'own_use', 'sample', 'lost', 'other')),
  note        VARCHAR(200)  NOT NULL DEFAULT '',
  cost_total  NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (cost_total >= 0),
  created_by  BIGINT        NOT NULL REFERENCES users(id),
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS stock_usages_branch_time_idx ON stock_usages (branch_id, created_at);
CREATE INDEX IF NOT EXISTS stock_usages_time_idx ON stock_usages (created_at);

-- qty dalam satuan dasar produk; unit_cost = HPP rata-rata lapisan FIFO yang terpakai.
CREATE TABLE IF NOT EXISTS stock_usage_items (
  id          BIGSERIAL PRIMARY KEY,
  usage_id    BIGINT        NOT NULL REFERENCES stock_usages(id) ON DELETE CASCADE,
  product_id  BIGINT        NOT NULL REFERENCES products(id),
  qty         NUMERIC(14,3) NOT NULL CHECK (qty > 0),
  qty_after   NUMERIC(14,3) NOT NULL,
  unit_cost   NUMERIC(14,4) NOT NULL DEFAULT 0,
  cost        NUMERIC(14,2) NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS stock_usage_items_usage_idx ON stock_usage_items (usage_id);
CREATE INDEX IF NOT EXISTS stock_usage_items_product_idx ON stock_usage_items (product_id);

ALTER TABLE stock_movements DROP CONSTRAINT IF EXISTS stock_movements_type_check;
ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_type_check
  CHECK (type IN ('sale', 'purchase', 'adjustment', 'opname', 'transfer_in', 'transfer_out', 'conversion_out', 'conversion_in', 'return', 'usage'));
