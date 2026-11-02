-- Membership dijual sebagai produk lewat POS (lihat src/services/membership.js).
--  - Jenis produk: retail (barang), bundle (paket), membership, playground, service (jasa lainnya). Hanya barang
--    (retail) yang bisa melacak stok; is_bundle tetap ada dan selalu sama dengan product_type = 'bundle'.
--  - Produk membership memberi tipe member (Basic, Silver, …) dengan masa aktif tertentu. Pembayaran yang berhasil
--    (transaksi POS tersimpan) membuat/memperbarui member pelanggan dalam transaksi database yang sama.
--  - Satu pelanggan = satu member = satu kartu. Setiap pembelian menjadi satu periode (riwayat tidak dihapus);
--    status & tipe saat ini dihitung dari periode yang berlaku hari ini.

/* ---------------------------------------------------------------- Jenis produk */

ALTER TABLE products ADD COLUMN product_type VARCHAR(12) NOT NULL DEFAULT 'retail'
  CHECK (product_type IN ('retail', 'bundle', 'membership', 'playground', 'service'));
UPDATE products SET product_type = 'bundle' WHERE is_bundle;
ALTER TABLE products ADD CONSTRAINT products_type_bundle_chk CHECK ((product_type = 'bundle') = is_bundle);
ALTER TABLE products ADD CONSTRAINT products_type_stock_chk CHECK (product_type = 'retail' OR NOT track_stock);
CREATE INDEX products_type_idx ON products (product_type);

/* ---------------------------------------------------------------- Tipe member */

