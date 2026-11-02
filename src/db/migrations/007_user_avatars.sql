-- Foto profil pengguna. Gambar sudah diperkecil di browser (maks. 256×256) sehingga
-- cukup disimpan di database; tidak ada file di disk server.
CREATE TABLE user_avatars (
  user_id     BIGINT      PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  mime        VARCHAR(20) NOT NULL CHECK (mime IN ('image/jpeg', 'image/png', 'image/webp')),
  data        BYTEA       NOT NULL CHECK (octet_length(data) <= 204800),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
