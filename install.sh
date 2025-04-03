#!/bin/bash

# Màu sắc cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Script này cần chạy với quyền root${NC}"
    exit 1
fi

# Các đường dẫn
INSTALL_DIR="/opt/webestvps"
CONFIG_DIR="/etc/webestvps"
LOG_DIR="/var/log/webestvps"
WEB_ROOT="/home/websites"
REPO_URL="https://github.com/webestvps/script-lemp.git"
TEMP_DIR="/tmp/webestvps_install"

# Function ghi log
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/install.log"
}

# Function kiểm tra lỗi
check_error() {
    if [ $? -ne 0 ]; then
        log "${RED}Lỗi: $1${NC}"
        exit 1
    fi
}

# Function sửa lỗi apt
fix_apt() {
    log "Đang sửa lỗi apt..."
    
    # Xóa các file lock
    rm -f /var/lib/apt/lists/lock
    rm -f /var/cache/apt/archives/lock
    rm -f /var/lib/dpkg/lock*
    
    # Cấu hình dpkg
    dpkg --configure -a
    
    # Cập nhật và nâng cấp
    apt update
    apt upgrade -y
    
    # Cài đặt lại các gói cần thiết
    apt install -y ubuntu-advantage-tools python3-software-properties
    
    check_error "Không thể sửa lỗi apt"
    log "${GREEN}Đã sửa lỗi apt thành công${NC}"
}

# Function sửa lỗi repository
fix_repository() {
    log "Đang sửa lỗi repository..."
    
    # Backup sources.list
    cp /etc/apt/sources.list /etc/apt/sources.list.backup
    
    # Tạo sources.list mới
    cat > /etc/apt/sources.list << EOF
deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
EOF
    
    # Cập nhật
    apt update
    
    check_error "Không thể sửa lỗi repository"
    log "${GREEN}Đã sửa lỗi repository thành công${NC}"
}

# Function sửa lỗi network
fix_network() {
    log "Đang sửa lỗi network..."
    
    # Kiểm tra kết nối internet
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        # Khởi động lại network
        systemctl restart networking
        systemctl restart systemd-networkd
    fi
    
    # Sửa lỗi DNS
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 8.8.4.4" >> /etc/resolv.conf
    
    check_error "Không thể sửa lỗi network"
    log "${GREEN}Đã sửa lỗi network thành công${NC}"
}

# Function kiểm tra gói đã cài đặt
check_package() {
    local pkg=$1
    if dpkg -l | grep -q "^ii  $pkg "; then
        log "${GREEN}Gói $pkg đã được cài đặt${NC}"
        return 0
    else
        log "${YELLOW}Gói $pkg chưa được cài đặt${NC}"
        return 1
    fi
}

# Function kiểm tra service
check_service() {
    local service=$1
    if systemctl is-active --quiet "$service"; then
        log "${GREEN}Service $service đang hoạt động${NC}"
        return 0
    else
        log "${YELLOW}Service $service không hoạt động${NC}"
        return 1
    fi
}

