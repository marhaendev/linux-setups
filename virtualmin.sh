#!/bin/bash

# Memastikan skrip dijalankan dengan hak akses root
if [ "$(id -u)" -ne "0" ]; then
  echo "Skrip ini harus dijalankan sebagai root" 1>&2
  exit 1
fi

# Mengatur hostname
HOSTNAME="hosting.computingforgeeks.com"
echo "Mengatur hostname menjadi $HOSTNAME..."
hostnamectl set-hostname $HOSTNAME

# Memperbarui dan meng-upgrade sistem
echo "Memperbarui dan meng-upgrade sistem..."
apt update -y && apt upgrade -y

# URL CDN untuk skrip instalasi
CDN_URL="https://cdn.example.com/scripts/install_virtualmin.sh"

# Mengunduh dan menjalankan skrip instalasi dari CDN
echo "Mengunduh skrip instalasi Virtualmin dari CDN..."
wget -O /tmp/install.sh $CDN_URL

echo "Menjalankan skrip instalasi Virtualmin..."
chmod +x /tmp/install.sh
/tmp/install.sh

# Mengatur firewall
echo "Mengatur firewall untuk mengizinkan akses ke Virtualmin..."
ufw allow 10000/tcp

# Menyelesaikan instalasi
echo "Instalasi Virtualmin selesai!"
echo "Anda dapat mengakses Virtualmin di URL berikut: https://<IP_SERVER>:10000"
