-- Menu "Pengembalian" (uang kembali tanpa barang) di POS dihapus: uang hanya kembali ke pelanggan lewat Retur, yang
-- terhubung ke transaksi & barangnya. Izin pos.refund tetap dipakai Retur — pemegangnya memproses retur tanpa
-- persetujuan atasan. Data cash_movements 'refund' yang sudah ada tetap tercatat di laporan.
UPDATE permissions SET name = 'Memproses retur tanpa persetujuan atasan' WHERE code = 'pos.refund';