# Function cài đặt các gói cần thiết
install_dependencies() {
    log "Đang kiểm tra và cài đặt các gói cần thiết..."
    
    # Cập nhật apt
    apt update
    
    # Danh sách các gói cần thiết
    local base_packages=(
        git
        curl
        wget
        unzip
        software-properties-common
        apt-transport-https
        ca-certificates
        gnupg
    )
    
    local lemp_packages=(
        nginx
        php8.1-fpm
        php8.1-cli
        php8.1-common
        php8.1-mysql
        php8.1-zip
        php8.1-gd
        php8.1-mbstring
        php8.1-curl
        php8.1-xml
        php8.1-bcmath
        php8.1-intl
        mariadb-server
        redis-server
    )
    
    # Cài đặt các gói cơ bản
    log "Đang cài đặt các gói cơ bản..."
    for pkg in "${base_packages[@]}"; do
        if ! check_package "$pkg"; then
            apt install -y "$pkg"
            check_error "Không thể cài đặt gói $pkg"
        fi
    done
    
    # Thêm repository PHP 8.1 nếu chưa có
    if ! apt-cache policy | grep -q "ondrej/php"; then
        log "Thêm repository PHP 8.1..."
        add-apt-repository -y ppa:ondrej/php
        apt update
    fi
    
    # Cài đặt LEMP stack
    log "Đang cài đặt LEMP stack..."
    for pkg in "${lemp_packages[@]}"; do
        if ! check_package "$pkg"; then
            apt install -y "$pkg"
            check_error "Không thể cài đặt gói $pkg"
        fi
    done
    
    # Cài đặt Composer nếu chưa có
    if ! command -v composer &> /dev/null; then
        log "${YELLOW}Đang cài đặt Composer...${NC}"
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
        check_error "Không thể cài đặt Composer"
    else
        log "${GREEN}Composer đã được cài đặt${NC}"
    fi
    
    # Cài đặt Node.js và npm nếu chưa có
    if ! command -v node &> /dev/null; then
        log "${YELLOW}Đang cài đặt Node.js...${NC}"
        if ! check_package "nodejs"; then
            curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
            apt install -y nodejs
            check_error "Không thể cài đặt Node.js"
        fi
    else
        log "${GREEN}Node.js đã được cài đặt${NC}"
    fi
    
    # Cài đặt Certbot nếu chưa có
    if ! command -v certbot &> /dev/null; then
        log "${YELLOW}Đang cài đặt Certbot...${NC}"
        apt install -y certbot python3-certbot-nginx
        check_error "Không thể cài đặt Certbot"
    else
        log "${GREEN}Certbot đã được cài đặt${NC}"
    fi
    
    # Cài đặt Supervisor nếu chưa có
    if ! check_package "supervisor"; then
        apt install -y supervisor
        check_error "Không thể cài đặt Supervisor"
    fi
    
    # Kiểm tra các service
    local services=(nginx php8.1-fpm mariadb redis-server)
    for service in "${services[@]}"; do
        if ! check_service "$service"; then
            systemctl start "$service"
            systemctl enable "$service"
            check_error "Không thể khởi động service $service"
        fi
    done
    
    log "${GREEN}Đã cài đặt và cấu hình tất cả các gói cần thiết thành công${NC}"
}

# Function tạo file webestvps
create_webestvps_script() {
    log "Đang tạo file webestvps..."
    
    # Tạo thư mục cài đặt nếu chưa tồn tại
    mkdir -p "$INSTALL_DIR"
    
    # Tạo file webestvps
    cat > "$INSTALL_DIR/webestvps" << 'EOF'
#!/bin/bash

# Màu sắc cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Script này cần chạy với quyền root${NC}"
    exit 1
fi

# Các đường dẫn
INSTALL_DIR="/opt/webestvps"
CONFIG_DIR="/etc/webestvps"
LOG_DIR="/var/log/webestvps"
WEB_ROOT="/home/websites"

# Function ghi log
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/webestvps.log"
}

# Function kiểm tra lỗi
check_error() {
    if [ $? -ne 0 ]; then
        log "${RED}Lỗi: $1${NC}"
        return 1
    fi
    return 0
}

# Function quản lý domain
manage_domain() {
    clear
    echo -e "${GREEN}=== QUẢN LÝ DOMAIN ===${NC}"
    echo "1) Thêm domain"
    echo "2) Xóa domain"
    echo "3) Liệt kê domain"
    echo "4) Quay lại"
    echo
    echo -n "Nhập lựa chọn của bạn [1-4]: "
    read -r choice
    
    case $choice in
        1)
            echo -n "Nhập tên domain: "
            read -r domain
            echo -n "Nhập đường dẫn thư mục web: "
            read -r web_path
            
            # Tạo thư mục web
            mkdir -p "$WEB_ROOT/$web_path"
            chown -R www-data:www-data "$WEB_ROOT/$web_path"
            
            # Tạo cấu hình Nginx
            cat > "/etc/nginx/sites-available/$domain" << EOF
