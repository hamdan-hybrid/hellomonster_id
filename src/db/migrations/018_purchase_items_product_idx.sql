-- Pembelian terakhir per produk (laporan stok menipis, riwayat harga beli) dicari lewat product_id.
-- Tanpa index ini setiap produk memindai seluruh purchase_items: diukur 676 produk × 0,3 ms = 200 ms
-- dari total 217 ms pada 4.000 baris barang pembelian, dan terus bertambah seiring pembelian.
CREATE INDEX IF NOT EXISTS purchase_items_product_idx ON purchase_items (product_id);
