-- Index laporan & dashboard (diukur dengan 90.000 transaksi / 270.000 baris barang dalam 120 hari).
-- Rentang tanggal transaksi selesai dibaca langsung dari index (tanpa membuka tabel sales).
CREATE INDEX IF NOT EXISTS sales_completed_time_idx ON sales (created_at) INCLUDE (id, branch_id, total, cashier_id)
  WHERE status = 'completed';

-- Barang per transaksi beserta angka yang dijumlah laporan (jumlah, subtotal, HPP, potongan): laporan cukup
-- membaca index. Menggantikan index sale_id biasa, jadi beban saat menyimpan transaksi tidak bertambah.
DROP INDEX IF EXISTS sale_items_sale_idx;
CREATE INDEX sale_items_sale_idx ON sale_items (sale_id)
  INCLUDE (product_id, qty, unit_factor, subtotal, unit_cost, discount_amount, promo_amount, voucher_amount);
