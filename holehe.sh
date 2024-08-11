#!/bin/bash

# Memperbaiki masalah dpkg (jika ada)
echo "Memperbaiki masalah dpkg..."
dpkg --configure -a

# Memperbarui sistem dan menginstal dependensi
echo "Memperbarui sistem dan menginstal dependensi..."
apt update && apt upgrade -y
apt install -y python3 python3-pip python3-venv git

# Meng-clone repository Holehe
echo "Meng-clone repository Holehe..."
rm -rf holehe  # Menghapus direktori lama jika ada
git clone https://github.com/megadose/holehe.git

# Menginstal Holehe
#echo "Menginstal Holehe..."
#pip install .

# Menambahkan alias untuk Holehe (Opsional)
#echo "Menambahkan alias untuk Holehe..."
#echo "alias holehe='~/holehe/holehe-env/bin/holehe'" >> ~/.bashrc
#source ~/.bashrc

# Membuat dan mengaktifkan virtual environment
#echo "Membuat dan mengaktifkan virtual environment..."
cd holehe || { echo "Direktori holehe tidak ditemukan!"; exit 1; }
# python3 -m venv holehe-env

# Menyelesaikan
echo "Instalasi Holehe selesai. Anda dapat menjalankan Holehe dengan perintah:"
echo "> cd holehe"
echo "> source holehe-env/bin/activate"
echo "> holehe -h"
