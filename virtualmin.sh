#!/bin/bash

# Skrip untuk menginstal Virtualmin pada Debian/Ubuntu

set -e

echo "Memperbarui dan meng-upgrade sistem..."
apt update -y && apt upgrade -y

echo "Menginstal dependensi dasar..."
apt install -y wget curl gnupg python3-venv

echo "Menambahkan repositori Virtualmin..."
wget -O - https://software.virtualmin.com/gpl/scripts/install.sh | bash

echo "Instalasi Virtualmin selesai. Mohon ikuti petunjuk di layar untuk menyelesaikan konfigurasi."

echo "Periksa status Virtualmin dengan menggunakan perintah berikut setelah instalasi selesai:"
echo "systemctl status webmin"

echo "Akses Virtualmin di: https://<IP_SERVER_AKSES>:10000"

echo "Instalasi Virtualmin selesai!"
