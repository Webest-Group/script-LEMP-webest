#!/bin/bash

# Màu sắc cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Vui lòng chạy script với quyền root (sudo)${NC}"
    exit 1
fi

# Các đường dẫn và biến
WEB_ROOT="/var/www"
PANEL_VERSION="1.0.0"
PANEL_SCRIPT="/usr/local/bin/webestvps"

# Hàm ghi log
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Hàm kiểm tra lỗi
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Lỗi: $1${NC}"
        exit 1
    fi
}

# Hàm sửa lỗi apt
fix_apt() {
    log "Đang sửa lỗi apt..."
    apt-get clean
    apt-get update
    apt-get install -f -y
    dpkg --configure -a
}

# Hàm cài đặt các gói cần thiết
install_dependencies() {
    log "Đang cài đặt các gói cần thiết..."
    
    # Cập nhật hệ thống
    apt-get update
    apt-get upgrade -y
    
    # Cài đặt các gói cơ bản
    apt-get install -y curl wget git unzip
    
    # Cài đặt Nginx
    apt-get install -y nginx
    
    # Cài đặt MariaDB
    apt-get install -y mariadb-server mariadb-client
    
    # Cài đặt PHP 8.1 và các module cần thiết
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt-get update
    apt-get install -y php8.1-fpm php8.1-mysql php8.1-curl php8.1-gd php8.1-mbstring php8.1-xml php8.1-zip php8.1-intl
    
    # Cài đặt Redis
    apt-get install -y redis-server
    
    # Cài đặt Supervisor
    apt-get install -y supervisor
}

# Hàm tạo script webestvps
create_webestvps_script() {
    log "Đang tạo script webestvps..."
    
    cat > "$PANEL_SCRIPT" << 'EOF_PANEL_SCRIPT'
#!/bin/bash

# Màu sắc cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Các đường dẫn
WEB_ROOT="/var/www"
NGINX_CONF="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
MYSQL_ROOT_PASS="$(cat /root/.my.cnf | grep password | cut -d'=' -f2)"

# Hàm ghi log
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Hàm kiểm tra lỗi
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Lỗi: $1${NC}"
        return 1
    fi
}

# Hàm tạo domain
create_domain() {
    read -p "Nhập tên domain: " domain
    if [ -z "$domain" ]; then
        echo -e "${RED}Tên domain không được để trống${NC}"
        return 1
    fi
    
    # Tạo thư mục cho domain
    mkdir -p "$WEB_ROOT/$domain/public_html"
    chown -R www-data:www-data "$WEB_ROOT/$domain"
    chmod -R 755 "$WEB_ROOT/$domain"
    
    # Tạo file cấu hình Nginx
    cat > "$NGINX_CONF/$domain" << EOF
server {
    listen 80;
    server_name $domain www.$domain;
    root $WEB_ROOT/$domain/public_html;
    index index.php index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF
    
    # Kích hoạt site
    ln -sf "$NGINX_CONF/$domain" "$NGINX_ENABLED/"
    nginx -t && systemctl reload nginx
    
    log "Đã tạo domain $domain thành công"
}

# Hàm cài đặt SSL
install_ssl() {
    read -p "Nhập tên domain cần cài SSL: " domain
    if [ -z "$domain" ]; then
        echo -e "${RED}Tên domain không được để trống${NC}"
        return 1
    fi
    
    # Cài đặt Certbot
    apt-get install -y certbot python3-certbot-nginx
    
    # Cài đặt SSL
    certbot --nginx -d $domain -d www.$domain
    
    log "Đã cài đặt SSL cho $domain thành công"
}

# Hàm tạo database
create_database() {
    read -p "Nhập tên database: " dbname
    read -p "Nhập tên user: " dbuser
    read -s -p "Nhập mật khẩu: " dbpass
    echo
    
    # Tạo database và user
    mysql -e "CREATE DATABASE $dbname;"
    mysql -e "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';"
    mysql -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
    
    log "Đã tạo database $dbname thành công"
}

# Hàm backup
backup() {
    read -p "Nhập tên domain cần backup: " domain
    if [ -z "$domain" ]; then
        echo -e "${RED}Tên domain không được để trống${NC}"
        return 1
    fi
    
    # Tạo thư mục backup
    mkdir -p "$WEB_ROOT/backups"
    
    # Backup files
    tar -czf "$WEB_ROOT/backups/${domain}_$(date +%Y%m%d).tar.gz" "$WEB_ROOT/$domain"
    
    # Backup database
    dbname=$(grep -o "database_name.*" "$WEB_ROOT/$domain/public_html/wp-config.php" | cut -d"'" -f4)
    if [ ! -z "$dbname" ]; then
        mysqldump $dbname > "$WEB_ROOT/backups/${dbname}_$(date +%Y%m%d).sql"
    fi
    
    log "Đã backup $domain thành công"
}

# Hàm quản lý service
manage_service() {
    echo "1. Khởi động service"
    echo "2. Dừng service"
    echo "3. Khởi động lại service"
    echo "4. Kiểm tra trạng thái service"
    read -p "Chọn tác vụ: " choice
    
    case $choice in
        1) systemctl start $1 ;;
        2) systemctl stop $1 ;;
        3) systemctl restart $1 ;;
        4) systemctl status $1 ;;
        *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
    esac
}

