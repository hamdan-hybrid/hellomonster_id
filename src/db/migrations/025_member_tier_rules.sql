-- Diskon member per kategori produk & per jenis produk untuk setiap tipe member (mis. Gold: kategori Cafe 10%,
-- jenis Playground 15%, produk lain 5% dari diskon bawaan tipe). Urutan yang berlaku untuk satu produk:
--   1. member_tier_prices   — diskon khusus produk (persen / harga khusus)
--   2. member_tier_categories — kategori produk
--   3. member_tier_types      — jenis produk
--   4. member_tiers.discount_percent — diskon bawaan tipe
-- discount_percent 0 = kategori/jenis itu tidak mendapat diskon member. Produk membership tidak pernah didiskon,
-- jadi tidak bisa dipilih sebagai jenis.

CREATE TABLE member_tier_categories (
  tier_id           BIGINT        NOT NULL REFERENCES member_tiers(id) ON DELETE CASCADE,
  category_id       BIGINT        NOT NULL REFERENCES product_categories(id) ON DELETE CASCADE,
  discount_percent  NUMERIC(5,2)  NOT NULL CHECK (discount_percent BETWEEN 0 AND 100),
  PRIMARY KEY (tier_id, category_id)
);
CREATE INDEX member_tier_categories_category_idx ON member_tier_categories (category_id);

CREATE TABLE member_tier_types (
  tier_id           BIGINT        NOT NULL REFERENCES member_tiers(id) ON DELETE CASCADE,
  product_type      VARCHAR(12)   NOT NULL CHECK (product_type IN ('retail', 'bundle', 'playground', 'service')),
  discount_percent  NUMERIC(5,2)  NOT NULL CHECK (discount_percent BETWEEN 0 AND 100),
  PRIMARY KEY (tier_id, product_type)
);
