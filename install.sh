#!/bin/bash

# Tao thu muc configs neu chua ton tai
mkdir -p configs

# Tai va tao cac file cau hinh
cat > configs/colors.sh << 'EOF_COLORS'
#!/bin/bash

# Mau sac cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
EOF_COLORS

cat > configs/paths.sh << 'EOF_PATHS'
#!/bin/bash

# Cac duong dan va bien
WEB_ROOT="/var/www"
PANEL_VERSION="1.0.0"
PANEL_SCRIPT="/usr/local/bin/webestvps"
NGINX_CONF="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
MYSQL_ROOT_PASS="$(cat /root/.my.cnf | grep password | cut -d'=' -f2)"
EOF_PATHS

cat > configs/functions.sh << 'EOF_FUNCTIONS'
#!/bin/bash

# Ham ghi log
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Ham kiem tra loi
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Loi: $1${NC}"
        exit 1
    fi
}

# Ham sua loi apt
fix_apt() {
    log "Dang sua loi apt..."
    apt-get clean
    apt-get update
    apt-get install -f -y
    dpkg --configure -a
}
EOF_FUNCTIONS

cat > configs/dependencies.sh << 'EOF_DEPENDENCIES'
#!/bin/bash

# Danh sach cac goi can cai dat
BASIC_PACKAGES=(
    "curl"
    "wget"
    "git"
    "unzip"
)

NGINX_PACKAGES=(
    "nginx"
)

MARIADB_PACKAGES=(
    "mariadb-server"
    "mariadb-client"
)

PHP_PACKAGES=(
    "software-properties-common"
    "php8.1-fpm"
    "php8.1-mysql"
    "php8.1-curl"
    "php8.1-gd"
    "php8.1-mbstring"
    "php8.1-xml"
    "php8.1-zip"
    "php8.1-intl"
)

OTHER_PACKAGES=(
    "redis-server"
    "supervisor"
)
EOF_DEPENDENCIES

cat > configs/services.sh << 'EOF_SERVICES'
#!/bin/bash

# Danh sach cac service can kiem tra
SERVICES=(
    "nginx"
    "php8.1-fpm"
    "mariadb"
    "redis-server"
    "supervisor"
)

# Ham quan ly service
manage_service() {
    echo "1. Khoi dong service"
    echo "2. Dung service"
    echo "3. Khoi dong lai service"
    echo "4. Kiem tra trang thai service"
    read -p "Chon tac vu: " choice
    
    case $choice in
        1) systemctl start $1 ;;
        2) systemctl stop $1 ;;
        3) systemctl restart $1 ;;
        4) systemctl status $1 ;;
        *) echo -e "${RED}Lua chon khong hop le${NC}" ;;
    esac
}
EOF_SERVICES

cat > configs/menu.sh << 'EOF_MENU'
#!/bin/bash

# Menu chinh
show_main_menu() {
    echo -e "\n${YELLOW}=== WebEST VPS Panel ===${NC}"
    echo "1. Tao domain"
    echo "2. Cai dat SSL"
    echo "3. Tao database"
    echo "4. Backup"
    echo "5. Quan ly service"
    echo "6. Cai dat Laravel"
    echo "7. Thoat"
}

# Menu service
show_service_menu() {
    echo "1. Nginx"
    echo "2. PHP-FPM"
    echo "3. MariaDB"
    echo "4. Redis"
}
EOF_MENU

cat > configs/webestvps.sh << 'EOF_WEBESTVPS'
#!/bin/bash

# Ham tao domain
create_domain() {
    read -p "Nhap ten domain: " domain
    if [ -z "$domain" ]; then
        echo -e "${RED}Ten domain khong duoc de trong${NC}"
        return 1
    fi
    
    # Tao thu muc cho domain
    mkdir -p "$WEB_ROOT/$domain/public_html"
    chown -R www-data:www-data "$WEB_ROOT/$domain"
    chmod -R 755 "$WEB_ROOT/$domain"
    
    # Tao file cau hinh Nginx
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
    
    # Kich hoat site
    ln -sf "$NGINX_CONF/$domain" "$NGINX_ENABLED/"
    nginx -t && systemctl reload nginx
    
    log "Da tao domain $domain thanh cong"
}

