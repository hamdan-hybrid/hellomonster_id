-- Konversi / pecah produk: stok produk sumber keluar (FIFO) dan masuk ke produk hasil
-- dengan satuan berbeda, di cabang yang sama. Total HPP sumber menjadi nilai lapisan hasil.
-- Contoh: Produk A 2 pack keluar → Produk B 10 kg masuk.

ALTER TABLE stock_movements DROP CONSTRAINT stock_movements_type_check;
ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_type_check
  CHECK (type IN ('sale', 'purchase', 'adjustment', 'opname', 'transfer_in', 'transfer_out', 'conversion_out', 'conversion_in'));

CREATE TABLE stock_conversions (
  id                 BIGSERIAL PRIMARY KEY,
  doc_no             VARCHAR(40)   NOT NULL UNIQUE,
  branch_id          BIGINT        NOT NULL REFERENCES branches(id),
  source_product_id  BIGINT        NOT NULL REFERENCES products(id),
  source_unit_id     BIGINT        NOT NULL REFERENCES units(id),
  source_qty         NUMERIC(14,3) NOT NULL CHECK (source_qty > 0),
  source_base_qty    NUMERIC(14,3) NOT NULL CHECK (source_base_qty > 0),
  target_product_id  BIGINT        NOT NULL REFERENCES products(id),
  target_unit_id     BIGINT        NOT NULL REFERENCES units(id),
  target_qty         NUMERIC(14,3) NOT NULL CHECK (target_qty > 0),
  target_base_qty    NUMERIC(14,3) NOT NULL CHECK (target_base_qty > 0),
  total_cost         NUMERIC(14,2) NOT NULL CHECK (total_cost >= 0),
  -- Harga pokok hasil per satuan dasar produk hasil = total_cost / target_base_qty.
  target_unit_cost   NUMERIC(14,4) NOT NULL CHECK (target_unit_cost >= 0),
  note               VARCHAR(200),
  created_by         BIGINT        NOT NULL REFERENCES users(id),
  created_at         TIMESTAMPTZ   NOT NULL DEFAULT now(),
  CHECK (source_product_id <> target_product_id)
);
CREATE INDEX stock_conversions_branch_idx ON stock_conversions (branch_id, created_at DESC);
