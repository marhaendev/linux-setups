#!/bin/bash

# Skrip ini dirancang untuk menginstal Webmin/Virtualmin atau DirectAdmin di Debian 12

set -e

# Memperbarui sistem
echo "Memperbarui sistem..."
apt update -y
apt upgrade -y

# Memastikan bahwa skrip dijalankan sebagai root
if [ "$(id -u)" -ne "0" ]; then
  echo "Skrip ini harus dijalankan sebagai root."
  exit 1
fi

# Memeriksa apakah wget dan curl sudah terpasang, jika tidak, pasang mereka
echo "Memeriksa dan menginstal wget dan curl..."
apt install -y wget curl

# Menawarkan pilihan instalasi
echo "Pilih opsi instalasi:"
echo "1) Instal Webmin / Virtualmin"
echo "2) Instal DirectAdmin"
read -p "Masukkan pilihan (1 atau 2): " choice

case $choice in
  1)
    # Instal Webmin / Virtualmin
    echo "Menginstal Webmin / Virtualmin..."

    # Unduh skrip instalasi Virtualmin
    wget http://software.virtualmin.com/gpl/scripts/install.sh -O /tmp/install.sh

    # Beri izin eksekusi pada skrip
    chmod a+x /tmp/install.sh

    # Jalankan skrip instalasi
    echo "Menjalankan skrip instalasi Virtualmin..."
    /tmp/install.sh

    # Izinkan lalu lintas melalui firewall
    echo "Mengizinkan lalu lintas melalui firewall pada port 10000..."
    ufw allow 10000/tcp

    echo "Instalasi Webmin / Virtualmin selesai. Akses di https://<domain_name>:10000"
    ;;

  2)
    # Instal DirectAdmin
    echo "Menginstal DirectAdmin..."

    # Unduh dan jalankan skrip instalasi DirectAdmin
    read -p "Masukkan kunci lisensi DirectAdmin Anda: " license_key
    curl -fsSL https://download.directadmin.com/setup.sh | bash -s "$license_key"

    # Izinkan lalu lintas melalui firewall
    echo "Mengizinkan lalu lintas melalui firewall pada port 2222..."
    ufw allow 2222/tcp

    echo "Instalasi DirectAdmin selesai. Akses di http://<domain_name>:2222"
    ;;

  *)
    echo "Pilihan tidak valid. Harap pilih 1 atau 2."
    exit 1
    ;;
esac
