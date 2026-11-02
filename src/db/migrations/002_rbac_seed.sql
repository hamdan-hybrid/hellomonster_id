-- Data referensi RBAC. Tidak ada akun pengguna/demo yang dibuat di sini;
-- administrator pertama dibuat lewat `npm run create-admin`.

INSERT INTO permissions (code, module, name) VALUES
  ('backoffice.access',      'akses',      'Masuk ke Backoffice'),
  ('pos.access',             'akses',      'Masuk ke Kasir POS'),
  ('dashboard.view',         'dashboard',  'Melihat dashboard'),
  ('users.view',             'pengguna',   'Melihat pengguna & kasir'),
  ('users.manage',           'pengguna',   'Menambah / mengubah / menonaktifkan pengguna'),
  ('users.reset_pin',        'pengguna',   'Mengatur ulang PIN kasir'),
  ('users.reset_password',   'pengguna',   'Mengatur ulang password pengguna'),
  ('users.unlock',           'pengguna',   'Membuka blokir sementara percobaan login'),
  ('sessions.view',          'pengguna',   'Melihat sesi aktif'),
  ('sessions.revoke',        'pengguna',   'Mengakhiri sesi pengguna'),
  ('branches.view',          'cabang',     'Melihat cabang'),
  ('branches.manage',        'cabang',     'Mengelola cabang'),
  ('branches.all',           'cabang',     'Akses data semua cabang'),
  ('terminals.view',         'terminal',   'Melihat terminal POS'),
  ('terminals.manage',       'terminal',   'Mengelola & memasangkan terminal POS'),
  ('audit.view',             'audit',      'Melihat audit log'),
  ('shifts.view',            'shift',      'Melihat laporan shift kasir'),
  ('shifts.manage',          'shift',      'Menutup paksa shift kasir'),
  ('reports.finance.view',   'laporan',    'Melihat laporan keuangan'),
  ('master_data.manage',     'master',     'Mengelola master data'),
  ('purchasing.manage',      'pembelian',  'Mengelola pembelian'),
  ('inventory.manage',       'stok',       'Mengelola stok'),
  ('expenses.manage',        'pengeluaran','Mengelola pengeluaran'),
  ('settings.manage',        'pengaturan', 'Mengelola pengaturan sistem'),
  ('pos.transaction',        'pos',        'Membuat transaksi penjualan'),
  ('pos.shift.open',         'pos',        'Membuka shift'),
  ('pos.shift.close',        'pos',        'Menutup shift'),
  ('pos.cash_movement',      'pos',        'Mencatat kas masuk / keluar'),
  ('pos.refund',             'pos',        'Mencatat pengembalian uang');

INSERT INTO roles (code, name, description, is_system) VALUES
  ('owner',      'Pemilik',       'Akses penuh ke seluruh modul dan cabang', TRUE),
  ('admin',      'Administrator', 'Mengelola pengguna, terminal, dan operasional di cabangnya', TRUE),
  ('supervisor', 'Supervisor',    'Memantau shift dan kasir di cabangnya', TRUE),
  ('cashier',    'Kasir',         'Bertransaksi di POS', TRUE);

-- Pemilik: semua izin.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p WHERE r.code = 'owner';

-- Administrator: semua kecuali pengelolaan cabang, pengaturan sistem, dan akses lintas cabang
-- (administrator bekerja dalam cabangnya sendiri; Pemilik mencakup semua cabang).
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p
  ON p.code NOT IN ('branches.manage', 'settings.manage', 'branches.all')
 WHERE r.code = 'admin';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN (
  'backoffice.access', 'pos.access', 'dashboard.view', 'users.view', 'users.unlock',
  'sessions.view', 'branches.view', 'terminals.view', 'shifts.view', 'shifts.manage',
  'pos.transaction', 'pos.shift.open', 'pos.shift.close', 'pos.cash_movement', 'pos.refund'
) WHERE r.code = 'supervisor';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN (
  'pos.access', 'pos.transaction', 'pos.shift.open', 'pos.shift.close', 'pos.cash_movement'
) WHERE r.code = 'cashier';
