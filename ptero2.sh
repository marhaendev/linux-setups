#!/bin/bash
set -e

# Fungsi: cek dan instal dependensi dasar
check_dependencies() {
    for cmd in curl netstat awk sed mysql nginx php ufw; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "❌ Perintah $cmd tidak ditemukan. Menginstall dependensi dasar..."
            apt-get update -y && apt-get install -y curl net-tools gawk sed mariadb-client nginx php8.2-cli ufw
        fi
    done
}

# Fungsi: cek IP publik VPS
get_ip() {
    curl -s http://ipinfo.io/ip 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1"
}

# Fungsi: cek port yang digunakan (hilangkan duplikat)
check_ports() {
    echo "Memeriksa port yang sedang digunakan..."
    if command -v ss >/dev/null 2>&1; then
        ss -tulpn 2>/dev/null | awk '{print $5, $1}' | sed 's/.*://' | sort -u | awk '
        {
            port=$1;
            if(port~/^[0-9]+$/) {
                service=$2;
                if (port==21) name="ftp";
                else if (port==22) name="ssh";
                else if (port==80) name="http";
                else if (port==443) name="https";
                else name=service;
                printf "%-5s : %s\n", port, name;
            }
        }'
    else
        netstat -tulpn 2>/dev/null | awk '/^tcp/ {print $4, $1}' | sed 's/.*://' | sort -u | awk '
        {
            port=$1;
            if(port~/^[0-9]+$/) {
                service=$2;
                if (port==21) name="ftp";
                else if (port==22) name="ssh";
                else if (port==80) name="http";
                else if (port==443) name="https";
                else name=service;
                printf "%-5s : %s\n", port, name;
            }
        }'
    fi
}

# Fungsi: minta port dari user
get_port() {
    while true; do
        read -rp "Masukkan port untuk Pterodactyl (1024–65535): " PORT
        if [[ -z "$PORT" ]]; then
            echo "❌ Port tidak boleh kosong."
            continue
        fi
        if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then
            echo "❌ Port harus angka antara 1024–65535."
            continue
        fi
        if command -v ss >/dev/null 2>&1; then
            if ss -tulpn 2>/dev/null | grep -q ":$PORT\b"; then
                echo "❌ Port $PORT sudah digunakan."
                continue
            fi
        else
            if netstat -tulpn 2>/dev/null | grep -q ":$PORT\b"; then
                echo "❌ Port $PORT sudah digunakan."
                continue
            fi
        fi
        echo "✅ Port $PORT tersedia."
        break
    done
}

# Fungsi: uninstall bersih
uninstall_ptero() {
    echo "=== UNINSTALL BERSIH ==="
    echo "PERINGATAN: Ini akan menghapus Nginx, MariaDB, Redis, PHP, dan file Pterodactyl."
    read -rp "Lanjutkan? (y/N): " ans
    [[ "$ans" != "y" && "$ans" != "Y" ]] && { echo "Dibatalkan."; exit 0; }
    systemctl stop nginx php*-fpm mariadb redis-server pteroq.service 2>/dev/null || true
    apt purge -y nginx* mariadb-* mysql-* redis-server php* composer nodejs npm certbot 2>/dev/null || true
    apt autoremove -y --purge
    apt clean
    rm -rf /var/www/pterodactyl /etc/nginx/sites-{available,enabled}/pterodactyl.conf \
           /etc/mysql /var/lib/mysql /var/lib/redis /etc/redis
    echo "=== UNINSTALL SELESAI ==="
}

