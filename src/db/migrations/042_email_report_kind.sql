-- Jenis laporan per jadwal email (src/services/reportMail.js):
--   summary = Ringkasan harian pemilik: satu halaman berisi omzet, pengunjung, laba kotor, pengeluaran, kas & shift,
--             dan daftar "Perlu perhatian" (selisih kas, shift belum ditutup, stok menipis, hutang jatuh tempo, …).
--   sales   = Laporan omset lengkap (metode bayar, per jam/hari, kategori, produk terlaris, per cabang).
-- Jadwal yang sudah ada tetap laporan omset.
ALTER TABLE email_schedules ADD COLUMN report VARCHAR(20) NOT NULL DEFAULT 'sales' CHECK (report IN ('summary', 'sales'));
