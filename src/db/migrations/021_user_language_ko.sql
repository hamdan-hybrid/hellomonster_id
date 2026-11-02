-- Bahasa Korea (ko) sebagai pilihan bahasa antarmuka per akun (lihat 019_user_language.sql).
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_language_check;
ALTER TABLE users ADD CONSTRAINT users_language_check CHECK (language IS NULL OR language IN ('id', 'en', 'nan', 'ko'));
