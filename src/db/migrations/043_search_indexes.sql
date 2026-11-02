-- Hasil audit performa (uji volume DB uji: 200 rb transaksi, 30 rb pelanggan):
-- 1. Pencarian pelanggan / member memakai '%…%' (nama, nomor member, digit nomor HP) → index trigram (pg_trgm sudah
--    terpasang sejak migrasi index produk). Kondisinya ditulis sebagai subquery id per kolom (services/customers.js)
--    agar setiap bagian bisa memakai index-nya sendiri, bukan OR lintas tabel yang memaksa baca seluruh tabel.
CREATE INDEX IF NOT EXISTS customers_name_trgm ON customers USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS customers_phone_digits_trgm ON customers USING gin ((regexp_replace(COALESCE(phone, ''), '\D', '', 'g')) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS members_member_no_trgm ON members USING gin (member_no gin_trgm_ops);
-- 2. Waiver pengunjung umum dicari dari akhir nomor HP / HP darurat (services/waivers.js byPhone): digit dibalik lalu
--    dicari dengan awalan (LIKE 'xxxx%'), sehingga index btree text_pattern_ops terpakai.
CREATE INDEX IF NOT EXISTS waivers_phone_rev_idx ON waivers (reverse(regexp_replace(phone, '\D', '', 'g')) text_pattern_ops);
CREATE INDEX IF NOT EXISTS waivers_emergency_rev_idx ON waivers (reverse(regexp_replace(emergency_phone, '\D', '', 'g')) text_pattern_ops);
-- 3. Baris dokumen dicari dari induknya (daftar & detail penyesuaian / opname, transfer stok, retur ke saldo member).
CREATE INDEX IF NOT EXISTS stock_adjustment_items_adjustment_idx ON stock_adjustment_items (adjustment_id);
CREATE INDEX IF NOT EXISTS stock_transfer_items_transfer_idx ON stock_transfer_items (transfer_id);
CREATE INDEX IF NOT EXISTS member_wallet_tx_return_idx ON member_wallet_tx (return_id) WHERE return_id IS NOT NULL;
