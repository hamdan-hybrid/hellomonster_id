-- Modul Promo & Diskon (diskon produk, promo kombinasi, beli X gratis Y, voucher) dan produk paket.
-- Setiap promo bisa dibatasi periode (tanggal usaha, inklusif) dan cabang.

/* ---------------------------------------------------------------- Izin */

INSERT INTO permissions (code, module, name) VALUES
  ('promotions.view',   'promo', 'Melihat promo, diskon & voucher'),
  ('promotions.manage', 'promo', 'Mengelola promo, diskon & voucher');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN ('promotions.view', 'promotions.manage')
 WHERE r.code IN ('owner', 'admin');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code = 'promotions.view'
 WHERE r.code = 'supervisor';

/* ---------------------------------------------------------------- Paket (bundling) */

-- Paket dijual sebagai satu barang; saat terjual, stok setiap isinya berkurang (FIFO) dan
-- HPP paket = jumlah HPP isinya. Paket sendiri tidak punya stok.
ALTER TABLE products
  ADD COLUMN is_bundle    BOOLEAN NOT NULL DEFAULT FALSE,
  -- Ketersediaan di POS: false = hanya di cabang yang tercantum di product_branches.
  ADD COLUMN all_branches BOOLEAN NOT NULL DEFAULT TRUE,
  ADD CONSTRAINT products_bundle_stock_chk CHECK (NOT (is_bundle AND track_stock));

CREATE TABLE product_branches (
  product_id  BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  branch_id   BIGINT NOT NULL REFERENCES branches(id),
  PRIMARY KEY (product_id, branch_id)
);

-- Isi paket; qty dalam satuan dasar produk isi.
CREATE TABLE bundle_items (
  bundle_id   BIGINT        NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  product_id  BIGINT        NOT NULL REFERENCES products(id),
  qty         NUMERIC(14,3) NOT NULL CHECK (qty > 0),
  PRIMARY KEY (bundle_id, product_id),
  CHECK (bundle_id <> product_id)
);
CREATE INDEX bundle_items_product_idx ON bundle_items (product_id);

/* ---------------------------------------------------------------- Promo */

-- discount : potongan per barang untuk produk/kategori tertentu (persen, atau Rupiah per satuan dasar).
-- combo    : semua produk promo ada di keranjang → dibayar combo_price per set.
-- buy_get  : beli produk 'buy' → produk 'get' mendapat potongan get_percent (100 = gratis).
-- voucher  : kode yang dimasukkan kasir; potongan dari total belanja (setelah diskon & promo).
CREATE TABLE promotions (
  id             BIGSERIAL PRIMARY KEY,
  type           VARCHAR(10)   NOT NULL CHECK (type IN ('discount', 'combo', 'buy_get', 'voucher')),
  name           VARCHAR(100)  NOT NULL,
  discount_type  VARCHAR(10)   CHECK (discount_type IN ('percent', 'amount')),
  discount_value NUMERIC(14,2) CHECK (discount_value > 0),
  combo_price    NUMERIC(14,2) CHECK (combo_price >= 0),
  get_percent    NUMERIC(5,2)  CHECK (get_percent > 0 AND get_percent <= 100),
  code           VARCHAR(30),
  min_purchase   NUMERIC(14,2) CHECK (min_purchase > 0),
  max_discount   NUMERIC(14,2) CHECK (max_discount > 0),
  -- Batas jumlah transaksi yang boleh memakai voucher ini; NULL = tanpa batas.
  quota          INT           CHECK (quota > 0),
  starts_on      DATE,
  ends_on        DATE,
  all_branches   BOOLEAN       NOT NULL DEFAULT TRUE,
  is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
  created_by     BIGINT        REFERENCES users(id),
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
  CHECK (type NOT IN ('discount', 'voucher') OR (discount_type IS NOT NULL AND discount_value IS NOT NULL)),
  CHECK (discount_type IS DISTINCT FROM 'percent' OR discount_value <= 100),
  CHECK (type <> 'combo' OR combo_price IS NOT NULL),
  CHECK (type <> 'buy_get' OR get_percent IS NOT NULL),
  CHECK ((type = 'voucher') = (code IS NOT NULL)),
  CHECK (starts_on IS NULL OR ends_on IS NULL OR starts_on <= ends_on)
);
CREATE UNIQUE INDEX promotions_code_uq ON promotions (upper(code)) WHERE code IS NOT NULL;
CREATE INDEX promotions_type_idx ON promotions (type, is_active, id DESC);

