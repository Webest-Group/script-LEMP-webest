#!/bin/bash

# Màu sắc cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Script này cần chạy với quyền root${NC}"
    exit 1
fi

# Log file
LOG_DIR="/var/log/webestvps"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/laravel_install_$(date +%Y%m%d_%H%M%S).log"

# Function ghi log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

echo -e "${GREEN}=== CÀI ĐẶT LARAVEL STACK ===${NC}"
echo

# Cài đặt Nginx
log "Bắt đầu cài đặt Nginx..."
if ! command -v nginx &> /dev/null; then
    apt update
    apt install -y nginx
    systemctl enable nginx
    systemctl start nginx
    log "Nginx đã được cài đặt thành công"
else
    log "Nginx đã được cài đặt trước đó"
fi

# Cài đặt PHP (8.1 là phiên bản phổ biến cho Laravel)
log "Bắt đầu cài đặt PHP 8.1 và các extension cần thiết cho Laravel..."
apt update
apt install -y software-properties-common
add-apt-repository -y ppa:ondrej/php
apt update
apt install -y php8.1-fpm php8.1-cli php8.1-common php8.1-mysql php8.1-zip php8.1-gd php8.1-mbstring php8.1-curl php8.1-xml php8.1-bcmath php8.1-intl
systemctl enable php8.1-fpm
systemctl start php8.1-fpm
log "PHP 8.1 và các extension đã được cài đặt thành công"

# Cấu hình PHP cho hiệu suất tốt hơn
log "Cấu hình PHP cho hiệu suất tốt hơn..."
PHP_INI_DIR="/etc/php/8.1/fpm/php.ini"
sed -i 's/memory_limit = .*/memory_limit = 256M/' "$PHP_INI_DIR"
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' "$PHP_INI_DIR"
sed -i 's/post_max_size = .*/post_max_size = 100M/' "$PHP_INI_DIR"
sed -i 's/max_execution_time = .*/max_execution_time = 60/' "$PHP_INI_DIR"
sed -i 's/;date.timezone.*/date.timezone = Asia\/Ho_Chi_Minh/' "$PHP_INI_DIR"

# Khởi động lại PHP
systemctl restart php8.1-fpm
log "Cấu hình PHP hoàn tất"

# Cài đặt MariaDB
log "Bắt đầu cài đặt MariaDB..."
if ! command -v mysql &> /dev/null; then
    apt update
    apt install -y mariadb-server
    systemctl enable mariadb
    systemctl start mariadb
    
    # Bảo mật MariaDB
    mysql_secure_installation <<EOF

y
password
password
y
y
y
y
EOF
    log "MariaDB đã được cài đặt và bảo mật thành công"
else
    log "MariaDB đã được cài đặt trước đó"
fi

# Cài đặt Composer (cần thiết cho Laravel)
log "Bắt đầu cài đặt Composer..."
if ! command -v composer &> /dev/null; then
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
    log "Composer đã được cài đặt thành công"
else
    log "Composer đã được cài đặt trước đó"
fi

# Cài đặt Redis (tùy chọn nhưng khuyến nghị cho Laravel)
log "Bắt đầu cài đặt Redis..."
if ! command -v redis-cli &> /dev/null; then
    apt update
    apt install -y redis-server
    systemctl enable redis-server
    systemctl start redis-server
    # Cài đặt PHP Redis extension
    apt install -y php8.1-redis
    log "Redis đã được cài đặt thành công"
else
    log "Redis đã được cài đặt trước đó"
fi

# Cài đặt Node.js và NPM (cho Laravel Mix)
log "Bắt đầu cài đặt Node.js và NPM..."
if ! command -v node &> /dev/null; then
    curl -sL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
    log "Node.js và NPM đã được cài đặt thành công"
else
    log "Node.js và NPM đã được cài đặt trước đó"
fi

# Cài đặt Certbot cho SSL
log "Bắt đầu cài đặt Certbot cho SSL..."
if ! command -v certbot &> /dev/null; then
    apt update
    apt install -y certbot python3-certbot-nginx
    log "Certbot đã được cài đặt thành công"
else
    log "Certbot đã được cài đặt trước đó"
fi

# Cài đặt Supervisor (để quản lý các queue của Laravel)
log "Bắt đầu cài đặt Supervisor..."
if ! command -v supervisorctl &> /dev/null; then
    apt update
    apt install -y supervisor
    systemctl enable supervisor
    systemctl start supervisor
    log "Supervisor đã được cài đặt thành công"
else
    log "Supervisor đã được cài đặt trước đó"
fi

# Cấu hình UFW (Uncomplicated Firewall)
log "Cấu hình UFW firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 'Nginx Full'
    ufw allow 'OpenSSH'
    echo "y" | ufw enable
    log "UFW đã được cấu hình thành công"
else
    apt install -y ufw
    ufw allow 'Nginx Full'
    ufw allow 'OpenSSH'
    echo "y" | ufw enable
    log "UFW đã được cài đặt và cấu hình thành công"
fi

echo -e "${GREEN}===== CÀI ĐẶT LARAVEL STACK HOÀN TẤT =====${NC}"
echo
echo -e "${YELLOW}Thông tin truy cập MariaDB:${NC}"
echo "Username: root"
echo "Password: password"
echo
echo -e "${YELLOW}Thông tin các dịch vụ đã cài đặt:${NC}"
echo "- Nginx"
echo "- PHP 8.1 + Extensions"
echo "- MariaDB"
echo "- Composer"
echo "- Redis"
echo "- Node.js & NPM"
echo "- Certbot (SSL)"
echo "- Supervisor"
echo "- UFW Firewall"
echo
echo -e "${YELLOW}Các port đã mở:${NC}"
echo "- 22 (SSH)"
echo "- 80 (HTTP)"
echo "- 443 (HTTPS)"
echo
echo -e "${GREEN}Để tạo site Laravel mới, sử dụng lệnh webestvps${NC}"
echo 