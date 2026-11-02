-- Jam berlaku harian promo & voucher (jam usaha, APP_TIMEZONE), mis. Happy Hour 10:00–12:00 setiap hari selama
-- periodenya. Keduanya NULL = sepanjang hari. Jam selesai tidak ikut (10:00–12:00 berlaku sampai 11:59:59);
-- jam selesai lebih kecil dari jam mulai = melewati tengah malam (mis. 22:00–02:00).
ALTER TABLE promotions
  ADD COLUMN time_start TIME(0),
  ADD COLUMN time_end   TIME(0),
  ADD CONSTRAINT promotions_hours_chk CHECK ((time_start IS NULL) = (time_end IS NULL) AND (time_start IS NULL OR time_start <> time_end));