-- level menentukan upgrade (level lebih tinggi) atau downgrade. discount_percent = diskon member bawaan untuk
-- semua produk; per produk bisa diganti di member_tier_prices.
CREATE TABLE member_tiers (
  id                BIGSERIAL     PRIMARY KEY,
  code              VARCHAR(20)   NOT NULL,
  name              VARCHAR(60)   NOT NULL,
  level             INT           NOT NULL CHECK (level BETWEEN 1 AND 99),
  discount_percent  NUMERIC(5,2)  NOT NULL DEFAULT 0 CHECK (discount_percent BETWEEN 0 AND 100),
  description       VARCHAR(300),
  is_active         BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX member_tiers_code_uq ON member_tiers (lower(code));
CREATE UNIQUE INDEX member_tiers_name_uq ON member_tiers (lower(name));

INSERT INTO member_tiers (code, name, level, discount_percent, description) VALUES
  ('BASIC',  'Basic',  1, 5,  'Diskon member 5%'),
  ('SILVER', 'Silver', 2, 10, 'Diskon member 10%'),
  ('GOLD',   'Gold',   3, 15, 'Diskon member 15%'),
  ('FAMILY', 'Family', 3, 15, 'Satu kartu untuk keluarga');

-- Pengaturan produk membership: tipe yang diberikan, masa aktif, aturan mulai, dan aturan perpanjangan.
--   start_rule   : purchase = mulai tanggal pembayaran; first_use = mulai saat kartu pertama kali dipakai di POS.
--   renewal_rule : immediate = perpanjangan mulai tanggal transaksi; after_end = setelah masa aktif lama berakhir.
CREATE TABLE product_memberships (
  product_id      BIGINT       PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
  tier_id         BIGINT       NOT NULL REFERENCES member_tiers(id),
  duration_value  INT          NOT NULL CHECK (duration_value BETWEEN 1 AND 3650),
  duration_unit   VARCHAR(5)   NOT NULL CHECK (duration_unit IN ('day', 'month', 'year')),
  start_rule      VARCHAR(10)  NOT NULL DEFAULT 'purchase' CHECK (start_rule IN ('purchase', 'first_use')),
  renewal_rule    VARCHAR(10)  NOT NULL DEFAULT 'after_end' CHECK (renewal_rule IN ('immediate', 'after_end')),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX product_memberships_tier_idx ON product_memberships (tier_id);

-- Diskon member per produk & tipe (menggantikan diskon bawaan tipe): percent = persen dari harga
-- (0 = produk ini tanpa diskon member), price = harga khusus member per satuan dasar.
CREATE TABLE member_tier_prices (
  tier_id         BIGINT         NOT NULL REFERENCES member_tiers(id) ON DELETE CASCADE,
  product_id      BIGINT         NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  discount_type   VARCHAR(7)     NOT NULL CHECK (discount_type IN ('percent', 'price')),
  discount_value  NUMERIC(14,2)  NOT NULL CHECK (discount_value >= 0),
  PRIMARY KEY (tier_id, product_id),
  CHECK (discount_type <> 'percent' OR discount_value <= 100)
);
CREATE INDEX member_tier_prices_product_idx ON member_tier_prices (product_id);

/* ---------------------------------------------------------------- Pelanggan & member */

CREATE TABLE customers (
  id          BIGSERIAL     PRIMARY KEY,
  name        VARCHAR(120)  NOT NULL,
  phone       VARCHAR(30),
  email       VARCHAR(254),
  birth_date  DATE,
  notes       VARCHAR(300),
  branch_id   BIGINT        REFERENCES branches(id),
  created_by  BIGINT        REFERENCES users(id),
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX customers_name_idx ON customers (lower(name) text_pattern_ops);
CREATE INDEX customers_phone_idx ON customers (phone text_pattern_ops) WHERE phone IS NOT NULL;

-- card_code: isi QR/barcode kartu (acak, tidak bisa ditebak dari nomor member). Kartu diganti = kode baru,
-- kartu lama otomatis tidak berlaku. status suspended = diskon & pemakaian kartu diblokir sementara.
CREATE SEQUENCE member_no_seq;
CREATE TABLE members (
  id              BIGSERIAL     PRIMARY KEY,
  member_no       VARCHAR(24)   NOT NULL UNIQUE,
  customer_id     BIGINT        NOT NULL UNIQUE REFERENCES customers(id),
  card_code       VARCHAR(24)   NOT NULL UNIQUE,
  holder_name     VARCHAR(120)  NOT NULL,
  status          VARCHAR(10)   NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  branch_id       BIGINT        REFERENCES branches(id),
  card_issued_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
  created_by      BIGINT        REFERENCES users(id),
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Satu periode per pembelian (atau koreksi manual). starts_on/ends_on NULL = menunggu pemakaian pertama.
-- kind: new (member baru), renewal (tipe sama), upgrade/downgrade (level tipe naik/turun), change (pindah tipe
-- selevel), manual (koreksi Backoffice tanpa pembayaran).
-- state: valid; superseded = diganti lebih awal (upgrade/perpanjangan langsung), berakhir sehari sebelum
-- superseded_on; cancelled = dibatalkan (retur atau koreksi). Tanggal lama tetap tercatat di member_events.
CREATE TABLE member_periods (
  id                     BIGSERIAL      PRIMARY KEY,
  member_id              BIGINT         NOT NULL REFERENCES members(id),
  tier_id                BIGINT         NOT NULL REFERENCES member_tiers(id),
  kind                   VARCHAR(10)    NOT NULL CHECK (kind IN ('new', 'renewal', 'upgrade', 'downgrade', 'change', 'manual')),
  product_id             BIGINT         REFERENCES products(id),
  sale_id                BIGINT         REFERENCES sales(id),
  sale_item_id           BIGINT         UNIQUE REFERENCES sale_items(id),
  price                  NUMERIC(14,2)  NOT NULL DEFAULT 0 CHECK (price >= 0),
  duration_value         INT            NOT NULL CHECK (duration_value >= 1),
  duration_unit          VARCHAR(5)     NOT NULL CHECK (duration_unit IN ('day', 'month', 'year')),
  starts_on              DATE,
  ends_on                DATE,
  state                  VARCHAR(10)    NOT NULL DEFAULT 'valid' CHECK (state IN ('valid', 'superseded', 'cancelled')),
  previous_period_id     BIGINT         REFERENCES member_periods(id),
  superseded_on          DATE,
  replaced_by_period_id  BIGINT         REFERENCES member_periods(id),
  cancelled_at           TIMESTAMPTZ,
  cancel_reason          VARCHAR(300),
  created_by             BIGINT         REFERENCES users(id),
  created_at             TIMESTAMPTZ    NOT NULL DEFAULT now(),
  CHECK ((starts_on IS NULL) = (ends_on IS NULL)),
  CHECK (ends_on IS NULL OR ends_on >= starts_on),
  CHECK ((state = 'superseded') = (superseded_on IS NOT NULL))
);
CREATE INDEX member_periods_member_idx ON member_periods (member_id, starts_on);
CREATE INDEX member_periods_sale_idx ON member_periods (sale_id) WHERE sale_id IS NOT NULL;

-- Riwayat member (append-only): pembelian, perpanjangan, upgrade, aktivasi, koreksi manual (dengan alasan serta
-- data sebelum & sesudah), ganti kartu, ubah data pelanggan.
CREATE TABLE member_events (
  id             BIGSERIAL     PRIMARY KEY,
  member_id      BIGINT        NOT NULL REFERENCES members(id),
  period_id      BIGINT        REFERENCES member_periods(id),
  event          VARCHAR(20)   NOT NULL,
  sale_id        BIGINT        REFERENCES sales(id),
  reason         VARCHAR(300),
  before         JSONB,
  after          JSONB,
  actor_user_id  BIGINT        REFERENCES users(id),
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX member_events_member_idx ON member_events (member_id, id DESC);

/* ---------------------------------------------------------------- Transaksi */

-- customer_id/member_id: pelanggan & kartu member di transaksi. member_tier_id: tipe yang dipakai untuk diskon.
-- client_ref: kunci idempotensi dari POS; request pembayaran yang dikirim ulang mengembalikan transaksi yang sama.
ALTER TABLE sales ADD COLUMN customer_id BIGINT REFERENCES customers(id);
ALTER TABLE sales ADD COLUMN member_id BIGINT REFERENCES members(id);
ALTER TABLE sales ADD COLUMN member_tier_id BIGINT REFERENCES member_tiers(id);
ALTER TABLE sales ADD COLUMN member_amount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (member_amount >= 0);
ALTER TABLE sales ADD COLUMN client_ref VARCHAR(64);
CREATE UNIQUE INDEX sales_client_ref_uq ON sales (terminal_id, client_ref) WHERE client_ref IS NOT NULL;
CREATE INDEX sales_member_idx ON sales (member_id, created_at DESC) WHERE member_id IS NOT NULL;
CREATE INDEX sales_customer_idx ON sales (customer_id) WHERE customer_id IS NOT NULL;

ALTER TABLE sale_items ADD COLUMN member_amount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (member_amount >= 0);
DROP INDEX IF EXISTS sale_items_sale_idx;
CREATE INDEX sale_items_sale_idx ON sale_items (sale_id)
  INCLUDE (product_id, qty, unit_factor, subtotal, unit_cost, discount_amount, promo_amount, voucher_amount, member_amount);

-- Diskon member di ringkasan laporan harian (hari lama tidak punya diskon member, jadi 0 tetap benar).
ALTER TABLE report_sales ADD COLUMN member_discount NUMERIC NOT NULL DEFAULT 0;

/* ---------------------------------------------------------------- Hak akses */

INSERT INTO permissions (code, module, name) VALUES
  ('membership.view',   'member', 'Melihat member, kartu member, dan riwayatnya'),
  ('membership.manage', 'member', 'Mengelola tipe member, diskon member, pengaturan membership, data pelanggan & kartu'),
  ('membership.adjust', 'member', 'Koreksi manual membership di luar transaksi POS (masa aktif, tipe, pembatalan, pemberian)');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN ('membership.view', 'membership.manage', 'membership.adjust')
 WHERE r.code = 'owner';
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN ('membership.view', 'membership.manage')
 WHERE r.code = 'admin';
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code = 'membership.view'
 WHERE r.code = 'supervisor';
