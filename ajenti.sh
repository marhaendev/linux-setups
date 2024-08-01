#!/bin/bash

# Update dan upgrade sistem
echo "Memperbarui dan meng-upgrade sistem..."
apt update && apt upgrade -y

# Instal dependensi dasar
echo "Menginstal dependensi dasar..."
apt install -y software-properties-common wget curl

# Tambahkan repository Ajenti
echo "Menambahkan repository Ajenti..."
wget -qO - https://ajenti.org/debian/key.asc | apt-key add -
echo "deb http://deb.ajenti.org/debian main main" | tee /etc/apt/sources.list.d/ajenti.list

# Update daftar paket
echo "Mengupdate daftar paket..."
apt update

# Instal Ajenti
echo "Menginstal Ajenti..."
apt install -y ajenti

# Mulai dan aktifkan layanan Ajenti
echo "Memulai layanan Ajenti..."
systemctl enable ajenti
systemctl start ajenti

# Konfirmasi instalasi
echo "Ajenti telah diinstal dan dijalankan. Akses Ajenti di https://<YOUR_SERVER_IP>:8000"
