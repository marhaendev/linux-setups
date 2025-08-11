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
    # Pastikan direktori Redis ada
    if [ ! -d /var/lib/redis ]; then
        mkdir -p /var/lib/redis /var/log/redis
        chown redis:redis /var/lib/redis /var/log/redis
        chmod 755 /var/lib/redis /var/log/redis
    fi
    for cmd in curl netstat awk sed mysql nginx php ufw redis-cli; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${RED}❌ Perintah $cmd tidak ditemukan. Menginstall dependensi dasar...${NC}"
            apt-get update -y && apt-get install -y curl net-tools gawk sed mariadb-client nginx php8.2-cli ufw redis-tools php8.2-redis
        fi
    done
    # Pastikan Redis berjalan
    if ! systemctl is-active --quiet redis-server; then
        echo -e "${YELLOW}⚠️ Layanan redis-server tidak aktif. Mencoba memulai...${NC}"
        systemctl restart redis-server 2>/dev/null || {
            echo -e "${RED}❌ Gagal memulai redis-server. Periksa log dengan 'journalctl -xeu redis-server.service'.${NC}"
            echo -e "${YELLOW}Melanjutkan instalasi tanpa Redis...${NC}"
            return 1
        }
    fi
}

# Fungsi: cek status Redis
check_redis() {
    if ! systemctl is-active --quiet redis-server; then
        echo -e "${YELLOW}⚠️ Layanan redis-server tidak aktif. Mencoba memulai...${NC}"
        systemctl restart redis-server 2>/dev/null || {
            echo -e "${RED}❌ Gagal memulai redis-server. Periksa log dengan 'journalctl -xeu redis-server.service'.${NC}"
            echo -e "${YELLOW}Melanjutkan instalasi tanpa Redis...${NC}"
            return 1
        }
    fi
    # Periksa port Redis
    if ss -tulpn | grep -q ":6379\b"; then
        local new_port=6380
        while ss -tulpn | grep -q ":$new_port\b"; do
            ((new_port++))
        done
        echo -e "${YELLOW}⚠️ Port 6379 sudah digunakan. Mengubah ke port $new_port...${NC}"
        sed -i "s/^port 6379/port $new_port/" /etc/redis/redis.conf
        systemctl restart redis-server 2>/dev/null || {
            echo -e "${RED}❌ Gagal restart redis-server dengan port baru.${NC}"
            return 1
        }
        echo -e "${GREEN}✅ Redis diubah ke port $new_port.${NC}"
        REDIS_PORT=$new_port
    else
        REDIS_PORT=6379
    fi
    echo -e "${GREEN}✅ Layanan redis-server aktif.${NC}"
    return 0
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

# Fungsi: minta port dari user
get_port() {
    while true; do
        read -rp "Masukkan port untuk Pterodactyl (1024–65535): " PORT
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

# Fungsi: minta lokasi
get_location() {
    while true; do
        echo -e "${ORANGE}Pilih lokasi default untuk node (SG untuk Singapura, ID untuk Indonesia):${NC}"
        read -rp "Lokasi [SG/ID]: " LOCATION
        if [[ "$LOCATION" != "SG" && "$LOCATION" != "ID" ]]; then
            echo -e "${RED}❌ Lokasi harus SG atau ID.${NC}"
            continue
        fi
        echo -e "${GREEN}✅ Lokasi $LOCATION dipilih.${NC}"
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
        echo -e "${RED}PERINGATAN: Ini akan menghapus SEMUA instance Pterodactyl, Nginx, MariaDB, Redis, PHP, dan file terkait.${NC}"
        read -rp "Lanjutkan? (y/N): " ans
        [[ "$ans" != "y" && "$ans" != "Y" ]] && { echo -e "${YELLOW}Dibatalkan.${NC}"; exit 0; }
        systemctl stop nginx php*-fpm mariadb redis-server pteroq*.service 2>/dev/null || true
        apt purge -y nginx* mariadb-* mysql-* redis-server php* composer nodejs npm certbot 2>/dev/null || true
        apt autoremove -y --purge
        apt clean
        rm -rf /var/www/pterodactyl* /etc/nginx/sites-{available,enabled}/pterodactyl*.conf \
               /etc/mysql /var/lib/mysql /var/lib/redis /etc/redis
        redis-cli FLUSHALL >/dev/null 2>&1 || true
        echo -e "${GREEN}=== UNINSTALL SEMUA INSTANCE SELESAI ===${NC}"
    else
        if [[ ! -d "/var/www/pterodactyl-$INSTANCE" ]]; then
            echo -e "${RED}❌ Instance $INSTANCE tidak ditemukan di /var/www/pterodactyl-$INSTANCE.${NC}"
            exit 1
        fi
        echo -e "${RED}PERINGATAN: Ini akan menghapus instance Pterodactyl $INSTANCE dan file terkait.${NC}"
        read -rp "Lanjutkan? (y/N): " ans
        [[ "$ans" != "y" && "$ans" != "Y" ]] && { echo -e "${YELLOW}Dibatalkan.${NC}"; exit 0; }
        systemctl stop pteroq-$INSTANCE.service 2>/dev/null || true
        systemctl disable pteroq-$INSTANCE.service 2>/dev/null || true
        rm -f /etc/systemd/system/pteroq-$INSTANCE.service
        rm -rf /var/www/pterodactyl-$INSTANCE /etc/nginx/sites-{available,enabled}/pterodactyl-$INSTANCE.conf
        mysql -u root -e "DROP DATABASE IF EXISTS panel_$INSTANCE;" 2>/dev/null || true
        redis-cli -n $(get_redis_db "$INSTANCE") FLUSHDB >/dev/null 2>&1 || true
        systemctl restart nginx
        echo -e "${GREEN}=== UNINSTALL INSTANCE $INSTANCE SELESAI ===${NC}"
    fi
}

# Fungsi: install Pterodactyl
install_ptero() {
    local recaptcha="$1"
    local instance="$2"
    local port="$3"
    local location="$4"
    local nodejs="$5"
    local golang="$6"
    check_dependencies
    check_redis || true
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
    REDIS_PORT=${REDIS_PORT:-6379}
    export DEBIAN_FRONTEND=noninteractive
    timedatectl set-timezone "$TZ" 2>/dev/null || true
    apt-get update -y
    apt-get install -y software-properties-common curl ca-certificates gnupg unzip tar
    add-apt-repository -y ppa:ondrej/php 2>/dev/null || true
    apt-get update -y
    apt-get install -y nginx php8.2 php8.2-fpm php8.2-cli php8.2-gd php8.2-mysql \
                      php8.2-mbstring php8.2-bcmath php8.2-xml php8.2-curl php8.2-zip \
                      redis-server mariadb-server mariadb-client php8.2-redis
    systemctl enable nginx php8.2-fpm mariadb 2>/dev/null || true
    systemctl enable --now redis-server 2>/dev/null || echo -e "${YELLOW}⚠️ Gagal mengaktifkan redis-server, melanjutkan instalasi...${NC}"
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
REDIS_PORT=${REDIS_PORT}
REDIS_DATABASE=${REDIS_DB}
SESSION_COOKIE=${SESSION_COOKIE}
ENV
    if [[ "$recaptcha" == "no" ]]; then
        echo "RECAPTCHA_ENABLED=false" >> .env
    fi
    curl -sS https://getcomposer.org/installer | php
    export COMPOSER_ALLOW_SUPERUSER=1
    php composer.phar install --no-dev --optimize-autoloader || {
        echo -e "${YELLOW}⚠️ Composer install gagal, mencoba ulang...${NC}"
        php composer.phar install --no-dev --optimize-autoloader
    }
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
    # Setup lokasi
    mysql -u root <<SQL
USE \`$DB_NAME\`;
INSERT INTO locations (short, long, created_at, updated_at) VALUES
('$location', '$([ "$location" == "SG" ] && echo "Singapore" || echo "Indonesia")', NOW(), NOW());
SQL
    # Setup node
    NODE_ID=$(mysql -u root -N -e "USE \`$DB_NAME\`; INSERT INTO nodes (name, location_id, fqdn, scheme, memory, disk, daemon_listen, created_at, updated_at) VALUES ('Node-$instance', 1, '$IP', 'http', 1024, 10240, 25565, NOW(), NOW()); SELECT LAST_INSERT_ID();")
    # Setup eggs untuk Node.js dan/atau Golang
    if [[ "$nodejs" == "yes" ]]; then
        for version in 20 19 18 17 16 15 14 13 12 11; do
            mysql -u root <<SQL
USE \`$DB_NAME\`;
INSERT INTO eggs (name, description, docker_image, startup, created_at, updated_at) VALUES
('Node.js v$version', 'Node.js version $version', 'node:$version', 'node {{SERVER_STARTUP}}', NOW(), NOW());
INSERT INTO egg_nest (egg_id, nest_id) VALUES (LAST_INSERT_ID(), 1);
SQL
        done
    fi
    if [[ "$golang" == "yes" ]]; then
        for version in 1.21 1.20 1.19 1.18 1.17 1.16 1.15 1.14 1.13 1.12; do
            mysql -u root <<SQL
USE \`$DB_NAME\`;
INSERT INTO eggs (name, description, docker_image, startup, created_at, updated_at) VALUES
('Golang v$version', 'Golang version $version', 'golang:$version', 'go run {{SERVER_STARTUP}}', NOW(), NOW());
INSERT INTO egg_nest (egg_id, nest_id) VALUES (LAST_INSERT_ID(), 1);
SQL
        done
    fi
    # Setup server
    if [[ "$nodejs" == "yes" || "$golang" == "yes" ]]; then
        mysql -u root <<SQL
USE \`$DB_NAME\`;
INSERT INTO servers (name, user_id, node_id, egg_id, created_at, updated_at) VALUES
('Server-$instance', 1, $NODE_ID, (SELECT id FROM eggs WHERE name LIKE '%$([ "$nodejs" == "yes" ] && echo "Node.js v20" || echo "Golang v1.21")%' LIMIT 1), NOW(), NOW());
SQL
    fi
    # Bersihkan cache aplikasi dan Redis
    php artisan optimize:clear
    redis-cli -n ${REDIS_DB} FLUSHDB >/dev/null 2>&1 || true
    # Verifikasi layanan
    systemctl restart nginx php8.2-fpm mariadb pteroq-$instance.service
    systemctl restart redis-server 2>/dev/null || echo -e "${YELLOW}⚠️ Gagal restart redis-server, periksa konfigurasi Redis.${NC}"
    echo -e "${ORANGE}=== VERIFIKASI LAYANAN ===${NC}"
    systemctl status nginx --no-pager
    systemctl status php8.2-fpm --no-pager
    systemctl status redis --no-pager
    systemctl status mariadb --no-pager
    systemctl status pteroq-$instance.service --no-pager
    clear
    echo -e "${GREEN}=== INSTALLASI SELESAI ===${NC}"
    echo -e "${GREEN}Akses Panel: ${APP_URL}${NC}"
    echo -e "${GREEN}Email Admin: ${ADMIN_EMAIL}${NC}"
    echo -e "${GREEN}Username: ${ADMIN_USER}${NC}"
    echo -e "${GREEN}Password: ${ADMIN_PASS}${NC}"
    echo -e "${YELLOW}Catatan: Port ${port} telah dibuka. Jika website tidak dapat diakses, periksa firewall cloud provider (misalnya, AWS, GCP) untuk memastikan port ${port} diizinkan.${NC}"
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
    REDIS_DB=$(get_redis_db "$INSTANCE")
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
    redis-cli -n ${REDIS_DB} FLUSHDB >/dev/null 2>&1 || true
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
    REDIS_DB=$(get_redis_db "$INSTANCE")
    php artisan optimize:clear
    redis-cli -n ${REDIS_DB} FLUSHDB >/dev/null 2>&1 || true
    echo -e "${GREEN}✅ Pengguna dengan email/username '$identifier' telah dihapus dari instance $INSTANCE.${NC}"
}

# Menu pilihan
echo -e "${ORANGE}=== Pterodactyl Panel Installer ===${NC}"
echo "1) Uninstall bersih / Clean uninstall (pilih instance atau semua)"
echo "2) Install dengan reCAPTCHA (Node.js + Golang)"
echo "26) Install dengan reCAPTCHA (Node.js only)"
echo "27) Install dengan reCAPTCHA (Golang only)"
echo "3) Install tanpa reCAPTCHA (Node.js + Golang)"
echo "36) Install tanpa reCAPTCHA (Node.js only)"
echo "37) Install tanpa reCAPTCHA (Golang only)"
echo "4) Buat pengguna baru (username = password, email = admin@password.com)"
echo "5) Lihat semua pengguna untuk instance tertentu"
echo "6) Hapus pengguna tertentu untuk instance tertentu"
echo "12) Uninstall lalu install dengan reCAPTCHA (Node.js + Golang)"
echo "126) Uninstall lalu install dengan reCAPTCHA (Node.js only)"
echo "127) Uninstall lalu install dengan reCAPTCHA (Golang only)"
echo "13) Uninstall lalu install tanpa reCAPTCHA (Node.js + Golang)"
echo "136) Uninstall lalu install tanpa reCAPTCHA (Node.js only)"
echo "137) Uninstall lalu install tanpa reCAPTCHA (Golang only)"
echo "0) Batal / Cancel"
read -rp "Pilih opsi [0-6,12,13,26,27,36,37,126,127,136,137]: " choice
case "$choice" in
    0) echo -e "${YELLOW}Dibatalkan.${NC}"; exit 0 ;;
    1) uninstall_ptero ;;
    2) get_instance_name && check_ports && get_port && get_location && install_ptero "yes" "$INSTANCE" "$PORT" "$LOCATION" "yes" "yes" ;;
    26) get_instance_name && check_ports && get_port && get_location && install_ptero "yes" "$INSTANCE" "$PORT" "$LOCATION" "yes" "no" ;;
    27) get_instance_name && check_ports && get_port && get_location && install_ptero "yes" "$INSTANCE" "$PORT" "$LOCATION" "no" "yes" ;;
    3) get_instance_name && check_ports && get_port && get_location && install_ptero "no" "$INSTANCE" "$PORT" "$LOCATION" "yes" "yes" ;;
    36) get_instance_name && check_ports && get_port && get_location && install_ptero "no" "$INSTANCE" "$PORT" "$LOCATION" "yes" "no" ;;
    37) get_instance_name && check_ports && get_port && get_location && install_ptero "no" "$INSTANCE" "$PORT" "$LOCATION" "no" "yes" ;;
    4) create_user ;;
    5) list_users ;;
    6) delete_user ;;
    12) uninstall_ptero && get_instance_name && check_ports && get_port && get_location && install_ptero "yes" "$INSTANCE" "$PORT" "$LOCATION" "yes" "yes" ;;
    126) uninstall_ptero && get_instance_name && check_ports && get_port && get_location && install_ptero "yes" "$INSTANCE" "$PORT" "$LOCATION" "yes" "no" ;;
    127) uninstall_ptero && get_instance_name && check_ports && get_port && get_location && install_ptero "yes" "$INSTANCE" "$PORT" "$LOCATION" "no" "yes" ;;
    13) uninstall_ptero && get_instance_name && check_ports && get_port && get_location && install_ptero "no" "$INSTANCE" "$PORT" "$LOCATION" "yes" "yes" ;;
    136) uninstall_ptero && get_instance_name && check_ports && get_port && get_location && install_ptero "no" "$INSTANCE" "$PORT" "$LOCATION" "yes" "no" ;;
    137) uninstall_ptero && get_instance_name && check_ports && get_port && get_location && install_ptero "no" "$INSTANCE" "$PORT" "$LOCATION" "no" "yes" ;;
    *) echo -e "${RED}Pilihan tidak valid.${NC}"; exit 1 ;;
esac
