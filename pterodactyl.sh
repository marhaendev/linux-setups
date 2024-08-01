#!/bin/bash

# Memastikan skrip dijalankan dengan hak akses root
if [[ $(id -u) -ne 0 ]]; then
    echo "Harap jalankan skrip ini sebagai root atau dengan sudo."
    exit 1
fi

# Memperbarui sistem
echo "Memperbarui sistem..."
apt update && apt upgrade -y

# Menginstal dependencies dasar
echo "Menginstal dependencies dasar..."
apt install -y curl unzip sudo gnupg lsb-release nginx mariadb-server mariadb-client \
    php php-cli php-fpm php-mysql php-pgsql php-xml php-mbstring php-curl php-zip php-gd

# Mengatur hostname
echo "Mengatur hostname..."
hostnamectl set-hostname hosting.computingforgeeks.com

# Menginstal Pterodactyl Panel
echo "Mengunduh dan menginstal Pterodactyl Panel..."
cd /var/www
curl -Lo panel.zip https://github.com/pterodactyl/panel/releases/download/v1.10.1/panel.zip
unzip panel.zip
mv panel pterodactyl
cd pterodactyl

# Menginstal Composer dan dependensi PHP
echo "Menginstal Composer dan dependensi PHP..."
apt install -y composer
composer install --no-dev --optimize-autoloader

# Mengatur izin folder
echo "Mengatur izin folder..."
chown -R www-data:www-data /var/www/pterodactyl
chmod -R 755 /var/www/pterodactyl

# Mengonfigurasi Pterodactyl
echo "Mengonfigurasi Pterodactyl..."
cp .env.example .env
php artisan key:generate

# Mengatur database
echo "Mengatur database..."
mysql -u root -p <<MYSQL_SCRIPT
CREATE DATABASE pterodactyl;
CREATE USER 'pterodactyl'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON pterodactyl.* TO 'pterodactyl'@'localhost';
FLUSH PRIVILEGES;
EXIT;
MYSQL_SCRIPT

# Melakukan migrasi database
echo "Melakukan migrasi database..."
php artisan migrate --seed

# Mengatur Nginx
echo "Mengatur Nginx..."
cat > /etc/nginx/sites-available/pterodactyl <<EOF
server {
    listen 80;
    server_name yourdomain.com;
    root /var/www/pterodactyl/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Mengaktifkan konfigurasi dan me-restart Nginx
ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx

# Menginstal Wings Daemon
echo "Menginstal Wings Daemon..."
mkdir -p /etc/pterodactyl
cd /etc/pterodactyl
curl -Lo wings.tar.gz https://github.com/pterodactyl/wings/releases/download/v1.6.1/wings-linux-amd64.tar.gz
tar xzf wings.tar.gz

# Mengonfigurasi Wings Daemon
echo "Mengonfigurasi Wings Daemon..."
cp wings/config.yml.example wings/config.yml
# Edit file wings/config.yml sesuai kebutuhan

# Menjalankan Wings Daemon
echo "Menjalankan Wings Daemon..."
./wings -d

echo "Instalasi selesai! Akses Pterodactyl Panel di http://yourdomain.com"
