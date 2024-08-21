#!/bin/bash

# Update dan upgrade sistem
echo "Memperbarui dan meng-upgrade sistem..."
apt update && apt upgrade -y

# Instal dependensi dasar
echo "Menginstal dependensi dasar..."
apt install -y git python3-venv python3-pip

# Clone repositori Ajenti
echo "Meng-clone repositori Ajenti..."
git clone https://github.com/ajenti/ajenti.git /opt/ajenti

# Masuk ke direktori Ajenti
cd /opt/ajenti

# Buat dan aktifkan virtual environment
echo "Membuat dan mengaktifkan virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Instal dependensi Python
echo "Menginstal dependensi Python..."
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
else
    echo "Error: requirements.txt tidak ditemukan. Mengunduh requirements secara manual..."
    pip install ajenti-panel
fi

# Jalankan Ajenti
echo "Menjalankan Ajenti..."
if [ -f ajenti-panel.py ]; then
    python3 ajenti-panel.py &
else
    echo "Error: ajenti-panel.py tidak ditemukan. Memastikan instalasi Ajenti..."
    pip install ajenti-panel
    ajenti-panel &
fi

# Konfirmasi instalasi
echo "Ajenti telah dijalankan. Akses Ajenti di https://$(hostname -I | awk '{print $1}'):8000"
