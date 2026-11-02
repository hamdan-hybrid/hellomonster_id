-- Laporan dipecah menjadi tiga menu (Operasional, Stok, Keuangan), masing-masing dengan izin sendiri.

INSERT INTO permissions (code, module, name) VALUES
  ('reports.operations.view', 'laporan', 'Melihat laporan operasional (penjualan, kasir & shift, promo, transaksi)'),
  ('reports.stock.view',      'laporan', 'Melihat laporan stok (posisi, mutasi, stok menipis, opname, pembelian)');

UPDATE permissions SET name = 'Melihat laporan keuangan (laba rugi, arus kas, hutang, pengeluaran)'
 WHERE code = 'reports.finance.view';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN ('reports.operations.view', 'reports.stock.view')
 WHERE r.code IN ('owner', 'admin', 'supervisor');

-- Laporan memfilter berdasarkan waktu untuk semua cabang sekaligus.
CREATE INDEX IF NOT EXISTS sales_time_idx ON sales (created_at);
CREATE INDEX IF NOT EXISTS stock_movements_branch_time_idx ON stock_movements (branch_id, created_at);
CREATE INDEX IF NOT EXISTS cash_movements_time_idx ON cash_movements (created_at);
CREATE INDEX IF NOT EXISTS purchase_payments_paid_idx ON purchase_payments (paid_at);
CREATE INDEX IF NOT EXISTS stock_adjustments_time_idx ON stock_adjustments (created_at);