server {
    listen 80;
    server_name $domain;
    
    root $WEB_ROOT/$web_path;
    index index.html index.htm index.php;
    
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
            
            # Kích hoạt cấu hình
            ln -sf "/etc/nginx/sites-available/$domain" "/etc/nginx/sites-enabled/$domain"
            nginx -t && systemctl reload nginx
            
            echo -e "${GREEN}Đã thêm domain $domain thành công${NC}"
            ;;
        2)
            echo -n "Nhập tên domain cần xóa: "
            read -r domain
            
            # Xóa cấu hình Nginx
            rm -f "/etc/nginx/sites-enabled/$domain"
            rm -f "/etc/nginx/sites-available/$domain"
            nginx -t && systemctl reload nginx
            
            echo -e "${GREEN}Đã xóa domain $domain thành công${NC}"
            ;;
        3)
            echo -e "${GREEN}Danh sách domain:${NC}"
            ls -la /etc/nginx/sites-enabled/ | grep -v "default" | awk '{print $9}'
            ;;
        4)
            return
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            ;;
    esac
    
    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
}

# Function quản lý SSL
manage_ssl() {
    clear
    echo -e "${GREEN}=== QUẢN LÝ SSL ===${NC}"
    echo "1) Cài đặt SSL cho domain"
    echo "2) Gia hạn SSL"
    echo "3) Liệt kê SSL"
    echo "4) Xóa SSL"
    echo "5) Quay lại"
    echo
    echo -n "Nhập lựa chọn của bạn [1-5]: "
    read -r choice
    
    case $choice in
        1)
            echo -n "Nhập tên domain: "
            read -r domain
            
            # Cài đặt SSL với Certbot
            certbot --nginx -d "$domain" --non-interactive --agree-tos --email admin@$domain
            
            echo -e "${GREEN}Đã cài đặt SSL cho domain $domain thành công${NC}"
            ;;
        2)
            # Gia hạn tất cả SSL
            certbot renew --dry-run
            
            echo -e "${GREEN}Đã gia hạn SSL thành công${NC}"
            ;;
        3)
            # Liệt kê SSL
            certbot certificates
            
            echo -e "${GREEN}Đã liệt kê SSL thành công${NC}"
            ;;
        4)
            echo -n "Nhập tên domain: "
            read -r domain
            
            # Xóa SSL
            certbot delete --cert-name "$domain"
            
            echo -e "${GREEN}Đã xóa SSL cho domain $domain thành công${NC}"
            ;;
        5)
            return
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            ;;
    esac
    
    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
}

# Function quản lý database
manage_database() {
    clear
    echo -e "${GREEN}=== QUẢN LÝ DATABASE ===${NC}"
    echo "1) Tạo database"
    echo "2) Xóa database"
    echo "3) Liệt kê database"
    echo "4) Tạo user database"
    echo "5) Xóa user database"
    echo "6) Liệt kê user database"
    echo "7) Quay lại"
    echo
    echo -n "Nhập lựa chọn của bạn [1-7]: "
    read -r choice
    
    case $choice in
        1)
            echo -n "Nhập tên database: "
            read -r dbname
            
            # Tạo database
            mysql -e "CREATE DATABASE \`$dbname\`;"
            
            echo -e "${GREEN}Đã tạo database $dbname thành công${NC}"
            ;;
        2)
            echo -n "Nhập tên database cần xóa: "
            read -r dbname
            
            # Xóa database
            mysql -e "DROP DATABASE \`$dbname\`;"
            
            echo -e "${GREEN}Đã xóa database $dbname thành công${NC}"
            ;;
        3)
            # Liệt kê database
            mysql -e "SHOW DATABASES;"
            
            echo -e "${GREEN}Đã liệt kê database thành công${NC}"
            ;;
        4)
            echo -n "Nhập tên user: "
            read -r username
            echo -n "Nhập mật khẩu: "
            read -r password
            
            # Tạo user
            mysql -e "CREATE USER '$username'@'localhost' IDENTIFIED BY '$password';"
            
            echo -e "${GREEN}Đã tạo user $username thành công${NC}"
            ;;
        5)
            echo -n "Nhập tên user cần xóa: "
            read -r username
            
            # Xóa user
            mysql -e "DROP USER '$username'@'localhost';"
            mysql -e "FLUSH PRIVILEGES;"
            
            echo -e "${GREEN}Đã xóa user $username thành công${NC}"
            ;;
        6)
            # Liệt kê user
            mysql -e "SELECT User, Host FROM mysql.user;"
            
            echo -e "${GREEN}Đã liệt kê user thành công${NC}"
            ;;
        7)
            return
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            ;;
    esac
    
    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
}

