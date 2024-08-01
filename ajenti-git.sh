#!/bin/bash

# Update dan upgrade sistem
echo "Memperbarui dan meng-upgrade sistem..."
apt update && apt upgrade -y

# Instal dependensi dasar
echo "Menginstal dependensi dasar..."
apt install -y git python3-venv python3-pip

# Hapus direktori ajenti jika sudah ada
if [ -d "ajenti" ]; then
  echo "Direktori 'ajenti' sudah ada. Menghapus direktori lama..."
  rm -rf ajenti
fi

# Clone repositori Ajenti
echo "Meng-clone repositori Ajenti..."
git clone https://github.com/ajenti/ajenti.git

# Masuk ke direktori Ajenti
cd ajenti || exit

# Buat dan aktifkan virtual environment
echo "Membuat dan mengaktifkan virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Instal dependensi Python dari requirements-rtd.txt
echo "Menginstal dependensi Python dari requirements-rtd.txt..."
pip install -r requirements-rtd.txt

# Jalankan Ajenti
echo "Menjalankan Ajenti..."
python3 ajenti-panel/ajenti-panel.py &

# Konfirmasi instalasi
echo "Ajenti telah dijalankan. Akses Ajenti di https://$(hostname -I | awk '{print $1}'):8000"
