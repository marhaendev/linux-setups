#!/bin/bash

# Memastikan skrip dijalankan sebagai root
if [ "$(id -u)" -ne "0" ]; then
    echo "Skrip ini harus dijalankan sebagai root." 1>&2
    exit 1
fi

# Tanyakan domain dan IP kepada pengguna
read -p "Masukkan domain yang ingin dibuat (contoh: smkmultazam.com): " DOMAIN
read -p "Masukkan IP server untuk domain tersebut (contoh: 192.168.1.10): " IP

# Update dan instal paket
apt update
apt install -y bind9 bind9utils bind9-doc

# Buat direktori zona jika belum ada
mkdir -p /etc/bind/zones

# Konfigurasi file named.conf.local
echo "zone \"$DOMAIN\" {" > /etc/bind/named.conf.local
echo "    type master;" >> /etc/bind/named.conf.local
echo "    file \"/etc/bind/zones/db.$DOMAIN\";" >> /etc/bind/named.conf.local
echo "};" >> /etc/bind/named.conf.local

# Buat file zona untuk domain yang diberikan
cat <<EOL > /etc/bind/zones/db.$DOMAIN
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                      1         ; Serial
                 604800         ; Refresh
                  86400         ; Retry
                2419200         ; Expire
                 604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN.
@       IN      A       $IP
ns1     IN      A       $IP
EOL

# Konfigurasi reverse DNS (opsional)
REVERSE_IP=$(echo $IP | awk -F. '{print $3"."$2"."$1}')
cat <<EOL > /etc/bind/zones/db.$REVERSE_IP
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                      1         ; Serial
                 604800         ; Refresh
                  86400         ; Retry
                2419200         ; Expire
                 604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN.
$(echo $IP | awk -F. '{print $4}')      IN      PTR     $DOMAIN.
EOL

# Restart BIND9 untuk menerapkan perubahan
systemctl restart bind9

# Verifikasi konfigurasi
echo "Verifikasi konfigurasi DNS:"
dig @$IP $DOMAIN
