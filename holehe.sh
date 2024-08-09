#!/bin/bash

# Menyelesaikan masalah dpkg
echo "Menyelesaikan masalah dpkg..."
dpkg --configure -a

# Memperbarui sistem dan menginstal git
echo "Memperbarui sistem dan menginstal git..."
apt update && apt upgrade -y
apt install -y python3 python3-pip git

# Meng-clone repository Holehe
echo "Meng-clone repository Holehe..."
rm -rf holehe  # Menghapus direktori lama jika ada
git clone https://github.com/megadose/holehe.git

# Menginstal Holehe secara global menggunakan pipx
echo "Menginstal Holehe menggunakan pipx..."
pipx install holehe

# Menambahkan alias untuk Holehe (Opsional)
echo "Menambahkan alias untuk Holehe..."
echo "alias holehe='$(which holehe)'" >> ~/.bashrc
source ~/.bashrc

# Menyelesaikan
echo "Instalasi Holehe selesai. Anda dapat menjalankan Holehe dengan perintah 'holehe'."
