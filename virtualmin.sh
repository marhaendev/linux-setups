#!/bin/bash

# Skrip untuk menginstal Virtualmin pada Debian/Ubuntu

set -e

echo "Memperbarui dan meng-upgrade sistem..."
apt update -y && apt upgrade -y

echo "Menginstal dependensi dasar..."
apt install -y wget curl gnupg

echo "Menambahkan repositori Virtualmin..."
wget -O- https://software.virtualmin.com/gpl/scripts/install.sh | sudo bash

echo "Memulai instalasi Virtualmin..."
# Skrip instalasi Virtualmin akan dijalankan di sini
# Anda akan diminta untuk mengikuti beberapa langkah konfigurasi

echo "Instalasi Virtualmin selesai. Mohon ikuti petunjuk di layar untuk menyelesaikan konfigurasi."

echo "Periksa status Virtualmin dengan menggunakan perintah berikut setelah instalasi selesai:"
echo "sudo systemctl status webmin"

echo "Akses Virtualmin di: https://<IP_SERVER_AKSES>:10000"

echo "Instalasi Virtualmin selesai!"