# Ham cai dat SSL
install_ssl() {
    read -p "Nhap ten domain can cai SSL: " domain
    if [ -z "$domain" ]; then
        echo -e "${RED}Ten domain khong duoc de trong${NC}"
        return 1
    fi
    
    # Cai dat Certbot
    apt-get install -y certbot python3-certbot-nginx
    
    # Cai dat SSL
    certbot --nginx -d $domain -d www.$domain
    
    log "Da cai dat SSL cho $domain thanh cong"
}

# Ham tao database
create_database() {
    read -p "Nhap ten database: " dbname
    read -p "Nhap ten user: " dbuser
    read -s -p "Nhap mat khau: " dbpass
    echo
    
    # Tao database va user
    mysql -e "CREATE DATABASE $dbname;"
    mysql -e "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';"
    mysql -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
    
    log "Da tao database $dbname thanh cong"
}

# Ham backup
backup() {
    read -p "Nhap ten domain can backup: " domain
    if [ -z "$domain" ]; then
        echo -e "${RED}Ten domain khong duoc de trong${NC}"
        return 1
    fi
    
    # Tao thu muc backup
    mkdir -p "$WEB_ROOT/backups"
    
    # Backup files
    tar -czf "$WEB_ROOT/backups/${domain}_$(date +%Y%m%d).tar.gz" "$WEB_ROOT/$domain"
    
    # Backup database
    dbname=$(grep -o "database_name.*" "$WEB_ROOT/$domain/public_html/wp-config.php" | cut -d"'" -f4)
    if [ ! -z "$dbname" ]; then
        mysqldump $dbname > "$WEB_ROOT/backups/${dbname}_$(date +%Y%m%d).sql"
    fi
    
    log "Da backup $domain thanh cong"
}

# Ham cai dat Laravel
install_laravel() {
    read -p "Nhap ten domain: " domain
    if [ -z "$domain" ]; then
        echo -e "${RED}Ten domain khong duoc de trong${NC}"
        return 1
    fi
    
    # Cai dat Composer
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    
    # Tao project Laravel
    composer create-project --prefer-dist laravel/laravel "$WEB_ROOT/$domain"
    
    # Cau hinh quyen
    chown -R www-data:www-data "$WEB_ROOT/$domain"
    chmod -R 755 "$WEB_ROOT/$domain"
    
    # Cau hinh Nginx
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
    
    # Kich hoat site
    ln -sf "$NGINX_CONF/$domain" "$NGINX_ENABLED/"
    nginx -t && systemctl reload nginx
    
    log "Da cai dat Laravel cho $domain thanh cong"
}
EOF_WEBESTVPS

cat > configs/nginx.conf << 'EOF_NGINX'
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
EOF_NGINX

cat > configs/php.ini << 'EOF_PHP'
upload_max_filesize = 64M
post_max_size = 64M
memory_limit = 256M
max_execution_time = 300
EOF_PHP

# Cap quyen thuc thi cho cac file cau hinh
chmod +x configs/*.sh

# Import cac file cau hinh
source configs/colors.sh
source configs/paths.sh
source configs/functions.sh
source configs/dependencies.sh
source configs/services.sh
source configs/menu.sh
source configs/webestvps.sh

# Kiem tra quyen root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Vui long chay script voi quyen root (sudo)${NC}"
    exit 1
fi

# Ham cai dat cac goi can thiet
install_dependencies() {
    log "Dang cai dat cac goi can thiet..."
    
    # Cap nhat he thong
    apt-get update
    apt-get upgrade -y
    
    # Cai dat cac goi co ban
    apt-get install -y "${BASIC_PACKAGES[@]}"
    
    # Cai dat Nginx
    apt-get install -y "${NGINX_PACKAGES[@]}"
    
    # Cai dat MariaDB voi mat khau root mac dinh
    debconf-set-selections <<< 'mariadb-server mysql-server/root_password password webestroot'
    debconf-set-selections <<< 'mariadb-server mysql-server/root_password_again password webestroot'
    apt-get install -y "${MARIADB_PACKAGES[@]}"
    
    # Cai dat PHP 8.1 va cac module can thiet
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt-get update
    apt-get install -y "${PHP_PACKAGES[@]}"
    
    # Cai dat cac goi khac
    apt-get install -y "${OTHER_PACKAGES[@]}"
}

# Ham cau hinh cac service
configure_services() {
    log "Dang cau hinh cac service..."
    
    # Cau hinh Nginx
    mkdir -p "$WEB_ROOT/default"
    echo "<h1>Welcome to WebEST VPS</h1>" > "$WEB_ROOT/default/index.html"
    
    # Backup cau hinh Nginx mac dinh
    if [ -f "/etc/nginx/sites-available/default" ]; then
        mv "/etc/nginx/sites-available/default" "/etc/nginx/sites-available/default.bak"
    fi
    
    # Tao cau hinh Nginx moi
    cat > "/etc/nginx/sites-available/default" << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/default;
    index index.html index.htm index.nginx-debian.html;
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    
    # Khoi dong lai Nginx
    systemctl restart nginx
    nginx -t
    
    # Cau hinh MariaDB
    if [ ! -f "/root/.my.cnf" ]; then
        cat > /root/.my.cnf << EOF
[client]
user=root
password=webestroot
EOF
        chmod 600 /root/.my.cnf
    fi
    
    # Cau hinh PHP
    if [ -f "configs/php.ini" ]; then
        while IFS= read -r line; do
            sed -i "s/^${line%=*}.*/$line/" /etc/php/8.1/fpm/php.ini
        done < configs/php.ini
    else
        # Cau hinh PHP mac dinh neu khong co file cau hinh
        sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' /etc/php/8.1/fpm/php.ini
        sed -i 's/post_max_size = 8M/post_max_size = 64M/' /etc/php/8.1/fpm/php.ini
        sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.1/fpm/php.ini
        sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/8.1/fpm/php.ini
    fi
    
    systemctl restart php8.1-fpm
}

