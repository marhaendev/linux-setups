#!/bin/bash
set -e
# Warna untuk output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fungsi: cek dan instal dependensi dasar
check_dependencies() {
    for cmd in curl netstat awk sed mysql nginx php ufw redis-cli docker; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${RED}❌ Perintah $cmd tidak ditemukan. Menginstall dependensi dasar...${NC}"
            apt-get update -y && apt-get install -y curl net-tools gawk sed mariadb-client nginx php8.2-cli ufw redis-tools docker.io
            systemctl enable --now docker
        fi
    done
}

# Fungsi: cek IP publik VPS
get_ip() {
    curl -s http://ipinfo.io/ip 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1"
}

# Fungsi: cek port yang digunakan (hilangkan duplikat)
check_ports() {
    echo -e "${ORANGE}Memeriksa port yang sedang digunakan...${NC}"
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

# Fungsi: minta port untuk panel
get_port() {
    while true; do
        read -rp "Masukkan port untuk Pterodactyl Panel (1024–65535): " PORT
        if [[ -z "$PORT" ]]; then
            echo -e "${RED}❌ Port tidak boleh kosong.${NC}"
            continue
        fi
        if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then
            echo -e "${RED}❌ Port harus angka antara 1024–65535.${NC}"
            continue
        fi
        if command -v ss >/dev/null 2>&1; then
            if ss -tulpn 2>/dev/null | grep -q ":$PORT\b"; then
                echo -e "${RED}❌ Port $PORT sudah digunakan.${NC}"
                continue
            fi
        else
            if netstat -tulpn 2>/dev/null | grep -q ":$PORT\b"; then
                echo -e "${RED}❌ Port $PORT sudah digunakan.${NC}"
                continue
            fi
        fi
        echo -e "${GREEN}✅ Port $PORT tersedia.${NC}"
        break
    done
}

# Fungsi: minta nama instance
get_instance_name() {
    while true; do
        read -rp "Masukkan nama instance (contoh: panel1, tanpa spasi atau karakter khusus): " INSTANCE
        if [[ -z "$INSTANCE" ]]; then
            echo -e "${RED}❌ Nama instance tidak boleh kosong.${NC}"
            continue
        fi
        if [[ ! "$INSTANCE" =~ ^[a-zA-Z0-9]+$ ]]; then
            echo -e "${RED}❌ Nama instance hanya boleh berisi huruf dan angka (tanpa spasi atau karakter khusus).${NC}"
            continue
        fi
        if [[ -d "/var/www/pterodactyl-$INSTANCE" ]]; then
            echo -e "${RED}❌ Instance dengan nama $INSTANCE sudah ada di /var/www/pterodactyl-$INSTANCE.${NC}"
            continue
        fi
        echo -e "${GREEN}✅ Nama instance $INSTANCE tersedia.${NC}"
        break
    done
}

# Fungsi: dapatkan nomor database Redis untuk instance
get_redis_db() {
    local instance="$1"
    local db=0
    local instances=()
    for existing in /var/www/pterodactyl-*; do
        if [[ -d "$existing" ]]; then
            instances+=("${existing##*/pterodactyl-}")
        fi
    done
    for existing_instance in "${instances[@]}"; do
        if [[ "$existing_instance" == "$instance" ]]; then
            break
        fi
        ((db++))
    done
    echo "$db"
}

# Fungsi: uninstall bersih untuk instance tertentu
uninstall_ptero() {
    echo -e "${ORANGE}Masukkan nama instance yang akan dihapus (atau kosongkan untuk menghapus semua):${NC}"
    read -rp "Nama instance (contoh: panel1): " INSTANCE
    if [[ -z "$INSTANCE" ]]; then
        echo -e "${RED}PERINGATAN: Ini akan menghapus SEMUA instance Pterodactyl, Wings, Nginx, MariaDB, Redis, PHP, dan file terkait.${NC}"
        read -rp "Lanjutkan? (y/N): " ans
        [[ "$ans" != "y" && "$ans" != "Y" ]] && { echo -e "${YELLOW}Dibatalkan.${NC}"; exit 0; }
        # Hentikan semua layanan terkait
        systemctl stop nginx php*-fpm mariadb redis-server pteroq*.service wings.service 2>/dev/null || true
        # Hapus semua file dan konfigurasi
        rm -rf /var/www/pterodactyl* /etc/pterodactyl /etc/nginx/sites-{available,enabled}/pterodactyl*.conf \
               /etc/mysql /var/lib/mysql /var/lib/redis /etc/redis
        # Hapus semua layanan systemd
        rm -f /etc/systemd/system/pteroq*.service /etc/systemd/system/wings.service
        systemctl daemon-reload
        # Bersihkan cron
        crontab -l 2>/dev/null | grep -v "pterodactyl-" | crontab - 2>/dev/null || true
        # Bersihkan Redis
        redis-cli FLUSHALL >/dev/null 2>&1 || true
        # Hapus paket
        apt purge -y nginx* mariadb-* mysql-* redis-server php* composer nodejs npm certbot docker.io 2>/dev/null || true
        apt autoremove -y --purge
        apt clean
        # Bersihkan firewall
        if command -v ufw >/dev/null 2>&1; then
            ufw --force reset >/dev/null 2>&1
            echo -e "${GREEN}✅ Firewall telah direset.${NC}"
        fi
        echo -e "${GREEN}=== UNINSTALL SEMUA INSTANCE SELESAI ===${NC}"
    else
        if [[ ! -d "/var/www/pterodactyl-$INSTANCE" ]]; then
            echo -e "${RED}❌ Instance $INSTANCE tidak ditemukan di /var/www/pterodactyl-$INSTANCE.${NC}"
            exit 1
        fi
        echo -e "${RED}PERINGATAN: Ini akan menghapus instance Pterodactyl $INSTANCE dan semua file, database, serta konfigurasi terkait.${NC}"
        read -rp "Lanjutkan? (y/N): " ans
        [[ "$ans" != "y" && "$ans" != "Y" ]] && { echo -e "${YELLOW}Dibatalkan.${NC}"; exit 0; }
        # Hentikan layanan terkait
        systemctl stop pteroq-$INSTANCE.service 2>/dev/null || true
        systemctl disable pteroq-$INSTANCE.service 2>/dev/null || true
        # Hapus file dan direktori
        rm -rf /var/www/pterodactyl-$INSTANCE /etc/nginx/sites-{available,enabled}/pterodactyl-$INSTANCE.conf
        # Hapus layanan systemd
        rm -f /etc/systemd/system/pteroq-$INSTANCE.service
        systemctl daemon-reload
        # Hapus database MySQL
        mysql -u root -e "DROP DATABASE IF EXISTS panel_$INSTANCE;" 2>/dev/null || true
        mysql -u root -e "DROP USER IF EXISTS 'pterouser_$INSTANCE'@'127.0.0.1';" 2>/dev/null || true
        mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null || true
        # Hapus Redis database
        REDIS_DB=$(redis-cli -n 0 KEYS "pterodactyl_session_$INSTANCE*" | wc -l)
        redis-cli -n $REDIS_DB FLUSHDB >/dev/null 2>&1 || true
        # Hapus entri cron
        crontab -l 2>/dev/null | grep -v "pterodactyl-$INSTANCE/artisan" | crontab - 2>/dev/null || true
        # Restart layanan
        systemctl restart nginx php8.2-fpm redis mariadb 2>/dev/null || true
        # Bersihkan firewall untuk port instance
        if command -v ufw >/dev/null 2>&1; then
            PORT=$(grep -oP 'listen \K[0-9]+' /etc/nginx/sites-available/pterodactyl-$INSTANCE.conf 2>/dev/null || echo "")
            [[ -n "$PORT" ]] && ufw delete allow $PORT >/dev/null 2>&1
            echo -e "${GREEN}✅ Port terkait instance $INSTANCE telah dihapus dari firewall.${NC}"
        fi
        echo -e "${GREEN}=== UNINSTALL INSTANCE $INSTANCE SELESAI ===${NC}"
    fi
}

# Fungsi: install Pterodactyl Panel
install_ptero() {
    local recaptcha="$1"
    local instance="$2"
    local port="$3"
    check_dependencies
    DB_NAME="panel_$instance"
    DB_USER="pterouser_$instance"
    DB_PASS=$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9')
    ADMIN_EMAIL="admin@example.com"
    ADMIN_USER="admin"
    ADMIN_FNAME="Panel"
    ADMIN_LNAME="Admin"
    ADMIN_PASS=$(openssl rand -base64 10 | tr -dc 'A-Za-z0-9!@#$%^&*()_+')
    TZ="Asia/Jakarta"
    IP=$(get_ip)
    APP_URL="http://${IP}:${port}"
    REDIS_DB=$(get_redis_db "$instance")
    SESSION_COOKIE="pterodactyl_session_$instance"
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
    mkdir -p /var/www/pterodactyl-$instance
    cd /var/www/pterodactyl-$instance
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
REDIS_DATABASE=${REDIS_DB}
SESSION_COOKIE=${SESSION_COOKIE}
ENV
    if [[ "$recaptcha" == "no" ]]; then
        echo "RECAPTCHA_ENABLED=false" >> .env
    fi
    curl -sS https://getcomposer.org/installer | php
    export COMPOSER_ALLOW_SUPERUSER=1
    php composer.phar install --no-dev --optimize-autoloader
    php artisan optimize:clear
    php artisan migrate --seed --force
    chown -R www-data:www-data /var/www/pterodactyl-$instance
    chmod -R 775 storage bootstrap/cache
    php artisan storage:link || true
    cat >/etc/nginx/sites-available/pterodactyl-$instance.conf <<NGINX
server {
    listen ${port};
    server_name _;
    root /var/www/pterodactyl-$instance/public;
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
    ln -sf /etc/nginx/sites-available/pterodactyl-$instance.conf /etc/nginx/sites-enabled/
    nginx -t
    systemctl restart nginx
    # Buka port di firewall
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ${port} >/dev/null 2>&1
        echo -e "${GREEN}✅ Port ${port} telah dibuka di firewall.${NC}"
    else
        echo -e "${YELLOW}⚠️ UFW tidak terdeteksi, pastikan port ${port} terbuka secara manual jika menggunakan firewall lain.${NC}"
    fi
    ( crontab -l 2>/dev/null | grep -v "pterodactyl-$instance/artisan" ; echo "* * * * * php /var/www/pterodactyl-$instance/artisan schedule:run >> /dev/null 2>&1" ) | crontab -
    cat >/etc/systemd/system/pteroq-$instance.service <<SERVICE
[Unit]
Description=Pterodactyl Queue Worker ($instance)
After=redis.service
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl-$instance/artisan queue:work --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
SERVICE
    systemctl daemon-reload
    systemctl enable --now pteroq-$instance.service
    sudo -u www-data php artisan p:user:make \
        --email="$ADMIN_EMAIL" \
        --username="$ADMIN_USER" \
        --name-first="$ADMIN_FNAME" \
        --name-last="$ADMIN_LNAME" \
        --password="$ADMIN_PASS" \
        --admin=1 \
        --no-interaction
    # Bersihkan cache aplikasi
    php artisan optimize:clear
    # Verifikasi layanan
    systemctl restart nginx php8.2-fpm redis mariadb pteroq-$instance.service
    echo -e "${ORANGE}=== VERIFIKASI LAYANAN ===${NC}"
    systemctl status nginx --no-pager
    systemctl status php8.2-fpm --no-pager
    systemctl status redis --no-pager
    systemctl status mariadb --no-pager
    systemctl status pteroq-$instance.service --no-pager
    clear
    echo -e "${GREEN}=== INSTALLASI PANEL SELESAI ===${NC}"
    echo -e "${GREEN}Akses Panel: ${APP_URL}${NC}"
    echo -e "${GREEN}Email Admin: ${ADMIN_EMAIL}${NC}"
    echo -e "${GREEN}Username: ${ADMIN_USER}${NC}"
    echo -e "${GREEN}Password: ${ADMIN_PASS}${NC}"
    echo -e "${YELLOW}Catatan: Port ${port} telah dibuka. Jika website tidak dapat diakses, periksa firewall cloud provider (misalnya, AWS, GCP) untuk memastikan port ${port} diizinkan.${NC}"
}

# Fungsi: install Wings (satu instance untuk semua panel)
install_wings() {
    echo -e "${ORANGE}Menginstal Pterodactyl Wings...${NC}"
    check_dependencies
    if [[ -f "/usr/local/bin/wings" && -f "/etc/pterodactyl/config.yml" ]]; then
        echo -e "${YELLOW}⚠️ Wings sudah terinstal. Melewati instalasi.${NC}"
        return
    fi
    mkdir -p /etc/pterodactyl
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/download/v1.11.0/wings_linux_amd64
    chmod +x /usr/local/bin/wings
    cat >/etc/systemd/system/wings.service <<SERVICE
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
[Service]
User=root
Group=root
Restart=always
ExecStart=/usr/local/bin/wings --config /etc/pterodactyl/config.yml
WorkingDirectory=/etc/pterodactyl
[Install]
WantedBy=multi-user.target
SERVICE
    systemctl daemon-reload
    systemctl enable --now wings.service
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 8080 >/dev/null 2>&1
        ufw allow 2022 >/dev/null 2>&1
        echo -e "${GREEN}✅ Port Wings 8080 (HTTP) dan 2022 (SFTP) telah dibuka di firewall.${NC}"
    else
        echo -e "${YELLOW}⚠️ UFW tidak terdeteksi, pastikan port 8080 dan 2022 terbuka secara manual.${NC}"
    fi
    echo -e "${GREEN}✅ Wings terinstal. Tambahkan node di panel dan masukkan token menggunakan opsi 888.${NC}"
}

# Fungsi: konfigurasi token Wings untuk instance tertentu
configure_wings_token() {
    echo -e "${ORANGE}Masukkan nama instance (contoh: panel1):${NC}"
    read -rp "Nama instance: " INSTANCE
    if [[ -z "$INSTANCE" ]]; then
        echo -e "${RED}❌ Nama instance tidak boleh kosong.${NC}"
        exit 1
    fi
    if [[ ! -d "/var/www/pterodactyl-$INSTANCE" ]]; then
        echo -e "${RED}❌ Panel untuk instance $INSTANCE tidak ditemukan di /var/www/pterodactyl-$INSTANCE.${NC}"
        exit 1
    fi
    echo -e "${ORANGE}Masukkan token dari panel untuk instance $INSTANCE:${NC}"
    read -rp "Token: " TOKEN
    if [[ -z "$TOKEN" ]]; then
        echo -e "${RED}❌ Token tidak boleh kosong.${NC}"
        exit 1
    fi
    IP=$(get_ip)
    PORT=$(grep -oP 'listen \K[0-9]+' /etc/nginx/sites-available/pterodactyl-$INSTANCE.conf)
    if [[ ! -f "/etc/pterodactyl/config.yml" ]]; then
        cat >/etc/pterodactyl/config.yml <<CONFIG
token: $TOKEN
panel_url: http://${IP}:${PORT}
http_port: 8080
sftp_port: 2022
CONFIG
    else
        echo -e "${YELLOW}⚠️ File config.yml sudah ada. Token hanya perlu disimpan di node panel. Pastikan token sesuai di panel instance $INSTANCE.${NC}"
    fi
    systemctl restart wings.service
    echo -e "${GREEN}✅ Token untuk instance $INSTANCE telah dikonfigurasi. Wings sedang berjalan di port 8080 (HTTP) dan 2022 (SFTP).${NC}"
}

# Fungsi: buat pengguna baru dengan username sama dengan password
create_user() {
    echo -e "${ORANGE}Masukkan nama instance (contoh: panel1):${NC}"
    read -rp "Nama instance: " INSTANCE
    if [[ -z "$INSTANCE" ]]; then
        echo -e "${RED}❌ Nama instance tidak boleh kosong.${NC}"
        exit 1
    fi
    if [[ ! -d "/var/www/pterodactyl-$INSTANCE" ]]; then
        echo -e "${RED}❌ Instance $INSTANCE tidak ditemukan di /var/www/pterodactyl-$INSTANCE.${NC}"
        exit 1
    fi
    check_dependencies
    cd /var/www/pterodactyl-$INSTANCE
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
    php artisan optimize:clear
    echo -e "${GREEN}=== PENGGUNA BARU DIBUAT ===${NC}"
    echo -e "${GREEN}Email: ${ADMIN_EMAIL}${NC}"
    echo -e "${GREEN}Username: ${ADMIN_USER}${NC}"
    echo -e "${GREEN}Password: ${ADMIN_PASS}${NC}"
}

# Fungsi: lihat semua pengguna untuk instance tertentu
list_users() {
    echo -e "${ORANGE}Masukkan nama instance (contoh: panel1):${NC}"
    read -rp "Nama instance: " INSTANCE
    if [[ -z "$INSTANCE" ]]; then
        echo -e "${RED}❌ Nama instance tidak boleh kosong.${NC}"
        exit 1
    fi
    if [[ ! -d "/var/www/pterodactyl-$INSTANCE" ]]; then
        echo -e "${RED}❌ Instance $INSTANCE tidak ditemukan di /var/www/pterodactyl-$INSTANCE.${NC}"
        exit 1
    fi
    check_dependencies
    mysql -u root -e "USE panel_$INSTANCE; SELECT username, email, password FROM users;" 2>/dev/null || {
        echo -e "${RED}❌ Gagal mengakses database. Pastikan MariaDB berjalan dan database 'panel_$INSTANCE' ada.${NC}"
        exit 1
    }
}

# Fungsi: hapus pengguna tertentu untuk instance tertentu
delete_user() {
    echo -e "${ORANGE}Masukkan nama instance (contoh: panel1):${NC}"
    read -rp "Nama instance: " INSTANCE
    if [[ -z "$INSTANCE" ]]; then
        echo -e "${RED}❌ Nama instance tidak boleh kosong.${NC}"
        exit 1
    fi
    if [[ ! -d "/var/www/pterodactyl-$INSTANCE" ]]; then
        echo -e "${RED}❌ Instance $INSTANCE tidak ditemukan di /var/www/pterodactyl-$INSTANCE.${NC}"
        exit 1
    fi
    echo -e "${ORANGE}Masukkan email atau username pengguna yang ingin dihapus:${NC}"
    read -rp "Email/Username: " identifier
    if [[ -z "$identifier" ]]; then
        echo -e "${RED}❌ Email atau username tidak boleh kosong.${NC}"
        exit 1
    fi
    mysql -u root -e "USE panel_$INSTANCE; DELETE FROM users WHERE email='$identifier' OR username='$identifier';" 2>/dev/null || {
        echo -e "${RED}❌ Gagal menghapus pengguna. Pastikan MariaDB berjalan dan pengguna ada.${NC}"
        exit 1
    }
    cd /var/www/pterodactyl-$INSTANCE
    php artisan optimize:clear
    echo -e "${GREEN}✅ Pengguna dengan email/username '$identifier' telah dihapus dari instance $INSTANCE.${NC}"
}

# Menu pilihan
echo -e "${ORANGE}=== Pterodactyl Panel & Wings Installer ===${NC}"
echo "0) Batal / Cancel"
echo "1) Uninstall bersih / Clean uninstall (pilih instance atau semua)"
echo "2) Install panel dengan reCAPTCHA + Wings"
echo "3) Install panel tanpa reCAPTCHA + Wings"
echo "4) Buat pengguna baru (username = password, email = admin@password.com)"
echo "5) Lihat semua pengguna untuk instance tertentu"
echo "6) Hapus pengguna tertentu untuk instance tertentu"
echo "12) Uninstall lalu install panel dengan reCAPTCHA + Wings"
echo "13) Uninstall lalu install panel tanpa reCAPTCHA + Wings"
echo "888) Konfigurasi token Wings untuk instance tertentu"
read -rp "Pilih opsi [0-6,12-13,888]: " choice
case "$choice" in
    0) echo -e "${YELLOW}Dibatalkan.${NC}"; exit 0 ;;
    1) uninstall_ptero ;;
    2) get_instance_name && check_ports && get_port && install_ptero "yes" "$INSTANCE" "$PORT" && install_wings ;;
    3) get_instance_name && check_ports && get_port && install_ptero "no" "$INSTANCE" "$PORT" && install_wings ;;
    4) create_user ;;
    5) list_users ;;
    6) delete_user ;;
    12) uninstall_ptero && get_instance_name && check_ports && get_port && install_ptero "yes" "$INSTANCE" "$PORT" && install_wings ;;
    13) uninstall_ptero && get_instance_name && check_ports && get_port && install_ptero "no" "$INSTANCE" "$PORT" && install_wings ;;
    888) configure_wings_token ;;
    *) echo -e "${RED}Pilihan tidak valid.${NC}"; exit 1 ;;
esac
