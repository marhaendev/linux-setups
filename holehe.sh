#!/bin/bash

# Memperbaiki masalah dpkg
echo "Memperbaiki masalah dpkg..."
sudo dpkg --configure -a

# Memperbarui sistem dan menginstal git
echo "Memperbarui sistem dan menginstal git..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip git

# Meng-clone repository Holehe
echo "Meng-clone repository Holehe..."
git clone https://github.com/megadose/holehe.git

# Menginstal Holehe secara global
echo "Menginstal Holehe secara global..."
cd holehe || { echo "Direktori holehe tidak ditemukan!"; exit 1; }
pip3 install .

# Menambahkan alias untuk Holehe
echo "Menambahkan alias untuk Holehe..."
echo "alias holehe='$(which holehe)'" >> ~/.bashrc
source ~/.bashrc

# Menyelesaikan
echo "Instalasi Holehe selesai. Anda dapat menjalankan Holehe dengan perintah 'holehe'."
