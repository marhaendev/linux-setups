#!/bin/bash

# Update dan upgrade sistem
echo "Memperbarui dan meng-upgrade sistem..."
apt update && apt upgrade -y

# Instal dependensi dasar
echo "Menginstal dependensi dasar..."
apt install -y git python3-venv python3-pip

# Clone repositori Ajenti
echo "Meng-clone repositori Ajenti..."
git clone https://github.com/ajenti/ajenti.git

# Masuk ke direktori Ajenti
cd ajenti

# Buat dan aktifkan virtual environment
echo "Membuat dan mengaktifkan virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Instal dependensi Python
echo "Menginstal dependensi Python..."
pip install -r requirements.txt

# Jalankan Ajenti
echo "Menjalankan Ajenti..."
python3 ajenti-panel.py &

# Konfirmasi instalasi
echo "Ajenti telah dijalankan. Akses Ajenti di https://$(hostname -I | awk '{print $1}'):8000"
