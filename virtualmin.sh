#!/bin/bash

# Memastikan skrip dijalankan dengan hak akses root
if [ "$(id -u)" -ne "0" ]; then
  echo "Skrip ini harus dijalankan sebagai root" 1>&2
  exit 1
fi

echo "Menambahkan kunci GPG Virtualmin..."
wget -O- https://software.virtualmin.com/gpl/scripts/virtualmin-key.asc | gpg --dearmor -o /usr/share/keyrings/virtualmin-archive-keyring.gpg

echo "Menambahkan repositori Virtualmin..."
echo "deb [signed-by=/usr/share/keyrings/virtualmin-archive-keyring.gpg] http://software.virtualmin.com/gpl/debian/ virtualmin-universal main" | tee /etc/apt/sources.list.d/virtualmin.list

echo "Memperbarui daftar paket..."
apt update

echo "Menginstal Webmin dan Virtualmin..."
apt install -y webmin virtualmin

echo "Mengonfigurasi firewall..."
ufw allow 10000/tcp

echo "Instalasi Virtualmin selesai!"
echo "Anda dapat mengakses Virtualmin di URL berikut: https://<IP_SERVER>:10000"

echo "Skrip selesai!"
