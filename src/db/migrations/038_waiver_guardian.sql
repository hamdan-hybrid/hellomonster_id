-- Waiver: isian wajib = nama, nomor HP, tanggal lahir, nama orang tua, nomor HP darurat (+ persetujuan). Email,
-- negara, kota, dan alamat menjadi opsional.
ALTER TABLE waivers
  ADD COLUMN parent_name     VARCHAR(120) NOT NULL DEFAULT '',
  ADD COLUMN emergency_phone VARCHAR(20)  NOT NULL DEFAULT '',
  ALTER COLUMN email   DROP NOT NULL,
  ALTER COLUMN country DROP NOT NULL,
  ALTER COLUMN city    DROP NOT NULL,
  ALTER COLUMN address DROP NOT NULL;
ALTER TABLE waivers ALTER COLUMN parent_name DROP DEFAULT, ALTER COLUMN emergency_phone DROP DEFAULT;
