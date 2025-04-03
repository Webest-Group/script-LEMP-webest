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

# Kiểm tra OS
if [[ -f /etc/lsb-release ]]; then
    os_version=$(lsb_release -rs)
    if [[ "$os_version" != "22.04" ]]; then
        echo -e "${RED}Script này chỉ hỗ trợ Ubuntu 22.04${NC}"
        exit 1
    fi
else
    echo -e "${RED}Script này chỉ hỗ trợ Ubuntu 22.04${NC}"
    exit 1
fi

# Tạo thư mục cài đặt và logs
INSTALL_DIR="/opt/webestvps"
CONFIG_DIR="/etc/webestvps"
LOG_DIR="/var/log/webestvps"
WEB_ROOT="/home/websites"
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR" "$WEB_ROOT"

# Log file
LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"

# Function ghi log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

echo -e "${GREEN}=== BẮT ĐẦU CÀI ĐẶT WEBEST VPS PANEL ===${NC}"
echo

# Sửa lỗi dpkg bị gián đoạn
log "Kiểm tra và sửa lỗi dpkg..."
dpkg --configure -a

# Cập nhật hệ thống
log "Đang cập nhật hệ thống..."
apt update
apt upgrade -y

# 1. Cài đặt Nginx
log "Đang cài đặt Nginx..."
apt install -y nginx
systemctl enable nginx
systemctl start nginx

# 2. Cài đặt PHP và các extension
log "Đang cài đặt PHP và các extension..."
apt install -y software-properties-common
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
apt update
apt install -y php8.1-fpm php8.1-cli php8.1-common php8.1-mysql php8.1-zip \
    php8.1-gd php8.1-mbstring php8.1-curl php8.1-xml php8.1-bcmath php8.1-intl

# Cấu hình PHP
PHP_INI="/etc/php/8.1/fpm/php.ini"
if [ -f "$PHP_INI" ]; then
    sed -i 's/memory_limit = .*/memory_limit = 256M/' "$PHP_INI"
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' "$PHP_INI"
    sed -i 's/post_max_size = .*/post_max_size = 64M/' "$PHP_INI"
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
    sed -i 's/;date.timezone.*/date.timezone = Asia\/Ho_Chi_Minh/' "$PHP_INI"
fi

systemctl enable php8.1-fpm
systemctl restart php8.1-fpm

# 3. Cài đặt MariaDB
log "Đang cài đặt MariaDB..."
apt install -y mariadb-server mariadb-client

# Đảm bảo MariaDB đang chạy
systemctl enable mariadb
systemctl start mariadb

# Bảo mật MariaDB và đặt mật khẩu root
mysql -e "UPDATE mysql.user SET Password = PASSWORD('webest@2024') WHERE User = 'root'"
mysql -e "DELETE FROM mysql.user WHERE User=''"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
mysql -e "DROP DATABASE IF EXISTS test"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
mysql -e "FLUSH PRIVILEGES"

# 4. Cài đặt Redis
log "Đang cài đặt Redis..."
apt install -y redis-server php8.1-redis
systemctl enable redis-server
systemctl start redis-server

# 5. Cài đặt Composer
log "Đang cài đặt Composer..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# 6. Cài đặt Node.js và NPM
log "Đang cài đặt Node.js và NPM..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# 7. Cài đặt Certbot (Let's Encrypt)
log "Đang cài đặt Certbot..."
apt install -y certbot python3-certbot-nginx

# 8. Cài đặt các công cụ bảo mật
log "Đang cài đặt các công cụ bảo mật..."
apt install -y ufw fail2ban

# Cấu hình UFW
ufw --force enable
ufw allow ssh
ufw allow http
ufw allow https

# Cấu hình Fail2ban
if [ -f "/etc/fail2ban/jail.conf" ]; then
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
fi
systemctl enable fail2ban
systemctl start fail2ban

# 9. Cài đặt Supervisor
log "Đang cài đặt Supervisor..."
apt install -y supervisor
systemctl enable supervisor
systemctl start supervisor

# 10. Cài đặt các công cụ hữu ích khác
log "Đang cài đặt các công cụ hữu ích..."
apt install -y zip unzip git curl wget htop

# Tạo thư mục web mặc định và phân quyền
mkdir -p "$WEB_ROOT"
chown -R www-data:www-data "$WEB_ROOT"
chmod -R 755 "$WEB_ROOT"

# Tạo thư mục cho domain mặc định
mkdir -p "$WEB_ROOT/default"

# Cấu hình Nginx mặc định
cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root $WEB_ROOT/default;
    index index.php index.html index.htm;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF

# Tạo symbolic link cho cấu hình Nginx
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/

# Khởi động lại Nginx
systemctl restart nginx

# Tạo trang chào mừng
cat > "$WEB_ROOT/default/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to WebEST VPS</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 40px;
            background: #f4f4f4;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
        }
        .success {
            color: #28a745;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to WebEST VPS</h1>
        <p class="success">✅ Server đã được cài đặt thành công!</p>
        <p>Các thành phần đã được cài đặt:</p>
        <ul>
            <li>Nginx</li>
            <li>PHP 8.1</li>
            <li>MariaDB</li>
            <li>Redis</li>
            <li>Composer</li>
            <li>Node.js & NPM</li>
            <li>Certbot (SSL)</li>
            <li>UFW & Fail2ban</li>
            <li>Supervisor</li>
        </ul>
        <p>Để quản lý server, sử dụng lệnh: <strong>webestvps</strong></p>
    </div>
</body>
</html>
EOF

# Phân quyền cho trang chào mừng
chown -R www-data:www-data "$WEB_ROOT/default"

# Tạo file version
echo "1.0.0" > "$CONFIG_DIR/version"
touch "$CONFIG_DIR/installed"

echo -e "${GREEN}=== CÀI ĐẶT HOÀN TẤT ===${NC}"
echo
echo -e "${YELLOW}Thông tin quan trọng:${NC}"
echo "- MariaDB Root Password: webest@2024"
echo "- Thư mục web root: $WEB_ROOT"
echo "- Các port đã mở: 22 (SSH), 80 (HTTP), 443 (HTTPS)"
echo "- Thư mục cấu hình: $CONFIG_DIR"
echo "- Thư mục logs: $LOG_DIR"
echo
echo -e "${GREEN}Bạn có thể truy cập IP server để xem trang chào mừng${NC}"
echo -e "${GREEN}Sử dụng lệnh 'webestvps' để quản lý server${NC}"
echo

# Hiển thị IP của server
echo -e "${YELLOW}IP của server:${NC}"
ip addr show | grep -w inet | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1 