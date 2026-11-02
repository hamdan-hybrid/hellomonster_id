-- Waiver pengunjung umum (src/services/waivers.js): diisi sendiri secara online di /waiver — email, nama lengkap, HP
-- (format internasional), tanggal lahir, negara, kota, alamat, persetujuan — lalu pengunjung menunjukkan QR-nya
-- (DUWAIVER:<code>) di kasir lewat tombol Umum. Kasir memindai QR atau memilih dari antrian hari ini; struk hanya
-- mencetak namanya. branch_id: cabang dari tautan QR kasir (?b=<kode cabang>), kosong = semua cabang.
CREATE TABLE waivers (
  id          BIGSERIAL     PRIMARY KEY,
  code        VARCHAR(12)   NOT NULL UNIQUE,
  email       VARCHAR(254)  NOT NULL,
  full_name   VARCHAR(120)  NOT NULL,
  phone       VARCHAR(20)   NOT NULL,
  birth_date  DATE          NOT NULL,
  country     CHAR(2)       NOT NULL,
  city        VARCHAR(120)  NOT NULL,
  address     VARCHAR(500)  NOT NULL,
  branch_id   BIGINT        REFERENCES branches(id),
  lang        VARCHAR(5),
  agreed_at   TIMESTAMPTZ   NOT NULL,
  submit_day  DATE          NOT NULL,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX waivers_day_idx ON waivers (submit_day, branch_id);

-- Transaksi pengunjung umum: waiver yang dipakai (nama di struk). Waiver yang sudah dipakai keluar dari antrian.
ALTER TABLE sales ADD COLUMN waiver_id BIGINT REFERENCES waivers(id);
CREATE INDEX sales_waiver_idx ON sales (waiver_id) WHERE waiver_id IS NOT NULL;