# Function quản lý backup
manage_backup() {
    clear
    echo -e "${GREEN}=== QUẢN LÝ BACKUP ===${NC}"
    echo "1) Backup website"
    echo "2) Backup database"
    echo "3) Restore website"
    echo "4) Restore database"
    echo "5) Liệt kê backup"
    echo "6) Quay lại"
    echo
    echo -n "Nhập lựa chọn của bạn [1-6]: "
    read -r choice
    
    case $choice in
        1)
            echo -n "Nhập tên domain: "
            read -r domain
            echo -n "Nhập đường dẫn thư mục web: "
            read -r web_path
            
            # Tạo thư mục backup
            mkdir -p "$INSTALL_DIR/backups"
            
            # Backup website
            tar -czf "$INSTALL_DIR/backups/${domain}_$(date +%Y%m%d_%H%M%S).tar.gz" -C "$WEB_ROOT" "$web_path"
            
            echo -e "${GREEN}Đã backup website $domain thành công${NC}"
            ;;
        2)
            echo -n "Nhập tên database: "
            read -r dbname
            
            # Tạo thư mục backup
            mkdir -p "$INSTALL_DIR/backups"
            
            # Backup database
            mysqldump -u root "$dbname" > "$INSTALL_DIR/backups/${dbname}_$(date +%Y%m%d_%H%M%S).sql"
            
            echo -e "${GREEN}Đã backup database $dbname thành công${NC}"
            ;;
        3)
            echo -n "Nhập tên file backup: "
            read -r backup_file
            echo -n "Nhập đường dẫn thư mục web: "
            read -r web_path
            
            # Restore website
            tar -xzf "$INSTALL_DIR/backups/$backup_file" -C "$WEB_ROOT"
            
            echo -e "${GREEN}Đã restore website thành công${NC}"
            ;;
        4)
            echo -n "Nhập tên file backup: "
            read -r backup_file
            echo -n "Nhập tên database: "
            read -r dbname
            
            # Restore database
            mysql -u root "$dbname" < "$INSTALL_DIR/backups/$backup_file"
            
            echo -e "${GREEN}Đã restore database $dbname thành công${NC}"
            ;;
        5)
            # Liệt kê backup
            ls -la "$INSTALL_DIR/backups"
            
            echo -e "${GREEN}Đã liệt kê backup thành công${NC}"
            ;;
        6)
            return
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            ;;
    esac
    
    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
}

