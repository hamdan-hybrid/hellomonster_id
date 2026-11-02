-- Pajak penjualan (src/services/tax.js). Tarif di Pengaturan → Profil usaha (business.taxRate), bisa diganti per
-- cabang (branches.tax_rate, mis. tarif daerah berbeda). Produk memilih kena pajak atau tidak, dan apakah harga
-- jualnya sudah termasuk pajak atau pajaknya ditambahkan saat bayar.
-- Pajak dihitung per baris dari harga setelah semua potongan (diskon, promo, voucher, member) dan disimpan beserta
-- tarifnya saat terjual, sehingga laporan lama tetap benar walau tarifnya diubah kemudian.
ALTER TABLE products
  ADD COLUMN taxable            BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN price_includes_tax BOOLEAN NOT NULL DEFAULT TRUE;

-- NULL = ikut tarif di Profil usaha.
ALTER TABLE branches ADD COLUMN tax_rate NUMERIC(5,2) CHECK (tax_rate >= 0 AND tax_rate <= 100);

-- subtotal = yang dibayar pelanggan untuk baris itu (termasuk pajak, baik yang sudah di dalam harga maupun yang
-- ditambahkan), sehingga SUM(subtotal) = sales.total tetap berlaku. tax_amount = bagian pajak di dalam subtotal.
ALTER TABLE sale_items
  ADD COLUMN tax_rate     NUMERIC(5,2),
  ADD COLUMN tax_included BOOLEAN,
  ADD COLUMN tax_amount   NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
  ADD CONSTRAINT sale_items_tax_chk CHECK ((tax_rate IS NULL) = (tax_included IS NULL) AND (tax_rate IS NOT NULL OR tax_amount = 0));

-- tax_amount = total pajak; tax_added = bagian yang ditambahkan di atas harga (bagian sisanya sudah di dalam harga).
ALTER TABLE sales
  ADD COLUMN tax_amount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
  ADD COLUMN tax_added  NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (tax_added >= 0 AND tax_added <= tax_amount);

-- Ringkasan harian ikut menyimpan pajak: laporan laba memakai penjualan tanpa pajak. Hari lama bernilai 0 (benar:
-- belum ada pajak), jadi tidak perlu diringkas ulang.
ALTER TABLE report_sales ADD COLUMN tax NUMERIC NOT NULL DEFAULT 0;
ALTER TABLE report_products ADD COLUMN tax NUMERIC NOT NULL DEFAULT 0;
ALTER TABLE report_products_month ADD COLUMN tax NUMERIC NOT NULL DEFAULT 0;
ALTER TABLE report_categories ADD COLUMN tax NUMERIC NOT NULL DEFAULT 0;