-- Sasaran promo. discount: produk ATAU kategori (qty kosong). combo: role 'item' + qty.
-- buy_get: role 'buy' dan 'get' + qty. qty dalam satuan dasar produk.
CREATE TABLE promotion_items (
  id            BIGSERIAL PRIMARY KEY,
  promotion_id  BIGINT        NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
  role          VARCHAR(4)    NOT NULL CHECK (role IN ('item', 'buy', 'get')),
  product_id    BIGINT        REFERENCES products(id),
  category_id   BIGINT        REFERENCES product_categories(id),
  qty           NUMERIC(14,3) CHECK (qty > 0),
  CHECK ((product_id IS NULL) <> (category_id IS NULL))
);
CREATE INDEX promotion_items_promo_idx ON promotion_items (promotion_id);
CREATE INDEX promotion_items_product_idx ON promotion_items (product_id) WHERE product_id IS NOT NULL;
CREATE UNIQUE INDEX promotion_items_product_uq ON promotion_items (promotion_id, role, product_id) WHERE product_id IS NOT NULL;
CREATE UNIQUE INDEX promotion_items_category_uq ON promotion_items (promotion_id, role, category_id) WHERE category_id IS NOT NULL;

CREATE TABLE promotion_branches (
  promotion_id  BIGINT NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
  branch_id     BIGINT NOT NULL REFERENCES branches(id),
  PRIMARY KEY (promotion_id, branch_id)
);

/* ---------------------------------------------------------------- Penjualan */

ALTER TABLE sales
  ADD COLUMN voucher_id     BIGINT        REFERENCES promotions(id),
  ADD COLUMN voucher_code   VARCHAR(30),
  ADD COLUMN voucher_amount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (voucher_amount >= 0);
CREATE INDEX sales_voucher_idx ON sales (voucher_id) WHERE voucher_id IS NOT NULL;

-- unit_price tetap harga normal. subtotal = harga normal × qty − discount_amount − promo_amount − voucher_amount,
-- sehingga SUM(subtotal) = sales.total dan laporan per produk memakai nilai bersih.
ALTER TABLE sale_items
  ADD COLUMN discount_amount       NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  ADD COLUMN discount_promotion_id BIGINT        REFERENCES promotions(id),
  ADD COLUMN discount_label        VARCHAR(120),
  ADD COLUMN promo_amount          NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (promo_amount >= 0),
  ADD COLUMN voucher_amount        NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (voucher_amount >= 0);
CREATE INDEX sale_items_discount_promo_idx ON sale_items (discount_promotion_id) WHERE discount_promotion_id IS NOT NULL;

-- Promo kombinasi / beli X gratis Y yang terpakai di sebuah transaksi (untuk struk & statistik).
CREATE TABLE sale_promotions (
  id            BIGSERIAL PRIMARY KEY,
  sale_id       BIGINT        NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  promotion_id  BIGINT        REFERENCES promotions(id),
  name          VARCHAR(100)  NOT NULL,
  times         INT           NOT NULL CHECK (times > 0),
  amount        NUMERIC(14,2) NOT NULL CHECK (amount > 0)
);
CREATE INDEX sale_promotions_sale_idx ON sale_promotions (sale_id);
CREATE INDEX sale_promotions_promotion_idx ON sale_promotions (promotion_id);
