-- Waktu bermain produk playground: 30 menit, 1 jam, 2 jam, sepuasnya, atau diisi sendiri (maks. 24 jam).
-- play_minutes = menit per tiket, 0 = sepuasnya, NULL = bukan produk playground. Baris transaksi menyalin waktu bermain saat terjual (struk & tiket
-- masuk tetap sama walau produknya diubah kemudian). Produk playground yang sudah ada menjadi sepuasnya.
ALTER TABLE products ADD COLUMN play_minutes INT CHECK (play_minutes BETWEEN 0 AND 1440);
UPDATE products SET play_minutes = 0 WHERE product_type = 'playground';

ALTER TABLE sale_items ADD COLUMN play_minutes INT CHECK (play_minutes BETWEEN 0 AND 1440);
