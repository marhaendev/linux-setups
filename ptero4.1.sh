#!/bin/bash
set -e
# Warna untuk output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fungsi: uninstall bersih untuk instance tertentu
uninstall_ptero() {
    echo -e "${ORANGE}Masukkan nama instance yang akan dihapus (atau kosongkan untuk menghapus semua):${NC}"
    read -rp "Nama instance (contoh: panel1): " INSTANCE
    if [[ -z "$INSTANCE" ]]; then
        echo -e "${RED}PERINGATAN: Ini akan menghapus SEMUA instance Pterodactyl, Wings, Nginx, MariaDB, Redis, PHP, dan file terkait.${NC}"
        read -rp "Lanjutkan? (y/N): " ans
        [[ "$ans" != "y" && "$ans" != "Y" ]] && { echo -e "${YELLOW}Dibatalkan.${NC}"; exit 0; }
        # Hentikan semua layanan terkait
        systemctl stop nginx php*-fpm mariadb redis-server pteroq*.service wings*.service 2>/dev/null || true
        # Hapus semua file dan konfigurasi
        rm -rf /var/www/pterodactyl* /etc/pterodactyl* /etc/nginx/sites-{available,enabled}/pterodactyl*.conf \
               /etc/mysql /var/lib/mysql /var/lib/redis /etc/redis
        # Hapus semua layanan systemd
        rm -f /etc/systemd/system/pteroq*.service /etc/systemd/system/wings*.service
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
        if [[ ! -d "/var/www/pterodactyl-$INSTANCE" && ! -d "/etc/pterodactyl-$INSTANCE" ]]; then
            echo -e "${RED}❌ Instance $INSTANCE tidak ditemukan di /var/www/pterodactyl-$INSTANCE atau /etc/pterodactyl-$INSTANCE.${NC}"
            exit 1
        fi
        echo -e "${RED}PERINGATAN: Ini akan menghapus instance Pterodactyl $INSTANCE, Wings terkait, dan semua file, database, serta konfigurasi terkait.${NC}"
        read -rp "Lanjutkan? (y/N): " ans
        [[ "$ans" != "y" && "$ans" != "Y" ]] && { echo -e "${YELLOW}Dibatalkan.${NC}"; exit 0; }
        # Hentikan layanan terkait
        systemctl stop pteroq-$INSTANCE.service wings-$INSTANCE.service 2>/dev/null || true
        systemctl disable pteroq-$INSTANCE.service wings-$INSTANCE.service 2>/dev/null || true
        # Hapus file dan direktori
        rm -rf /var/www/pterodactyl-$INSTANCE /etc/pterodactyl-$INSTANCE \
               /etc/nginx/sites-{available,enabled}/pterodactyl-$INSTANCE.conf
        # Hapus layanan systemd
        rm -f /etc/systemd/system/pteroq-$INSTANCE.service /etc/systemd/system/wings-$INSTANCE.service
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
            WINGS_HTTP_PORT=$(grep -oP 'http_port: \K[0-9]+' /etc/pterodactyl-$INSTANCE/config.yml 2>/dev/null || echo "")
            WINGS_SFTP_PORT=$(grep -oP 'sftp_port: \K[0-9]+' /etc/pterodactyl-$INSTANCE/config.yml 2>/dev/null || echo "")
            [[ -n "$PORT" ]] && ufw delete allow $PORT >/dev/null 2>&1
            [[ -n "$WINGS_HTTP_PORT" ]] && ufw delete allow $WINGS_HTTP_PORT >/dev/null 2>&1
            [[ -n "$WINGS_SFTP_PORT" ]] && ufw delete allow $WINGS_SFTP_PORT >/dev/null 2>&1
            echo -e "${GREEN}✅ Port terkait instance $INSTANCE telah dihapus dari firewall.${NC}"
        fi
        echo -e "${GREEN}=== UNINSTALL INSTANCE $INSTANCE SELESAI ===${NC}"
    fi
}
# Fungsi stub untuk keperluan kompatibilitas dengan skrip sebelumnya
check_dependencies() { true; }
get_redis_db() { echo 0; }
# Menu pilihan (hanya untuk testing fungsi uninstall)
echo -e "${ORANGE}=== Pterodactyl Panel & Wings Uninstaller ===${NC}"
echo "0) Batal / Cancel"
echo "1) Uninstall bersih / Clean uninstall (pilih instance atau semua)"
read -rp "Pilih opsi [0-1]: " choice
case "$choice" in
    0) echo -e "${YELLOW}Dibatalkan.${NC}"; exit 0 ;;
    1) uninstall_ptero ;;
    *) echo -e "${RED}Pilihan tidak valid.${NC}"; exit 1 ;;
esac
