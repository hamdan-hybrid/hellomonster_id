-- Foto produk & foto profil disimpan sebagai file di folder storage/ (lihat src/services/storage.js);
-- database cukup menyimpan keterangannya (sha256/mime/waktu).
-- Kolom data dipertahankan sementara dan boleh kosong: saat start, server memindahkan isi lama ke storage/
-- lalu mengosongkannya. data kosong = file ada di storage/.

ALTER TABLE media ALTER COLUMN data DROP NOT NULL;
ALTER TABLE user_avatars ALTER COLUMN data DROP NOT NULL;
