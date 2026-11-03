# DOMPET USAHA — Playground

Versi 2.1.1 (build `b3e8e04`).

## Cara instal

Butuh server **Ubuntu 22.04 atau 24.04** yang terhubung ke internet, dan akun biasa yang punya `sudo` (bukan `root`).

1. Ambil aplikasinya:
   ```bash
   sudo apt install -y git
   git clone https://github.com/hamdan-hybrid/hellomonster_id.git ~/dompet-usaha-playground
   cd ~/dompet-usaha-playground
   ```
   Kalau memakai paket `.tar.gz`, ganti perintah di atas dengan `tar -xzf dompet-usaha-playground-2.1.1.tar.gz -C ~` lalu `cd ~/dompet-usaha-playground`.

2. Jalankan pemasang:
   ```bash
   ./setup.sh --domain playground.dompetusaha.com
   ```
   Tanpa domain, cukup `./setup.sh`. Dengan `--domain`, siapkan token Cloudflare Tunnel untuk ditempel saat diminta.

   Saat ditanya port aplikasi dan port database, tekan Enter untuk memakai port bawaan (`3009` dan `5432`). Kalau port sudah dipakai, ketik port yang disarankan.

3. Buka alamat Backoffice yang tampil di akhir setup. Masuk dengan **`owner`** / **`owner123`**, lalu ganti password sesuai permintaan.

Panduan lengkap ada di [INSTALL.md](INSTALL.md).