# Function quản lý service
manage_service() {
    clear
    echo -e "${GREEN}=== QUẢN LÝ SERVICE ===${NC}"
    echo "1) Khởi động service"
    echo "2) Dừng service"
    echo "3) Khởi động lại service"
    echo "4) Kiểm tra trạng thái service"
    echo "5) Quay lại"
    echo
    echo -n "Nhập lựa chọn của bạn [1-5]: "
    read -r choice
    
    case $choice in
        1)
            echo "1) Nginx"
            echo "2) PHP-FPM"
            echo "3) MariaDB"
            echo "4) Redis"
            echo "5) Tất cả"
            echo
            echo -n "Nhập lựa chọn của bạn [1-5]: "
            read -r service_choice
            
            case $service_choice in
                1) systemctl start nginx ;;
                2) systemctl start php8.1-fpm ;;
                3) systemctl start mariadb ;;
                4) systemctl start redis-server ;;
                5)
                    systemctl start nginx
                    systemctl start php8.1-fpm
                    systemctl start mariadb
                    systemctl start redis-server
                    ;;
                *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
            esac
            
            echo -e "${GREEN}Đã khởi động service thành công${NC}"
            ;;
        2)
            echo "1) Nginx"
            echo "2) PHP-FPM"
            echo "3) MariaDB"
            echo "4) Redis"
            echo "5) Tất cả"
            echo
            echo -n "Nhập lựa chọn của bạn [1-5]: "
            read -r service_choice
            
            case $service_choice in
                1) systemctl stop nginx ;;
                2) systemctl stop php8.1-fpm ;;
                3) systemctl stop mariadb ;;
                4) systemctl stop redis-server ;;
                5)
                    systemctl stop nginx
                    systemctl stop php8.1-fpm
                    systemctl stop mariadb
                    systemctl stop redis-server
                    ;;
                *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
            esac
            
            echo -e "${GREEN}Đã dừng service thành công${NC}"
            ;;
        3)
            echo "1) Nginx"
            echo "2) PHP-FPM"
            echo "3) MariaDB"
            echo "4) Redis"
            echo "5) Tất cả"
            echo
            echo -n "Nhập lựa chọn của bạn [1-5]: "
            read -r service_choice
            
            case $service_choice in
                1) systemctl restart nginx ;;
                2) systemctl restart php8.1-fpm ;;
                3) systemctl restart mariadb ;;
                4) systemctl restart redis-server ;;
                5)
                    systemctl restart nginx
                    systemctl restart php8.1-fpm
                    systemctl restart mariadb
                    systemctl restart redis-server
                    ;;
                *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
            esac
            
            echo -e "${GREEN}Đã khởi động lại service thành công${NC}"
            ;;
        4)
            echo "1) Nginx"
            echo "2) PHP-FPM"
            echo "3) MariaDB"
            echo "4) Redis"
            echo "5) Tất cả"
            echo
            echo -n "Nhập lựa chọn của bạn [1-5]: "
            read -r service_choice
            
            case $service_choice in
                1) systemctl status nginx ;;
                2) systemctl status php8.1-fpm ;;
                3) systemctl status mariadb ;;
                4) systemctl status redis-server ;;
                5)
                    systemctl status nginx
                    systemctl status php8.1-fpm
                    systemctl status mariadb
                    systemctl status redis-server
                    ;;
                *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
            esac
            
            echo -e "${GREEN}Đã kiểm tra trạng thái service thành công${NC}"
            ;;
        5)
            return
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            ;;
    esac
    
    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
}

# Function cài đặt Laravel
install_laravel() {
    clear
    echo -e "${GREEN}=== CÀI ĐẶT LARAVEL ===${NC}"
    echo -n "Nhập tên project: "
    read -r project_name
    echo -n "Nhập đường dẫn thư mục web: "
    read -r web_path
    
    # Tạo thư mục web
    mkdir -p "$WEB_ROOT/$web_path"
    cd "$WEB_ROOT/$web_path"
    
    # Cài đặt Laravel
    composer create-project laravel/laravel .
    
    # Phân quyền
    chown -R www-data:www-data .
    chmod -R 755 .
    chmod -R 777 storage bootstrap/cache
    
    echo -e "${GREEN}Đã cài đặt Laravel thành công${NC}"
    echo -e "Bạn có thể truy cập Laravel tại: http://$(hostname -I | awk '{print $1}')/$web_path"
    
    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
}

