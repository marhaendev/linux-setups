#!/bin/bash

# Memastikan skrip dijalankan sebagai root
if [ "$(id -u)" -ne "0" ]; then
  echo "Skrip ini harus dijalankan sebagai root" 1>&2
  exit 1
fi

echo "Memperbarui dan meng-upgrade sistem..."
apt update -y && apt upgrade -y

echo "Menginstal dependensi dasar..."
apt install -y wget curl gnupg

echo "Menambahkan kunci GPG Virtualmin..."
wget -O- https://software.virtualmin.com/gpl/scripts/virtualmin-key.asc | apt-key add -

echo "Menambahkan repositori Virtualmin..."
echo "deb http://software.virtualmin.com/gpl/debian/ virtualmin-universal main" | tee /etc/apt/sources.list.d/virtualmin.list

echo "Memperbarui daftar paket..."
apt update -y

echo "Menginstal Virtualmin..."
apt install -y webmin virtualmin

echo "Instalasi Virtualmin selesai. Anda dapat mengakses Virtualmin di URL berikut: https://<IP_SERVER>:10000"

echo "Skrip selesai!"
