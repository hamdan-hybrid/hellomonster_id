-- Kartu RFID, foto, dan saldo member (lihat src/services/memberWallet.js).
--  - Kartu RFID: UID kartu dibaca reader USB di kasir (reader mengetik UID lalu Enter). Satu kartu RFID per member;
--    kartu QR (card_code) tetap berlaku. Ganti kartu RFID = UID lama tidak berlaku lagi (tercatat di member_events).
--  - Foto member: file storage/members/<id member>.<ext> (seperti foto profil), hanya dibuka lewat API ber-sesi.
--    Ditampilkan di kasir saat kartu dipakai, agar petugas bisa mencocokkan pemegang kartu.
--  - Saldo member: uang titipan pelanggan, BUKAN penjualan. Top-up di POS masuk kas shift (tunai) atau metode
--    non-tunai; saldo dipakai lewat metode bayar bawaan "Saldo Member". Pendapatan diakui saat saldo dipakai.
--    members.balance = saldo berjalan, member_wallet_tx = buku besarnya (append-only; saldo = jumlah semua baris).

ALTER TABLE members ADD COLUMN rfid_uid VARCHAR(32);
ALTER TABLE members ADD COLUMN rfid_linked_at TIMESTAMPTZ;
CREATE UNIQUE INDEX members_rfid_uq ON members (rfid_uid) WHERE rfid_uid IS NOT NULL;

ALTER TABLE members ADD COLUMN photo_mime VARCHAR(20) CHECK (photo_mime IN ('image/jpeg', 'image/png', 'image/webp'));
ALTER TABLE members ADD COLUMN photo_updated_at TIMESTAMPTZ;

ALTER TABLE members ADD COLUMN balance NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (balance >= 0);

-- kind: topup (di POS; method = cara pelanggan membayar top-up, shift_id = laci yang menerima uangnya),
-- payment (membayar transaksi POS dengan saldo), refund (retur transaksi yang dibayar dengan saldo, kembali ke
-- saldo), adjust (koreksi Backoffice dengan alasan). amount bertanda: + menambah saldo, − mengurangi.
CREATE TABLE member_wallet_tx (
  id             BIGSERIAL      PRIMARY KEY,
  member_id      BIGINT         NOT NULL REFERENCES members(id),
  kind           VARCHAR(8)     NOT NULL CHECK (kind IN ('topup', 'payment', 'refund', 'adjust')),
  amount         NUMERIC(14,2)  NOT NULL CHECK (amount <> 0),
  balance_after  NUMERIC(14,2)  NOT NULL CHECK (balance_after >= 0),
  method         VARCHAR(20)    REFERENCES payment_methods(code),
  tendered       NUMERIC(14,2),
  change         NUMERIC(14,2)  NOT NULL DEFAULT 0 CHECK (change >= 0),
  shift_id       BIGINT         REFERENCES cashier_shifts(id),
  branch_id      BIGINT         REFERENCES branches(id),
  terminal_id    BIGINT         REFERENCES pos_terminals(id),
  sale_id        BIGINT         REFERENCES sales(id),
  return_id      BIGINT         REFERENCES sale_returns(id),
  doc_no         VARCHAR(40)    UNIQUE,
  reason         VARCHAR(300),
  client_ref     VARCHAR(64),
  created_by     BIGINT         REFERENCES users(id),
  created_at     TIMESTAMPTZ    NOT NULL DEFAULT now(),
  CHECK (kind <> 'topup' OR (amount > 0 AND method IS NOT NULL AND method <> 'member_balance' AND shift_id IS NOT NULL AND doc_no IS NOT NULL)),
  CHECK (kind <> 'payment' OR (amount < 0 AND sale_id IS NOT NULL)),
  CHECK (kind <> 'refund' OR (amount > 0 AND sale_id IS NOT NULL AND return_id IS NOT NULL)),
  CHECK (kind <> 'adjust' OR reason IS NOT NULL)
);
CREATE INDEX member_wallet_tx_member_idx ON member_wallet_tx (member_id, id DESC);
CREATE INDEX member_wallet_tx_shift_idx ON member_wallet_tx (shift_id) WHERE shift_id IS NOT NULL;
CREATE INDEX member_wallet_tx_sale_idx ON member_wallet_tx (sale_id) WHERE sale_id IS NOT NULL;
CREATE INDEX member_wallet_tx_time_idx ON member_wallet_tx (created_at, kind);
-- Kunci idempotensi top-up dari POS: request yang dikirim ulang tidak menambah saldo dua kali.
CREATE UNIQUE INDEX member_wallet_tx_client_ref_uq ON member_wallet_tx (terminal_id, client_ref) WHERE client_ref IS NOT NULL;

-- Top-up tunai menambah kas seharusnya di laci shift (snapshot saat shift ditutup, seperti kolom kas lainnya).
ALTER TABLE cashier_shifts ADD COLUMN member_topups NUMERIC(14,2) NOT NULL DEFAULT 0;

-- Metode bayar bawaan "Saldo Member": memotong saldo member yang dipasang di transaksi. Tidak bisa dihapus;
-- dinonaktifkan di Master Data = fitur saldo (top-up & bayar) tidak tampil di POS.
INSERT INTO payment_methods (code, name, sort_order)
SELECT 'member_balance',
       CASE WHEN EXISTS (SELECT 1 FROM payment_methods WHERE lower(name) = 'saldo member') THEN 'Saldo Member (bawaan)' ELSE 'Saldo Member' END,
       5
 WHERE NOT EXISTS (SELECT 1 FROM payment_methods WHERE code = 'member_balance');

INSERT INTO permissions (code, module, name) VALUES
  ('pos.member_topup', 'pos', 'Top-up saldo member di POS');
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code = 'pos.member_topup'
 WHERE r.code IN ('owner', 'admin', 'supervisor', 'cashier');
