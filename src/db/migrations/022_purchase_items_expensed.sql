-- Baris pembelian yang langsung dibiayakan: barang dibeli untuk dipakai habis (bukan dijual), jadi saat pembelian
-- diterima stok tidak bertambah dan harga beli acuan produk tidak berubah. Subtotal barisnya menjadi beban
-- "Pembelian langsung dibiayakan" di laporan laba rugi pada tanggal pembelian. Hutang & pembayaran pemasok tetap
-- lewat pembelian (arus kas tercatat sebagai pembayaran pemasok, tidak dobel dengan pengeluaran).
ALTER TABLE purchase_items ADD COLUMN IF NOT EXISTS expensed BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS purchase_items_expensed_idx ON purchase_items (purchase_id) WHERE expensed;
