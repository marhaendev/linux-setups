#!/bin/bash

# Memperbarui sistem dan menginstal dependensi
echo "Memperbarui sistem dan menginstal dependensi..."
apt update && apt upgrade -y
apt install -y python3 python3-pip git

# Meng-clone repository Holehe
echo "Meng-clone repository Holehe..."
git clone https://github.com/megadose/holehe.git

# Membuat dan mengaktifkan virtual environment
echo "Membuat dan mengaktifkan virtual environment..."
cd holehe || { echo "Direktori holehe tidak ditemukan!"; exit 1; }
python3 -m venv holehe-env
source holehe-env/bin/activate

# Menginstal Holehe
echo "Menginstal Holehe..."
pip install .

# Menambahkan alias untuk Holehe
echo "Menambahkan alias untuk Holehe..."
echo "alias holehe='$(pwd)/holehe-env/bin/holehe'" >> ~/.bashrc
source ~/.bashrc

# Menyelesaikan
echo "Instalasi Holehe selesai. Anda dapat menjalankan Holehe dengan perintah 'holehe'."
