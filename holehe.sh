#!/bin/bash

# Memperbaiki masalah dpkg
echo "Memperbaiki masalah dpkg..."
sudo dpkg --configure -a

# Memperbarui sistem dan menginstal git
echo "Memperbarui sistem dan menginstal git..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv git

# Meng-clone repository Holehe
echo "Meng-clone repository Holehe..."
rm -rf holehe  # Menghapus direktori lama jika ada
git clone https://github.com/megadose/holehe.git

# Membuat dan mengaktifkan virtual environment
echo "Membuat dan mengaktifkan virtual environment..."
cd holehe || { echo "Direktori holehe tidak ditemukan!"; exit 1; }
python3 -m venv holehe-env
source holehe-env/bin/activate

# Menginstal Holehe
echo "Menginstal Holehe..."
pip install .

# Menambahkan alias untuk Holehe (Opsional)
echo "Menambahkan alias untuk Holehe..."
echo "alias holehe='~/holehe/holehe-env/bin/holehe'" >> ~/.bashrc
source ~/.bashrc

# Menyelesaikan
echo "Instalasi Holehe selesai. Anda dapat menjalankan Holehe dengan perintah 'holehe'."
