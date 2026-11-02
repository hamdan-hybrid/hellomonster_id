-- Multi-satuan per produk. Stok selalu disimpan dalam satuan dasar produk (products.unit_id);
-- satuan lain dikonversi dengan faktor: 1 <satuan lain> = factor <satuan dasar>.
-- Contoh: Ayam Pop, satuan dasar kg, satuan lain pack dengan factor 0.5 (1 pack = 0,5 kg).

CREATE TABLE product_units (
  id             BIGSERIAL PRIMARY KEY,
  product_id     BIGINT        NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  unit_id        BIGINT        NOT NULL REFERENCES units(id),
  factor         NUMERIC(14,6) NOT NULL CHECK (factor > 0),
  -- Harga jual per satuan ini; NULL = harga dasar × factor.
  selling_price  NUMERIC(14,2) CHECK (selling_price IS NULL OR selling_price >= 0),
  barcode        VARCHAR(60),
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
  UNIQUE (product_id, unit_id)
);
CREATE INDEX product_units_product_idx ON product_units (product_id);
CREATE UNIQUE INDEX product_units_barcode_uq ON product_units (barcode) WHERE barcode IS NOT NULL;

-- Satuan saat transaksi terjadi (riwayat tidak berubah walau konversi produk diubah kemudian).
-- qty tetap dalam satuan yang dijual/dibeli; qty × unit_factor = jumlah dalam satuan dasar.
ALTER TABLE sale_items
  ADD COLUMN unit_name   VARCHAR(20),
  ADD COLUMN unit_factor NUMERIC(14,6) NOT NULL DEFAULT 1;

ALTER TABLE purchase_items
  ADD COLUMN unit_id     BIGINT REFERENCES units(id),
  ADD COLUMN unit_factor NUMERIC(14,6) NOT NULL DEFAULT 1;
