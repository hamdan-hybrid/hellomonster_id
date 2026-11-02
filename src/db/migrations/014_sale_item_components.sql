-- Isi paket pada saat terjual (salinan) untuk struk: [{ "name", "qty" (per paket, satuan dasar isi), "unit" }].
-- NULL untuk barang biasa. Disalin saat transaksi agar struk lama tidak ikut berubah bila isi paket diubah kemudian.
ALTER TABLE sale_items ADD COLUMN components JSONB;

-- Transaksi paket sebelum kolom ini ada: isinya diambil dari definisi paket saat migrasi.
UPDATE sale_items si
   SET components = (
     SELECT jsonb_agg(jsonb_build_object('name', cp.name, 'qty', bi.qty::text, 'unit', cu.code) ORDER BY cp.name)
       FROM bundle_items bi
       JOIN products cp ON cp.id = bi.product_id
       JOIN units cu ON cu.id = cp.unit_id
      WHERE bi.bundle_id = si.product_id)
 WHERE si.product_id IN (SELECT id FROM products WHERE is_bundle);