# Hàm cài đặt Laravel
install_laravel() {
    read -p "Nhập tên domain: " domain
    if [ -z "$domain" ]; then
        echo -e "${RED}Tên domain không được để trống${NC}"
        return 1
    fi
    
    # Cài đặt Composer
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    
    # Tạo project Laravel
    composer create-project --prefer-dist laravel/laravel "$WEB_ROOT/$domain"
    
    # Cấu hình quyền
    chown -R www-data:www-data "$WEB_ROOT/$domain"
    chmod -R 755 "$WEB_ROOT/$domain"
    
    # Cấu hình Nginx
    cat > "$NGINX_CONF/$domain" << EOF
server {
    listen 80;
    server_name $domain www.$domain;
    root $WEB_ROOT/$domain/public;
    
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    
    index index.php;
    
    charset utf-8;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
    
    error_page 404 /index.php;
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF
    
    # Kích hoạt site
    ln -sf "$NGINX_CONF/$domain" "$NGINX_ENABLED/"
    nginx -t && systemctl reload nginx
    
    log "Đã cài đặt Laravel cho $domain thành công"
}

# Menu chính
while true; do
    echo -e "\n${YELLOW}=== WebEST VPS Panel ===${NC}"
    echo "1. Tạo domain"
    echo "2. Cài đặt SSL"
    echo "3. Tạo database"
    echo "4. Backup"
    echo "5. Quản lý service"
    echo "6. Cài đặt Laravel"
    echo "7. Thoát"
    
    read -p "Chọn tác vụ: " choice
    
    case $choice in
        1) create_domain ;;
        2) install_ssl ;;
        3) create_database ;;
        4) backup ;;
        5)
            echo "1. Nginx"
            echo "2. PHP-FPM"
            echo "3. MariaDB"
            echo "4. Redis"
            read -p "Chọn service: " service_choice
            case $service_choice in
                1) manage_service nginx ;;
                2) manage_service php8.1-fpm ;;
                3) manage_service mariadb ;;
                4) manage_service redis-server ;;
                *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
            esac
            ;;
        6) install_laravel ;;
        7) exit 0 ;;
        *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
    esac
done
EOF_PANEL_SCRIPT

    chmod +x "$PANEL_SCRIPT"
    log "Đã tạo script webestvps thành công"
}

# Hàm cấu hình các service
configure_services() {
    log "Đang cấu hình các service..."
    
    # Cấu hình Nginx
    mkdir -p "$WEB_ROOT/default"
    echo "<h1>Welcome to WebEST VPS</h1>" > "$WEB_ROOT/default/index.html"
    
    # Backup cấu hình Nginx mặc định
    if [ -f "/etc/nginx/sites-available/default" ]; then
        mv "/etc/nginx/sites-available/default" "/etc/nginx/sites-available/default.bak"
    fi
    
    # Tạo cấu hình Nginx mới
    cat > "/etc/nginx/sites-available/default" << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root $WEB_ROOT/default;
    index index.html index.htm index.nginx-debian.html;
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    
    # Khởi động lại Nginx
    systemctl restart nginx
    nginx -t
    
    # Cấu hình MariaDB
    if [ ! -f "/root/.my.cnf" ]; then
        mysql_secure_installation
    fi
    
    # Cấu hình PHP
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' /etc/php/8.1/fpm/php.ini
    sed -i 's/post_max_size = 8M/post_max_size = 64M/' /etc/php/8.1/fpm/php.ini
    sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.1/fpm/php.ini
    sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/8.1/fpm/php.ini
    
    systemctl restart php8.1-fpm
}

# Hàm kiểm tra cài đặt
check_installation() {
    log "Đang kiểm tra cài đặt..."
    
    # Kiểm tra các service
    services=("nginx" "php8.1-fpm" "mariadb" "redis-server" "supervisor")
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet $service; then
            echo -e "${RED}Service $service không hoạt động${NC}"
            return 1
        fi
    done
    
    # Kiểm tra file webestvps
    if [ ! -f "$PANEL_SCRIPT" ]; then
        echo -e "${RED}File webestvps không tồn tại${NC}"
        return 1
    fi
    
    # Kiểm tra symlink
    if [ ! -L "/usr/bin/webestvps" ]; then
        ln -s "$PANEL_SCRIPT" "/usr/bin/webestvps"
    fi
    
    # Kiểm tra cấu hình Nginx
    if ! nginx -t; then
        echo -e "${RED}Cấu hình Nginx có lỗi${NC}"
        return 1
    fi
    
    # Kiểm tra kết nối MariaDB
    if ! mysql -e "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${RED}Không thể kết nối đến MariaDB${NC}"
        return 1
    fi
    
    log "Kiểm tra cài đặt hoàn tất"
    return 0
}

# Thực hiện cài đặt
log "Bắt đầu cài đặt WebEST VPS Panel..."

# Sửa lỗi apt
fix_apt

# Cài đặt các gói cần thiết
install_dependencies

# Tạo script webestvps
create_webestvps_script

# Cấu hình các service
configure_services

# Kiểm tra cài đặt
if check_installation; then
    echo -e "\n${GREEN}=== Cài đặt WebEST VPS Panel thành công ===${NC}"
    echo -e "Phiên bản: $PANEL_VERSION"
    echo -e "Để sử dụng panel, gõ lệnh: ${YELLOW}webestvps${NC}"
else
    echo -e "\n${RED}=== Cài đặt WebEST VPS Panel thất bại ===${NC}"
    echo -e "Vui lòng kiểm tra log và thử lại"
    exit 1
fi 