# Fungsi: install Pterodactyl
install_ptero() {
    local recaptcha="$1"
    check_dependencies
    IP=$(get_ip)
    check_ports
    get_port
    DB_NAME="panel"
    DB_USER="pterouser"
    DB_PASS=$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9')
    ADMIN_EMAIL="admin@example.com"
    ADMIN_USER="admin"
    ADMIN_FNAME="Panel"
    ADMIN_LNAME="Admin"
    ADMIN_PASS=$(openssl rand -base64 10 | tr -dc 'A-Za-z0-9!@#$%^&*()_+')
    TZ="Asia/Jakarta"
    APP_URL="http://${IP}:${PORT}"
    export DEBIAN_FRONTEND=noninteractive
    timedatectl set-timezone "$TZ" 2>/dev/null || true
    apt-get update -y
    apt-get install -y software-properties-common curl ca-certificates gnupg unzip tar
    add-apt-repository -y ppa:ondrej/php 2>/dev/null || true
    apt-get update -y
    apt-get install -y nginx php8.2 php8.2-fpm php8.2-cli php8.2-gd php8.2-mysql \
                      php8.2-mbstring php8.2-bcmath php8.2-xml php8.2-curl php8.2-zip \
                      redis-server mariadb-server mariadb-client
    systemctl enable --now nginx php8.2-fpm redis-server mariadb
    mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl
    curl -sSL -o panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzf panel.tar.gz && rm -f panel.tar.gz
    KEY=$(openssl rand -base64 32 | tr -d '\n')
    cat > .env <<ENV
APP_ENV=production
APP_KEY=base64:${KEY}
APP_URL=${APP_URL}
APP_TIMEZONE=${TZ}
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379
ENV
    if [[ "$recaptcha" == "no" ]]; then
        echo "RECAPTCHA_ENABLED=false" >> .env
    fi
    curl -sS https://getcomposer.org/installer | php
    export COMPOSER_ALLOW_SUPERUSER=1
    php composer.phar install --no-dev --optimize-autoloader
    php artisan optimize:clear
    php artisan migrate --seed --force
    chown -R www-data:www-data /var/www/pterodactyl
    chmod -R 775 storage bootstrap/cache
    php artisan storage:link || true
    cat >/etc/nginx/sites-available/pterodactyl.conf <<NGINX
server {
    listen ${PORT};
    server_name _;
    root /var/www/pterodactyl/public;
    index index.php index.html;
    charset utf-8;
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_index index.php;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
    }
    location ~ /\.ht {
        deny all;
    }
}
NGINX
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
    nginx -t
    systemctl restart nginx
    # Buka port di firewall
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ${PORT} >/dev/null 2>&1
        echo "✅ Port ${PORT} telah dibuka di firewall."
    else
        echo "⚠️ UFW tidak terdeteksi, pastikan port ${PORT} terbuka secara manual jika menggunakan firewall lain."
    fi
    ( crontab -l 2>/dev/null | grep -v 'pterodactyl/artisan' ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1" ) | crontab -
    cat >/etc/systemd/system/pteroq.service <<SERVICE
[Unit]
Description=Pterodactyl Queue Worker
After=redis.service
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
SERVICE
    systemctl daemon-reload
    systemctl enable --now pteroq.service
    sudo -u www-data php artisan p:user:make \
        --email="$ADMIN_EMAIL" \
        --username="$ADMIN_USER" \
        --name-first="$ADMIN_FNAME" \
        --name-last="$ADMIN_LNAME" \
        --password="$ADMIN_PASS" \
        --admin=1 \
        --no-interaction
    # Verifikasi layanan
    systemctl restart nginx php8.2-fpm redis mariadb pteroq.service
    echo "=== VERIFIKASI LAYANAN ==="
    systemctl status nginx --no-pager
    systemctl status php8.2-fpm --no-pager
    systemctl status redis --no-pager
    systemctl status mariadb --no-pager
    systemctl status pteroq.service --no-pager
    echo "=== INSTALLASI SELESAI ==="
    echo "Akses Panel: ${APP_URL}"
    echo "Email Admin: ${ADMIN_EMAIL}"
    echo "Username: ${ADMIN_USER}"
    echo "Password: ${ADMIN_PASS}"
    echo "Catatan: Port ${PORT} telah dibuka. Jika website tidak dapat diakses, periksa firewall cloud provider (misalnya, AWS, GCP) untuk memastikan port ${PORT} diizinkan."
}

# Fungsi: buat pengguna baru dengan username sama dengan password
create_user() {
    check_dependencies
    cd /var/www/pterodactyl
    ADMIN_PASS=$(openssl rand -base64 10 | tr -dc 'A-Za-z0-9!@#$%^&*()_+')
    ADMIN_USER="$ADMIN_PASS"
    ADMIN_EMAIL="admin@$ADMIN_PASS.com"
    ADMIN_FNAME="Panel"
    ADMIN_LNAME="Admin"
    sudo -u www-data php artisan p:user:make \
        --email="$ADMIN_EMAIL" \
        --username="$ADMIN_USER" \
        --name-first="$ADMIN_FNAME" \
        --name-last="$ADMIN_LNAME" \
        --password="$ADMIN_PASS" \
        --admin=1 \
        --no-interaction
    echo "=== PENGGUNA BARU DIBUAT ==="
    echo "Email: ${ADMIN_EMAIL}"
    echo "Username: ${ADMIN_USER}"
    echo "Password: ${ADMIN_PASS}"
}

# Fungsi: lihat semua pengguna
list_users() {
    check_dependencies
    mysql -u root -e "USE panel; SELECT username, email, password FROM users;" 2>/dev/null || {
        echo "❌ Gagal mengakses database. Pastikan MariaDB berjalan dan database 'panel' ada."
        exit 1
    }
}

# Fungsi: hapus pengguna tertentu
delete_user() {
    check_dependencies
    echo "Masukkan email atau username pengguna yang ingin dihapus:"
    read -rp "Email/Username: " identifier
    if [[ -z "$identifier" ]]; then
        echo "❌ Email atau username tidak boleh kosong."
        exit 1
    fi
    mysql -u root -e "USE panel; DELETE FROM users WHERE email='$identifier' OR username='$identifier';" 2>/dev/null || {
        echo "❌ Gagal menghapus pengguna. Pastikan MariaDB berjalan dan pengguna ada."
        exit 1
    }
    echo "✅ Pengguna dengan email/username '$identifier' telah dihapus."
}

# Menu pilihan
echo "=== Pterodactyl Panel Installer ==="
echo "0) Batal / Cancel"
echo "1) Uninstall bersih / Clean uninstall"
echo "2) Install dengan reCAPTCHA"
echo "3) Install tanpa reCAPTCHA"
echo "4) Buat pengguna baru (username = password, email = admin@password.com)"
echo "5) Lihat semua pengguna"
echo "6) Hapus pengguna tertentu"
echo "12) Uninstall lalu install dengan reCAPTCHA"
echo "13) Uninstall lalu install tanpa reCAPTCHA"
read -rp "Pilih opsi [0-6,12-13]: " choice

case "$choice" in
    0) echo "Dibatalkan."; exit 0 ;;
    1) uninstall_ptero ;;
    2) install_ptero "yes" ;;
    3) install_ptero "no" ;;
    4) create_user ;;
    5) list_users ;;
    6) delete_user ;;
    12) uninstall_ptero && install_ptero "yes" ;;
    13) uninstall_ptero && install_ptero "no" ;;
    *) echo "Pilihan tidak valid."; exit 1 ;;
esac
