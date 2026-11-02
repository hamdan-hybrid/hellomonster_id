-- Ringkasan penjualan harian untuk laporan rentang panjang (cara pakai: src/services/salesRollup.js).
-- Hari yang sudah lewat diringkas sekali per hari × cabang. Laporan membaca ringkasan untuk hari yang siap
-- dan menghitung langsung dari transaksi untuk hari lain (hari ini, belum diringkas, atau perlu diringkas ulang),
-- sehingga waktu laporan tidak lagi bergantung pada umur data.
-- Angka disimpan sebagai NUMERIC tanpa skala: jumlahnya mempertahankan skala asli (mis. 2 desimal untuk uang),
-- sehingga hasil laporan identik dengan hitungan langsung. Nama produk, satuan, dan nama kategori tidak disimpan
-- (dibaca saat laporan dibuka).

-- Hari yang sudah diringkas (semua cabang sekaligus). Baris ringkasan ikut terhapus bila hari diringkas ulang.
CREATE TABLE report_days (
  day       DATE        PRIMARY KEY,
  built_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Hari yang datanya berubah setelah diringkas: dihitung langsung sampai diringkas ulang.
CREATE TABLE report_dirty_days (
  day        DATE        PRIMARY KEY,
  marked_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Hari yang hanya ringkasan per kategorinya perlu dihitung ulang (kategori produk diubah).
CREATE TABLE report_stale_categories (
  day        DATE        PRIMARY KEY,
  marked_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Per hari × cabang × jam × kasir: jumlah transaksi, omzet, barang, HPP, dan potongan.
CREATE TABLE report_sales (
  day                 DATE    NOT NULL REFERENCES report_days(day) ON DELETE CASCADE,
  branch_id           BIGINT  NOT NULL,
  hour                INT     NOT NULL,
  cashier_id          BIGINT  NOT NULL,
  sale_count          INT     NOT NULL,
  total               NUMERIC NOT NULL,  -- SUM(sales.total)
  items               NUMERIC NOT NULL,  -- SUM(sale_items.qty)
  subtotal            NUMERIC NOT NULL,  -- SUM(sale_items.subtotal)
  cogs                NUMERIC NOT NULL,
  item_discount       NUMERIC NOT NULL,
  promo_discount      NUMERIC NOT NULL,
  voucher_discount    NUMERIC NOT NULL,
  discounted_count    INT     NOT NULL,
  unknown_cost_lines  INT     NOT NULL,
  PRIMARY KEY (day, branch_id, hour, cashier_id)
);

-- Per hari × cabang × metode pembayaran.
CREATE TABLE report_payments (
  day         DATE        NOT NULL REFERENCES report_days(day) ON DELETE CASCADE,
  branch_id   BIGINT      NOT NULL,
  method      VARCHAR(20) NOT NULL,
  sale_count  INT         NOT NULL,
  amount      NUMERIC     NOT NULL,
  PRIMARY KEY (day, branch_id, method)
);

-- Per hari × cabang × produk (barang manual: per nama).
CREATE TABLE report_products (
  day                 DATE         NOT NULL REFERENCES report_days(day) ON DELETE CASCADE,
  branch_id           BIGINT       NOT NULL,
  product_id          BIGINT,
  custom_name         VARCHAR(150),
  qty                 NUMERIC      NOT NULL,  -- dalam satuan dasar
  sale_count          INT          NOT NULL,
  subtotal            NUMERIC      NOT NULL,
  cogs                NUMERIC      NOT NULL,
  discount            NUMERIC      NOT NULL,
  unknown_cost_lines  INT          NOT NULL
);
CREATE INDEX report_products_day_idx ON report_products (day, branch_id);
CREATE INDEX report_products_product_idx ON report_products (product_id, day);

-- Bulan penuh yang semua harinya sudah diringkas (month = tanggal 1). Ikut terhapus bila salah satu harinya diringkas ulang.
CREATE TABLE report_months (
  month     DATE        PRIMARY KEY REFERENCES report_days(day) ON DELETE CASCADE,
  built_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Per bulan × cabang × produk: laporan per produk rentang panjang membaca bulan penuh dari sini.
CREATE TABLE report_products_month (
  month               DATE         NOT NULL REFERENCES report_months(month) ON DELETE CASCADE,
  branch_id           BIGINT       NOT NULL,
  product_id          BIGINT,
  custom_name         VARCHAR(150),
  qty                 NUMERIC      NOT NULL,
  sale_count          INT          NOT NULL,
  subtotal            NUMERIC      NOT NULL,
  cogs                NUMERIC      NOT NULL,
  discount            NUMERIC      NOT NULL,
  unknown_cost_lines  INT          NOT NULL
);
CREATE INDEX report_products_month_idx ON report_products_month (month, branch_id);

-- Per hari × cabang × kategori (kategori produk saat diringkas; ditandai di report_stale_categories bila kategori
-- produk diubah). Diperlukan untuk jumlah transaksi per kategori (satu transaksi dihitung sekali per kategori).
CREATE TABLE report_categories (
  day                 DATE    NOT NULL REFERENCES report_days(day) ON DELETE CASCADE,
  branch_id           BIGINT  NOT NULL,
  category_id         BIGINT,
  custom              BOOLEAN NOT NULL,  -- barang manual (tanpa produk)
  sale_count          INT     NOT NULL,
  subtotal            NUMERIC NOT NULL,
  cogs                NUMERIC NOT NULL,
  discount            NUMERIC NOT NULL,
  unknown_cost_lines  INT     NOT NULL
);
CREATE INDEX report_categories_day_idx ON report_categories (day, branch_id);

-- Per hari × cabang × promo. kind: d = diskon produk, c = promo kombinasi/beli-dapat, v = voucher.
CREATE TABLE report_promotions (
  day           DATE    NOT NULL REFERENCES report_days(day) ON DELETE CASCADE,
  branch_id     BIGINT  NOT NULL,
  kind          CHAR(1) NOT NULL CHECK (kind IN ('d', 'c', 'v')),
  promotion_id  BIGINT  NOT NULL,
  sale_count    INT     NOT NULL,
  amount        NUMERIC NOT NULL,
  times         INT     NOT NULL,
  PRIMARY KEY (day, branch_id, kind, promotion_id)
);

/* ---------------------------------------------------------------- Penanda hari yang berubah */

-- Hari dari sebuah waktu, ±1 hari agar tetap benar walau sesi yang mengubah data memakai zona waktu lain.
CREATE FUNCTION report_mark_dirty(ts TIMESTAMPTZ) RETURNS void LANGUAGE sql AS $$
  INSERT INTO report_dirty_days (day)
  SELECT d::date FROM generate_series(ts::date - 1, ts::date + 1, interval '1 day') d
  ON CONFLICT (day) DO NOTHING
$$;

CREATE FUNCTION report_sales_changed() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP <> 'INSERT' THEN PERFORM report_mark_dirty(OLD.created_at); END IF;
  IF TG_OP <> 'DELETE' THEN PERFORM report_mark_dirty(NEW.created_at); END IF;
  RETURN NULL;
END $$;

-- Transaksi kasir (created_at = sekarang) tidak memicu apa pun: hari ini belum pernah diringkas.
-- Hanya data bertanggal lampau (impor/perbaikan) yang menandai harinya.
CREATE TRIGGER report_sales_insert AFTER INSERT ON sales FOR EACH ROW
  WHEN (NEW.created_at < now() - interval '1 hour') EXECUTE FUNCTION report_sales_changed();
CREATE TRIGGER report_sales_change AFTER UPDATE OR DELETE ON sales FOR EACH ROW EXECUTE FUNCTION report_sales_changed();

-- Barang/pembayaran/promo hanya ditambahkan bersama transaksinya; perubahan sesudahnya menandai hari transaksi.
-- (Menyisipkan baris ke transaksi lama secara manual: jalankan TRUNCATE report_days CASCADE agar diringkas ulang.)
CREATE FUNCTION report_sale_child_changed() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP <> 'INSERT' THEN PERFORM report_mark_dirty(s.created_at) FROM sales s WHERE s.id = OLD.sale_id; END IF;
  IF TG_OP <> 'DELETE' THEN PERFORM report_mark_dirty(s.created_at) FROM sales s WHERE s.id = NEW.sale_id; END IF;
  RETURN NULL;
END $$;

CREATE TRIGGER report_sale_items_change AFTER UPDATE OR DELETE ON sale_items FOR EACH ROW EXECUTE FUNCTION report_sale_child_changed();
CREATE TRIGGER report_sale_payments_change AFTER UPDATE OR DELETE ON sale_payments FOR EACH ROW EXECUTE FUNCTION report_sale_child_changed();
CREATE TRIGGER report_sale_promotions_change AFTER UPDATE OR DELETE ON sale_promotions FOR EACH ROW EXECUTE FUNCTION report_sale_child_changed();

-- Kategori produk berubah: ringkasan per kategori pada hari-hari produk itu terjual dihitung ulang
-- (laporan lain tetap memakai ringkasan). Kunci bersama menunggu peringkasan hari yang sedang berjalan selesai,
-- agar barisnya terlihat dan ikut ditandai.
CREATE FUNCTION report_product_category_changed() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_advisory_xact_lock_shared(727003);
  INSERT INTO report_stale_categories (day)
  SELECT DISTINCT day FROM report_products WHERE product_id = NEW.id
  ON CONFLICT (day) DO NOTHING;
  RETURN NULL;
END $$;

CREATE TRIGGER report_product_category AFTER UPDATE OF category_id ON products FOR EACH ROW
  WHEN (OLD.category_id IS DISTINCT FROM NEW.category_id) EXECUTE FUNCTION report_product_category_changed();
