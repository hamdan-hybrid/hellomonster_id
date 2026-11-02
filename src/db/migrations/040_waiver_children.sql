-- Satu waiver untuk banyak anak (src/services/waivers.js): orang tua mengisi sekali; anak-anaknya (nama & tanggal lahir)
-- di waiver_children. Kasir memilih anak yang bermain hari itu; nama mereka disimpan di transaksi (sales.guest_name)
-- untuk struk & laporan, tetap sama walau waiver diubah kemudian. Waiver lama: nama & tanggal lahirnya menjadi anak ke-1.
CREATE TABLE waiver_children (
  id          BIGSERIAL     PRIMARY KEY,
  waiver_id   BIGINT        NOT NULL REFERENCES waivers(id),
  position    SMALLINT      NOT NULL CHECK (position BETWEEN 1 AND 10),
  full_name   VARCHAR(120)  NOT NULL,
  birth_date  DATE          NOT NULL,
  UNIQUE (waiver_id, position)
);
INSERT INTO waiver_children (waiver_id, position, full_name, birth_date) SELECT id, 1, full_name, birth_date FROM waivers;
ALTER TABLE waivers DROP COLUMN full_name, DROP COLUMN birth_date;

ALTER TABLE sales ADD COLUMN guest_name VARCHAR(400);
UPDATE sales s SET guest_name = (SELECT string_agg(c.full_name, ', ' ORDER BY c.position) FROM waiver_children c WHERE c.waiver_id = s.waiver_id)
 WHERE s.waiver_id IS NOT NULL;