# Function hiển thị thông tin server
show_server_info() {
    clear
    echo -e "${GREEN}=== THÔNG TIN SERVER ===${NC}"
    
    # Thông tin hệ thống
    echo -e "${YELLOW}Thông tin hệ thống:${NC}"
    uname -a
    
    # Thông tin CPU
    echo -e "${YELLOW}Thông tin CPU:${NC}"
    lscpu | grep "Model name"
    
    # Thông tin RAM
    echo -e "${YELLOW}Thông tin RAM:${NC}"
    free -h
    
    # Thông tin ổ đĩa
    echo -e "${YELLOW}Thông tin ổ đĩa:${NC}"
    df -h
    
    # Thông tin IP
    echo -e "${YELLOW}Thông tin IP:${NC}"
    hostname -I
    
    # Thông tin các service
    echo -e "${YELLOW}Trạng thái các service:${NC}"
    systemctl status nginx | grep "Active:"
    systemctl status php8.1-fpm | grep "Active:"
    systemctl status mariadb | grep "Active:"
    systemctl status redis-server | grep "Active:"
    
    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
}

# Function cập nhật panel
update_panel() {
    clear
    echo -e "${GREEN}=== CẬP NHẬT PANEL ===${NC}"
    
    # Tạo thư mục tạm
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Clone repository
    git clone "$REPO_URL" .
    
    # Sao chép file webestvps
    cp -f webestvps "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/webestvps"
    
    # Cập nhật version
    if [ -f "$INSTALL_DIR/setup.sh" ]; then
        VERSION=$(grep "version=" "$INSTALL_DIR/setup.sh" | cut -d'"' -f2)
        echo "$VERSION" > "$CONFIG_DIR/version"
    fi
    
    # Xóa thư mục tạm
    cd /
    rm -rf "$TEMP_DIR"
    
    echo -e "${GREEN}Đã cập nhật panel thành công${NC}"
    
    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
}

# Function hiển thị menu
show_menu() {
    clear
    echo -e "${GREEN}=== WEBEST VPS PANEL ===${NC}"
    echo "1) Quản lý Domain"
    echo "2) Quản lý SSL"
    echo "3) Quản lý Database"
    echo "4) Quản lý Backup"
    echo "5) Quản lý Service"
    echo "6) Cài đặt Laravel"
    echo "7) Thông tin Server"
    echo "8) Cập nhật Panel"
    echo "0) Thoát"
    echo
    echo -n "Nhập lựa chọn của bạn [0-8]: "
    read -r choice
    
    case $choice in
        1) manage_domain ;;
        2) manage_ssl ;;
        3) manage_database ;;
        4) manage_backup ;;
        5) manage_service ;;
        6) install_laravel ;;
        7) show_server_info ;;
        8) update_panel ;;
        0)
            echo -e "${GREEN}Cảm ơn bạn đã sử dụng WebEST VPS Panel!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            ;;
    esac
}

# Main script
while true; do
    show_menu
done
EOF
    
    # Phân quyền thực thi
    chmod +x "$INSTALL_DIR/webestvps"
    
    # Tạo symbolic link
    ln -sf "$INSTALL_DIR/webestvps" /usr/local/bin/webestvps
    
    check_error "Không thể tạo file webestvps"
    log "${GREEN}Đã tạo file webestvps thành công${NC}"
}

