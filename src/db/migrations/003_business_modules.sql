-- Modul bisnis: Master Data, Stok & Inventori, Pembelian, Pengeluaran, Pengaturan.
-- Semua data operasional terikat ke cabang; master produk berlaku untuk semua cabang.

/* ---------------------------------------------------------------- Izin tambahan */

INSERT INTO permissions (code, module, name) VALUES
  ('master_data.view', 'master',      'Melihat master data'),
  ('inventory.view',   'stok',        'Melihat stok & kartu stok'),
  ('purchasing.view',  'pembelian',   'Melihat pembelian'),
  ('expenses.view',    'pengeluaran', 'Melihat pengeluaran');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
  ON p.code IN ('master_data.view', 'inventory.view', 'purchasing.view', 'expenses.view')
 WHERE r.code IN ('owner', 'admin');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
  ON p.code IN ('master_data.view', 'inventory.view', 'purchasing.view')
 WHERE r.code = 'supervisor';

/* ---------------------------------------------------------------- Pengaturan */

CREATE TABLE app_settings (
  key         VARCHAR(60) PRIMARY KEY,
  value       JSONB       NOT NULL,
  updated_by  BIGINT      REFERENCES users(id),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

/* ---------------------------------------------------------------- Master data */

CREATE TABLE product_categories (
  id          BIGSERIAL PRIMARY KEY,
  name        VARCHAR(80)  NOT NULL,
  is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX product_categories_name_uq ON product_categories (lower(name));

CREATE TABLE units (
  id             BIGSERIAL PRIMARY KEY,
  code           VARCHAR(20)  NOT NULL,
  name           VARCHAR(60)  NOT NULL,
  allow_decimal  BOOLEAN      NOT NULL DEFAULT FALSE,
  is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX units_code_uq ON units (lower(code));

INSERT INTO units (code, name, allow_decimal) VALUES
  ('pcs', 'Pieces', FALSE),
  ('box', 'Box', FALSE),
  ('pack', 'Pack', FALSE),
  ('btl', 'Botol', FALSE),
  ('kg', 'Kilogram', TRUE),
  ('ltr', 'Liter', TRUE);

CREATE TABLE suppliers (
  id              BIGSERIAL PRIMARY KEY,
  name            VARCHAR(150) NOT NULL,
  contact_person  VARCHAR(120),
  phone           VARCHAR(40),
  email           VARCHAR(254),
  address         TEXT,
  notes           TEXT,
  is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX suppliers_name_uq ON suppliers (lower(name));

CREATE TABLE products (
  id             BIGSERIAL PRIMARY KEY,
  sku            VARCHAR(40)   NOT NULL,
  barcode        VARCHAR(60),
  name           VARCHAR(150)  NOT NULL,
  category_id    BIGINT        REFERENCES product_categories(id),
  unit_id        BIGINT        NOT NULL REFERENCES units(id),
  selling_price  NUMERIC(14,2) NOT NULL CHECK (selling_price >= 0),
  -- Harga beli acuan (diperbarui dari pembelian terakhir); HPP aktual memakai rata-rata per cabang.
  cost_price     NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (cost_price >= 0),
  track_stock    BOOLEAN       NOT NULL DEFAULT TRUE,
  min_stock      NUMERIC(14,3) NOT NULL DEFAULT 0 CHECK (min_stock >= 0),
  is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX products_sku_uq ON products (lower(sku));
CREATE UNIQUE INDEX products_barcode_uq ON products (barcode) WHERE barcode IS NOT NULL;
CREATE INDEX products_name_idx ON products (lower(name));

/* ---------------------------------------------------------------- Stok */

-- Saldo stok per produk per cabang dengan harga pokok rata-rata (moving average).
CREATE TABLE product_stocks (
  product_id  BIGINT        NOT NULL REFERENCES products(id),
  branch_id   BIGINT        NOT NULL REFERENCES branches(id),
  qty         NUMERIC(14,3) NOT NULL DEFAULT 0,
  avg_cost    NUMERIC(14,4) NOT NULL DEFAULT 0 CHECK (avg_cost >= 0),
  updated_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
  PRIMARY KEY (product_id, branch_id)
);
CREATE INDEX product_stocks_branch_idx ON product_stocks (branch_id);

-- Kartu stok: setiap perubahan saldo tercatat di sini (append-only).
CREATE TABLE stock_movements (
  id          BIGSERIAL PRIMARY KEY,
  product_id  BIGINT        NOT NULL REFERENCES products(id),
  branch_id   BIGINT        NOT NULL REFERENCES branches(id),
  type        VARCHAR(20)   NOT NULL CHECK (type IN ('sale', 'purchase', 'adjustment', 'opname', 'transfer_in', 'transfer_out')),
  qty_change  NUMERIC(14,3) NOT NULL CHECK (qty_change <> 0),
  qty_after   NUMERIC(14,3) NOT NULL,
  unit_cost   NUMERIC(14,4) NOT NULL DEFAULT 0,
  ref_type    VARCHAR(30),
  ref_id      BIGINT,
  note        VARCHAR(200),
  created_by  BIGINT        REFERENCES users(id),
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX stock_movements_product_idx ON stock_movements (product_id, branch_id, id DESC);
CREATE INDEX stock_movements_ref_idx ON stock_movements (ref_type, ref_id);

CREATE TABLE stock_adjustments (
  id          BIGSERIAL PRIMARY KEY,
  doc_no      VARCHAR(40)  NOT NULL UNIQUE,
  branch_id   BIGINT       NOT NULL REFERENCES branches(id),
  kind        VARCHAR(12)  NOT NULL CHECK (kind IN ('adjustment', 'opname')),
  reason      VARCHAR(200) NOT NULL,
  created_by  BIGINT       NOT NULL REFERENCES users(id),
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX stock_adjustments_branch_idx ON stock_adjustments (branch_id, created_at DESC);

CREATE TABLE stock_adjustment_items (
  id             BIGSERIAL PRIMARY KEY,
  adjustment_id  BIGINT        NOT NULL REFERENCES stock_adjustments(id) ON DELETE CASCADE,
  product_id     BIGINT        NOT NULL REFERENCES products(id),
  qty_before     NUMERIC(14,3) NOT NULL,
  qty_change     NUMERIC(14,3) NOT NULL,
  qty_after      NUMERIC(14,3) NOT NULL,
  unit_cost      NUMERIC(14,4) NOT NULL DEFAULT 0
);

CREATE TABLE stock_transfers (
  id              BIGSERIAL PRIMARY KEY,
  doc_no          VARCHAR(40)  NOT NULL UNIQUE,
  from_branch_id  BIGINT       NOT NULL REFERENCES branches(id),
  to_branch_id    BIGINT       NOT NULL REFERENCES branches(id),
  note            VARCHAR(200),
  created_by      BIGINT       NOT NULL REFERENCES users(id),
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CHECK (from_branch_id <> to_branch_id)
);
CREATE INDEX stock_transfers_from_idx ON stock_transfers (from_branch_id, created_at DESC);
CREATE INDEX stock_transfers_to_idx ON stock_transfers (to_branch_id, created_at DESC);

CREATE TABLE stock_transfer_items (
  id           BIGSERIAL PRIMARY KEY,
  transfer_id  BIGINT        NOT NULL REFERENCES stock_transfers(id) ON DELETE CASCADE,
  product_id   BIGINT        NOT NULL REFERENCES products(id),
  qty          NUMERIC(14,3) NOT NULL CHECK (qty > 0),
  unit_cost    NUMERIC(14,4) NOT NULL DEFAULT 0
);

/* ---------------------------------------------------------------- Pembelian */

CREATE TABLE purchases (
  id                   BIGSERIAL PRIMARY KEY,
  purchase_no          VARCHAR(40)   NOT NULL UNIQUE,
  branch_id            BIGINT        NOT NULL REFERENCES branches(id),
  supplier_id          BIGINT        NOT NULL REFERENCES suppliers(id),
  status               VARCHAR(10)   NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'received', 'cancelled')),
  purchase_date        DATE          NOT NULL,
  due_date             DATE,
  supplier_invoice_no  VARCHAR(60),
  notes                TEXT,
  total                NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
  paid_amount          NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
  created_by           BIGINT        NOT NULL REFERENCES users(id),
  received_by          BIGINT        REFERENCES users(id),
  received_at          TIMESTAMPTZ,
  cancelled_by         BIGINT        REFERENCES users(id),
  cancelled_at         TIMESTAMPTZ,
  created_at           TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ   NOT NULL DEFAULT now(),
  CHECK (paid_amount <= total)
);
CREATE INDEX purchases_branch_idx ON purchases (branch_id, purchase_date DESC);
CREATE INDEX purchases_supplier_idx ON purchases (supplier_id);

CREATE TABLE purchase_items (
  id           BIGSERIAL PRIMARY KEY,
  purchase_id  BIGINT        NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
  product_id   BIGINT        NOT NULL REFERENCES products(id),
  qty          NUMERIC(14,3) NOT NULL CHECK (qty > 0),
  unit_cost    NUMERIC(14,2) NOT NULL CHECK (unit_cost >= 0),
  subtotal     NUMERIC(14,2) NOT NULL
);
CREATE INDEX purchase_items_purchase_idx ON purchase_items (purchase_id);

-- Pembayaran ke pemasok (pelunasan hutang). Tidak memengaruhi kas laci POS.
CREATE TABLE purchase_payments (
  id           BIGSERIAL PRIMARY KEY,
  purchase_id  BIGINT        NOT NULL REFERENCES purchases(id),
  paid_at      DATE          NOT NULL,
  amount       NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  method       VARCHAR(20)   NOT NULL CHECK (method IN ('cash', 'transfer', 'qris', 'card', 'other')),
  note         VARCHAR(200),
  created_by   BIGINT        NOT NULL REFERENCES users(id),
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX purchase_payments_purchase_idx ON purchase_payments (purchase_id);

/* ---------------------------------------------------------------- Pengeluaran */

CREATE TABLE expense_categories (
  id          BIGSERIAL PRIMARY KEY,
  name        VARCHAR(80)  NOT NULL,
  is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX expense_categories_name_uq ON expense_categories (lower(name));

INSERT INTO expense_categories (name) VALUES
  ('Gaji & Upah'), ('Sewa Tempat'), ('Listrik & Air'), ('Internet & Telepon'),
  ('Transportasi'), ('Perlengkapan Toko'), ('Perawatan & Perbaikan'), ('Pemasaran'), ('Lain-lain');

-- Biaya operasional di luar kas laci POS (kas keluar laci dicatat di shift).
-- Tidak pernah dihapus; pembatalan memakai status 'void' beserta alasannya.
CREATE TABLE expenses (
  id            BIGSERIAL PRIMARY KEY,
  expense_no    VARCHAR(40)   NOT NULL UNIQUE,
  branch_id     BIGINT        NOT NULL REFERENCES branches(id),
  category_id   BIGINT        NOT NULL REFERENCES expense_categories(id),
  expense_date  DATE          NOT NULL,
  amount        NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  method        VARCHAR(20)   NOT NULL CHECK (method IN ('cash', 'transfer', 'qris', 'card', 'other')),
  description   VARCHAR(300)  NOT NULL,
  status        VARCHAR(10)   NOT NULL DEFAULT 'posted' CHECK (status IN ('posted', 'void')),
  void_reason   VARCHAR(200),
  voided_by     BIGINT        REFERENCES users(id),
  voided_at     TIMESTAMPTZ,
  created_by    BIGINT        NOT NULL REFERENCES users(id),
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX expenses_branch_idx ON expenses (branch_id, expense_date DESC);

/* ---------------------------------------------------------------- Penjualan ↔ produk */

-- product_id NULL = barang manual (bila diizinkan pengaturan). unit_cost = HPP saat terjual.
ALTER TABLE sale_items
  ADD COLUMN product_id BIGINT REFERENCES products(id),
  ADD COLUMN unit_cost  NUMERIC(14,4);
CREATE INDEX sale_items_product_idx ON sale_items (product_id);
