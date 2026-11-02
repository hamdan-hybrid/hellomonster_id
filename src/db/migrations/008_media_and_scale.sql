-- Foto produk & kesiapan skala besar (jutaan produk).

/* ---------------------------------------------------------------- Media (gambar) */

-- Gambar disimpan sekali dan dirujuk lewat id; konten identik (sha256 sama) dipakai bersama,
-- sehingga banyak produk dengan foto yang sama tidak menggandakan data.
CREATE TABLE media (
  id          BIGSERIAL PRIMARY KEY,
  sha256      CHAR(64)    NOT NULL UNIQUE,
  mime        VARCHAR(20) NOT NULL CHECK (mime IN ('image/jpeg', 'image/png', 'image/webp')),
  data        BYTEA       NOT NULL CHECK (octet_length(data) <= 524288),
  width       INT,
  height      INT,
  created_by  BIGINT      REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE products ADD COLUMN image_id BIGINT REFERENCES media(id);
CREATE INDEX IF NOT EXISTS products_image_idx ON products (image_id);

/* ---------------------------------------------------------------- Indeks pencarian & paging */

-- Pencarian teks "mengandung" (ILIKE '%kata%') memakai indeks trigram.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS products_name_trgm ON products USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS products_sku_trgm ON products USING gin (sku gin_trgm_ops);
CREATE INDEX IF NOT EXISTS suppliers_name_trgm ON suppliers USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS users_name_trgm ON users USING gin (full_name gin_trgm_ops);

-- Urutan daftar produk (nama, id) dan filter umum.
CREATE INDEX IF NOT EXISTS products_name_order_idx ON products (name, id);
CREATE INDEX IF NOT EXISTS products_active_name_idx ON products (name, id) WHERE is_active;
CREATE INDEX IF NOT EXISTS products_category_name_idx ON products (category_id, name, id);

CREATE INDEX IF NOT EXISTS audit_logs_id_desc_idx ON audit_logs (id DESC);
CREATE INDEX IF NOT EXISTS sale_items_sale_idx ON sale_items (sale_id);
