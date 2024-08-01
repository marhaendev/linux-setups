#!/bin/bash

# Hapus konten file sources.list
echo "Menghapus konten file /etc/apt/sources.list..."
> /etc/apt/sources.list

# Tambahkan repositori baru
echo "Menambahkan repositori baru ke /etc/apt/sources.list..."
cat <<EOL > /etc/apt/sources.list
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware

deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
EOL

# Update daftar paket
echo "Mengupdate daftar paket..."
apt update

echo "Repositori telah diperbarui dan daftar paket telah diupdate."
