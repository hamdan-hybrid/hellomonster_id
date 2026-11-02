-- Waiver: versi dokumen Pengecualian dan Persetujuan yang dibaca & disetujui pengunjung (public/js/waiver-terms.js).
ALTER TABLE waivers ADD COLUMN terms_version VARCHAR(20) NOT NULL DEFAULT '';
ALTER TABLE waivers ALTER COLUMN terms_version DROP DEFAULT;
