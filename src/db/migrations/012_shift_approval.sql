-- Tutup shift di POS wajib disetujui atasan (username + password akun berizin shifts.manage);
-- nama yang menyetujui disimpan dan tercetak di laporan tutup shift.
ALTER TABLE cashier_shifts ADD COLUMN approved_by BIGINT REFERENCES users(id);

-- Riwayat: shift yang ditutup paksa dari Backoffice dianggap disetujui oleh yang menutupnya.
UPDATE cashier_shifts SET approved_by = closed_by
 WHERE status = 'closed' AND closed_by IS NOT NULL AND closed_by <> user_id;

UPDATE permissions SET name = 'Menyetujui tutup shift kasir & menutup paksa shift' WHERE code = 'shifts.manage';
