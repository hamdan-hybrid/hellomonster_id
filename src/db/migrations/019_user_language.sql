-- Preferensi bahasa antarmuka per akun: id (Indonesia), en (English), nan (Hokkien).
-- NULL = belum pernah memilih → memakai bahasa bawaan Indonesia. Hanya mengubah tampilan; data tidak terpengaruh.
ALTER TABLE users ADD COLUMN IF NOT EXISTS language text;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_language_check;
ALTER TABLE users ADD CONSTRAINT users_language_check CHECK (language IS NULL OR language IN ('id', 'en', 'nan'));