# Function tải và cài đặt từ Git
install_from_git() {
    log "Đang tải mã nguồn từ Git..."
    
    # Tạo thư mục tạm
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Clone repository
    git clone "$REPO_URL" .
    check_error "Không thể clone repository"
    
    # Sao chép các file script
    cp -f setup.sh "$INSTALL_DIR/"
    cp -f laravel_install.sh "$INSTALL_DIR/"
    
    # Sao chép thư mục modules
    cp -rf modules "$INSTALL_DIR/"
    
    # Phân quyền thực thi
    chmod +x "$INSTALL_DIR/setup.sh"
    chmod +x "$INSTALL_DIR/laravel_install.sh"
    chmod +x "$INSTALL_DIR/modules"/*.sh
    
    # Xóa thư mục tạm
    cd /
    rm -rf "$TEMP_DIR"
    
    check_error "Không thể cài đặt từ Git"
    log "${GREEN}Đã cài đặt từ Git thành công${NC}"
}

# Function cấu hình các service
configure_services() {
    log "Đang cấu hình các service..."
    
    # Cấu hình Nginx
    if [ ! -f "/etc/nginx/sites-available/default" ]; then
        cat > "/etc/nginx/sites-available/default" << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    root $WEB_ROOT/default;
    index index.html index.htm index.php;
    
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
    fi
    
    # Tạo thư mục web root mặc định
    mkdir -p "$WEB_ROOT/default"
    echo "<?php phpinfo(); ?>" > "$WEB_ROOT/default/info.php"
    chown -R www-data:www-data "$WEB_ROOT/default"
    
    # Cấu hình PHP
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' /etc/php/8.1/fpm/php.ini
    sed -i 's/post_max_size = 8M/post_max_size = 64M/' /etc/php/8.1/fpm/php.ini
    sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.1/fpm/php.ini
    sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/8.1/fpm/php.ini
    
    # Cấu hình MariaDB
    mysql -e "CREATE DATABASE IF NOT EXISTS \`default\`;"
    mysql -e "CREATE USER IF NOT EXISTS 'default'@'localhost' IDENTIFIED BY 'default';"
    mysql -e "GRANT ALL PRIVILEGES ON \`default\`.* TO 'default'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
    
    # Khởi động lại các service
    systemctl restart nginx
    systemctl restart php8.1-fpm
    systemctl restart mariadb
    systemctl restart redis-server
    
    check_error "Không thể cấu hình các service"
    log "${GREEN}Đã cấu hình các service thành công${NC}"
}

# Function kiểm tra cài đặt
check_installation() {
    log "Đang kiểm tra cài đặt..."
    
    # Kiểm tra các thư mục
    if [ ! -d "$INSTALL_DIR" ] || [ ! -d "$CONFIG_DIR" ] || [ ! -d "$LOG_DIR" ] || [ ! -d "$WEB_ROOT" ]; then
        log "${RED}Lỗi: Các thư mục cần thiết chưa được tạo${NC}"
        return 1
    fi
    
    # Kiểm tra các file script
    if [ ! -f "$INSTALL_DIR/webestvps" ] || [ ! -f "$INSTALL_DIR/setup.sh" ] || [ ! -f "$INSTALL_DIR/laravel_install.sh" ]; then
        log "${RED}Lỗi: Các file script chưa được cài đặt${NC}"
        return 1
    fi
    
    # Kiểm tra các service
    if ! systemctl is-active --quiet nginx || ! systemctl is-active --quiet php8.1-fpm || ! systemctl is-active --quiet mariadb || ! systemctl is-active --quiet redis-server; then
        log "${RED}Lỗi: Các service chưa hoạt động${NC}"
        return 1
    fi
    
    # Kiểm tra lệnh webestvps
    if ! command -v webestvps &> /dev/null; then
        log "${RED}Lỗi: Lệnh webestvps chưa được cài đặt${NC}"
        return 1
    fi
    
    log "${GREEN}Kiểm tra cài đặt thành công${NC}"
    return 0
}

# Main script
echo -e "${GREEN}=== CÀI ĐẶT WEBEST VPS PANEL ===${NC}"
echo

# Tạo thư mục log nếu chưa tồn tại
mkdir -p "$LOG_DIR"

# Sửa lỗi network
fix_network

# Sửa lỗi apt
fix_apt

# Sửa lỗi repository
fix_repository

# Cài đặt các gói cần thiết
install_dependencies

# Tạo file webestvps
create_webestvps_script

# Tải và cài đặt từ Git
install_from_git

# Cấu hình các service
configure_services

# Kiểm tra cài đặt
if check_installation; then
    echo -e "${GREEN}Cài đặt WebEST VPS Panel hoàn tất!${NC}"
    echo -e "Bạn có thể sử dụng lệnh ${YELLOW}webestvps${NC} để mở panel quản lý."
else
    echo -e "${RED}Cài đặt WebEST VPS Panel thất bại!${NC}"
    echo -e "Vui lòng kiểm tra log tại ${YELLOW}$LOG_DIR/install.log${NC}"
    exit 1
fi 