# Ham kiem tra cai dat
check_installation() {
    log "Dang kiem tra cai dat..."
    
    # Kiem tra cac service
    for service in "${SERVICES[@]}"; do
        if ! systemctl is-active --quiet $service; then
            echo -e "${RED}Service $service khong hoat dong${NC}"
            return 1
        fi
    done
    
    # Kiem tra file webestvps
    if [ ! -f "$PANEL_SCRIPT" ]; then
        echo -e "${RED}File webestvps khong ton tai${NC}"
        return 1
    fi
    
    # Kiem tra symlink
    if [ ! -L "/usr/bin/webestvps" ]; then
        ln -s "$PANEL_SCRIPT" "/usr/bin/webestvps"
    fi
    
    # Kiem tra cau hinh Nginx
    if ! nginx -t; then
        echo -e "${RED}Cau hinh Nginx co loi${NC}"
        return 1
    fi
    
    # Kiem tra ket noi MariaDB
    if ! mysql -e "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${RED}Khong the ket noi den MariaDB${NC}"
        return 1
    fi
    
    log "Kiem tra cai dat hoan tat"
    return 0
}

# Thuc hien cai dat
log "Bat dau cai dat WebEST VPS Panel..."

# Sua loi apt
fix_apt

# Cai dat cac goi can thiet
install_dependencies

# Tao script webestvps
cat > "$PANEL_SCRIPT" << EOF
#!/bin/bash

source configs/colors.sh
source configs/paths.sh
source configs/functions.sh
source configs/services.sh
source configs/menu.sh
source configs/webestvps.sh

while true; do
    show_main_menu
    read -p "Chon tac vu: " choice
    
    case \$choice in
        1) create_domain ;;
        2) install_ssl ;;
        3) create_database ;;
        4) backup ;;
        5)
            show_service_menu
            read -p "Chon service: " service_choice
            case \$service_choice in
                1) manage_service nginx ;;
                2) manage_service php8.1-fpm ;;
                3) manage_service mariadb ;;
                4) manage_service redis-server ;;
                *) echo -e "\${RED}Lua chon khong hop le\${NC}" ;;
            esac
            ;;
        6) install_laravel ;;
        7) exit 0 ;;
        *) echo -e "\${RED}Lua chon khong hop le\${NC}" ;;
    esac
done
EOF

chmod +x "$PANEL_SCRIPT"

# Cau hinh cac service
configure_services

# Kiem tra cai dat
if check_installation; then
    echo -e "\n${GREEN}=== Cai dat WebEST VPS Panel thanh cong ===${NC}"
    echo -e "Phien ban: $PANEL_VERSION"
    echo -e "De su dung panel, go lenh: ${YELLOW}webestvps${NC}"
else
    echo -e "\n${RED}=== Cai dat WebEST VPS Panel that bai ===${NC}"
    echo -e "Vui long kiem tra log va thu lai"
    exit 1
fi
