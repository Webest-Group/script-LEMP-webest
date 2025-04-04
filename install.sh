#!/bin/bash

# Mau sac cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Cac duong dan va bien
WEB_ROOT="/var/www"
PANEL_VERSION="1.0.0"
PANEL_SCRIPT="/usr/local/bin/webestvps"
NGINX_CONF="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

# Xóa file cũ nếu tồn tại
echo -e "${YELLOW}Đang xóa file cũ...${NC}"
rm -rf /usr/local/bin/webestvps
rm -rf /usr/local/bin/configs/

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

# Kiem tra quyen root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Vui long chay script voi quyen root (sudo)${NC}"
    exit 1
fi

# Xoa cai dat cu neu co
log "Dang xoa cai dat cu..."
rm -f $PANEL_SCRIPT
rm -rf /usr/local/bin/configs
rm -f /usr/bin/webestvps

# Tao thu muc configs
log "Dang tao thu muc cau hinh moi..."
mkdir -p /usr/local/bin/configs
check_error "Khong the tao thu muc configs"

# Tai va tao cac file cau hinh
log "Dang tao cac file cau hinh..."

# colors.sh
cat > /usr/local/bin/configs/colors.sh << 'EOF_COLORS'
#!/bin/bash

# Mau sac cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
EOF_COLORS
chmod +x /usr/local/bin/configs/colors.sh

# paths.sh
cat > /usr/local/bin/configs/paths.sh << 'EOF_PATHS'
#!/bin/bash

# Cac duong dan va bien
WEB_ROOT="/var/www"
PANEL_VERSION="1.0.0"
PANEL_SCRIPT="/usr/local/bin/webestvps"
NGINX_CONF="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
MYSQL_ROOT_PASS="$(cat /root/.my.cnf 2>/dev/null | grep password | cut -d'=' -f2 || echo "webestroot")"
EOF_PATHS
chmod +x /usr/local/bin/configs/paths.sh

# functions.sh
cat > /usr/local/bin/configs/functions.sh << 'EOF_FUNCTIONS'
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
chmod +x /usr/local/bin/configs/functions.sh

# dependencies.sh
cat > /usr/local/bin/configs/dependencies.sh << 'EOF_DEPENDENCIES'
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
chmod +x /usr/local/bin/configs/dependencies.sh

# services.sh
cat > /usr/local/bin/configs/services.sh << 'EOF_SERVICES'
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
chmod +x /usr/local/bin/configs/services.sh

# menu.sh
cat > /usr/local/bin/configs/menu.sh << 'EOF_MENU'
#!/bin/bash

# Menu chinh
show_main_menu() {
    echo -e "\n${YELLOW}=== WebEST VPS Panel ===${NC}"
    echo "1. Quan ly domain"
    echo "2. Quan ly database"
    echo "3. Cai dat SSL"
    echo "4. Backup"
    echo "5. Quan ly service"
    echo "6. Setup Git Hook"
    echo "7. Cap nhat WebEST VPS"
    echo "8. Cai dat them"
    echo "9. Thoat"
}

# Menu quan ly domain
show_domain_menu() {
    echo -e "\n${YELLOW}=== Quan ly Domain ===${NC}"
    echo "1. Tao domain moi"
    echo "2. Xoa domain"
    echo "3. Xem danh sach domain"
    echo "4. Tro ve menu chinh"
}

# Menu quan ly database
show_database_menu() {
    echo -e "\n${YELLOW}=== Quan ly Database ===${NC}"
    echo "1. Tao database moi"
    echo "2. Xoa database"
    echo "3. Xem danh sach database"
    echo "4. Tro ve menu chinh"
}

# Menu service
show_service_menu() {
    echo "1. Nginx"
    echo "2. PHP-FPM"
    echo "3. MariaDB"
    echo "4. Redis"
    echo "5. PostgreSQL"
    echo "6. PHP 8.3-FPM"
    echo "7. Quay lai menu chinh"
}

# Menu cai dat them
show_install_menu() {
    echo -e "\n${YELLOW}=== Cai dat them ===${NC}"
    echo "1. Cai dat PostgreSQL"
    echo "2. Cai dat PHP 8.3"
    echo "3. Tro ve menu chinh"
}
EOF_MENU
chmod +x /usr/local/bin/configs/menu.sh

# postgresql.sh
cat > /usr/local/bin/configs/postgresql.sh << 'EOF_POSTGRESQL'
#!/bin/bash

# Ham cai dat PostgreSQL
install_postgresql() {
    echo -e "${YELLOW}Dang cai dat PostgreSQL...${NC}"
    
    # Cai dat PostgreSQL
    apt-get update
    apt-get install -y postgresql postgresql-contrib
    
    # Khoi dong service
    systemctl start postgresql
    systemctl enable postgresql
    
    echo -e "${GREEN}Da cai dat PostgreSQL thanh cong!${NC}"
    echo -e "Mat khau mac dinh cho user postgres: postgres"
    echo -e "De thay doi mat khau, su dung lenh: sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD 'mat_khau_moi';\""
}

# Ham tao database PostgreSQL
create_postgresql_database() {
    read -p "Nhap ten database: " dbname
    read -p "Nhap ten user: " dbuser
    read -s -p "Nhap mat khau: " dbpass
    echo
    
    # Tao database va user
    sudo -u postgres psql -c "CREATE DATABASE $dbname;"
    sudo -u postgres psql -c "CREATE USER $dbuser WITH PASSWORD '$dbpass';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $dbname TO $dbuser;"
    
    log "Da tao PostgreSQL database $dbname thanh cong"
}

# Ham xoa database PostgreSQL
delete_postgresql_database() {
    read -p "Nhap ten database can xoa: " dbname
    read -p "Nhap ten user can xoa: " dbuser
    
    # Xoa database va user
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $dbname;"
    sudo -u postgres psql -c "DROP USER IF EXISTS $dbuser;"
    
    log "Da xoa PostgreSQL database $dbname va user $dbuser thanh cong"
}

# Ham hien thi danh sach database PostgreSQL
list_postgresql_databases() {
    echo -e "\n${YELLOW}Danh sach PostgreSQL databases:${NC}"
    sudo -u postgres psql -c "\l"
    
    echo -e "\n${YELLOW}Danh sach PostgreSQL users:${NC}"
    sudo -u postgres psql -c "\du"
}

# Ham quan ly PostgreSQL
manage_postgresql() {
    while true; do
        echo -e "\n${YELLOW}=== Quan ly PostgreSQL ===${NC}"
        echo "1. Cai dat PostgreSQL"
        echo "2. Tao database"
        echo "3. Xoa database"
        echo "4. Xem danh sach database"
        echo "5. Quay lai menu chinh"
        read -p "Chon tac vu: " choice
        
        case $choice in
            1) install_postgresql ;;
            2) create_postgresql_database ;;
            3) delete_postgresql_database ;;
            4) list_postgresql_databases ;;
            5) return ;;
            *) echo -e "${RED}Lua chon khong hop le${NC}" ;;
        esac
    done
}
EOF_POSTGRESQL
chmod +x /usr/local/bin/configs/postgresql.sh

# webestvps.sh
cat > /usr/local/bin/configs/webestvps.sh << 'EOF_WEBESTVPS'
#!/bin/bash

# Ham setup git hook
setup_git_hook() {
    read -p "Nhap ten domain: " domain
    if [ -z "$domain" ]; then
        echo -e "${RED}Ten domain khong duoc de trong${NC}"
        return 1
    fi

    read -p "Nhap ten repository (user/repo): " repo
    if [ -z "$repo" ]; then
        echo -e "${RED}Ten repository khong duoc de trong${NC}"
        return 1
    fi

    read -p "Nhap ten branch (mac dinh: main): " branch
    branch=${branch:-main}

    # Khoi tao git repository trong public_html
    cd "$WEB_ROOT/$domain/public_html"
    git init
    git remote add origin "https://github.com/$repo.git"
    git fetch origin
    git checkout -b $branch "origin/$branch"

    # Tao file hook
    cat > "$WEB_ROOT/$domain/public_html/webhook.php" << EOF
<?php
// Cau hinh
\$secret = 'webestvps';
\$domain = '$domain';
\$branch = '$branch';
\$web_root = '$WEB_ROOT';

// Kiem tra secret
\$headers = getallheaders();
\$hub_signature = \$headers['X-Hub-Signature-256'] ?? '';

if (empty(\$hub_signature)) {
    http_response_code(401);
    die('Missing signature');
}

// Lay payload
\$payload = file_get_contents('php://input');
\$payload_hash = 'sha256=' . hash_hmac('sha256', \$payload, \$secret);

if (!hash_equals(\$hub_signature, \$payload_hash)) {
    http_response_code(401);
    die('Invalid signature');
}

// Xu ly payload
\$data = json_decode(\$payload, true);
if (!isset(\$data['ref'])) {
    http_response_code(400);
    die('Invalid payload');
}

// Kiem tra branch
\$ref = \$data['ref'];
\$push_branch = substr(\$ref, strrpos(\$ref, '/') + 1);

if (\$push_branch !== \$branch) {
    die('Ignoring push to ' . \$push_branch);
}

// Thuc hien git pull
chdir(\$web_root . '/' . \$domain . '/public_html');
exec('git fetch origin ' . \$branch . ' 2>&1', \$output, \$return_var);
exec('git reset --hard origin/' . \$branch . ' 2>&1', \$output, \$return_var);

if (\$return_var !== 0) {
    http_response_code(500);
    die('Git pull failed: ' . implode("\n", \$output));
}

// Cap nhat quyen
exec('chown -R www-data:www-data .');
exec('find . -type f -exec chmod 644 {} \\;');
exec('find . -type d -exec chmod 755 {} \\;');

// Khoi dong lai PHP-FPM
exec('systemctl restart php8.1-fpm');

echo 'Success';
EOF

    # Commit file webhook.php
    git add webhook.php
    git commit -m "Add webhook.php for auto deployment"
    git push origin $branch

    # Cap nhat cau hinh Nginx cho domain
    cat > "$NGINX_CONF/$domain" << EOF
server {
    listen 80;
    server_name $domain www.$domain;
    root $WEB_ROOT/$domain/public_html;
    index index.php index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location /webhook.php {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        
        # Chi cho phep POST
        if (\$request_method != POST) {
            return 405;
        }
        
        # Gioi han kich thuoc payload
        client_max_body_size 1M;
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

    log "Da setup git hook cho $domain thanh cong"
    log "Webhook URL: http://$domain/webhook.php"
    log "Secret: webestvps"
}

# Ham update webestvps
update_webestvps() {
    # Tao thu muc tam
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    # Clone repository moi
    git clone https://github.com/Webest-Group/script-LEMP-webest.git .
    
    # Kiem tra version moi
    NEW_VERSION=$(cat install.sh | grep "PANEL_VERSION=" | cut -d'"' -f2)
    CURRENT_VERSION=$(cat /usr/local/bin/configs/paths.sh | grep "PANEL_VERSION=" | cut -d'"' -f2)
    
    if [ "$NEW_VERSION" = "$CURRENT_VERSION" ]; then
        echo -e "${GREEN}Ban dang su dung phien ban moi nhat: $CURRENT_VERSION${NC}"
        rm -rf "$TMP_DIR"
        return 0
    fi
    
    echo -e "${YELLOW}Tim thay phien ban moi: $NEW_VERSION${NC}"
    echo -e "${YELLOW}Phien ban hien tai: $CURRENT_VERSION${NC}"
    
    read -p "Ban co muon cap nhat khong? (y/n): " choice
    if [ "$choice" != "y" ]; then
        echo -e "${RED}Da huy cap nhat${NC}"
        rm -rf "$TMP_DIR"
        return 0
    fi
    
    # Sao chep file moi
    bash install.sh
    
    # Xoa thu muc tam
    rm -rf "$TMP_DIR"
    
    log "Da cap nhat WebEST VPS Panel len phien ban $NEW_VERSION"
    log "Vui long khoi dong lai panel de ap dung thay doi"
}

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
    
    # Menu chon loai domain
    echo -e "\n${YELLOW}Chon loai domain:${NC}"
    echo "1. Domain dung Laravel"
    echo "2. Domain dung WordPress"
    echo "3. Domain dung code normal"
    read -p "Chon loai domain: " domain_type
    
    case $domain_type in
        1) # Laravel
            # Tao file .env
            cat > "$WEB_ROOT/$domain/public_html/.env" << EOF
APP_NAME=Laravel
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://$domain

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel_${domain//./_}
DB_USERNAME=laravel_${domain//./_}
DB_PASSWORD=$(openssl rand -base64 12)

BROADCAST_DRIVER=log
CACHE_DRIVER=file
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

MEMCACHED_HOST=127.0.0.1

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=mailpit
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="${APP_NAME}"

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=
AWS_USE_PATH_STYLE_ENDPOINT=false

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_HOST=
PUSHER_PORT=443
PUSHER_SCHEME=https
PUSHER_APP_CLUSTER=mt1

VITE_APP_NAME="${APP_NAME}"
VITE_PUSHER_APP_KEY="${PUSHER_APP_KEY}"
VITE_PUSHER_HOST="${PUSHER_HOST}"
VITE_PUSHER_PORT="${PUSHER_PORT}"
VITE_PUSHER_SCHEME="${PUSHER_SCHEME}"
VITE_PUSHER_APP_CLUSTER="${PUSHER_APP_CLUSTER}"
EOF
            
            # Tao file index.php cho Laravel
            cat > "$WEB_ROOT/$domain/public_html/index.php" << EOF
<?php
require __DIR__.'/vendor/autoload.php';
\$app = require_once __DIR__.'/bootstrap/app.php';
\$kernel = \$app->make(Illuminate\Contracts\Http\Kernel::class);
\$response = \$kernel->handle(
    \$request = Illuminate\Http\Request::capture()
);
\$response->send();
\$kernel->terminate(\$request, \$response);
EOF
            
            # Tao database cho Laravel
            dbname="laravel_${domain//./_}"
            dbuser="laravel_${domain//./_}"
            dbpass=$(openssl rand -base64 12)
            
            mysql -e "CREATE DATABASE $dbname;"
            mysql -e "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';"
            mysql -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'localhost';"
            mysql -e "FLUSH PRIVILEGES;"
            
            # Cap nhat .env voi thong tin database
            sed -i "s/DB_DATABASE=.*/DB_DATABASE=$dbname/" "$WEB_ROOT/$domain/public_html/.env"
            sed -i "s/DB_USERNAME=.*/DB_USERNAME=$dbuser/" "$WEB_ROOT/$domain/public_html/.env"
            sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$dbpass/" "$WEB_ROOT/$domain/public_html/.env"
            ;;
            
        2) # WordPress
            # Tai WordPress
            cd "$WEB_ROOT/$domain/public_html"
            wget https://wordpress.org/latest.tar.gz
            tar -xzf latest.tar.gz --strip-components=1
            rm latest.tar.gz
            
            # Tao database cho WordPress
            dbname="wp_${domain//./_}"
            dbuser="wp_${domain//./_}"
            dbpass=$(openssl rand -base64 12)
            
            mysql -e "CREATE DATABASE $dbname;"
            mysql -e "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';"
            mysql -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'localhost';"
            mysql -e "FLUSH PRIVILEGES;"
            
            # Tao file wp-config.php
            cp wp-config-sample.php wp-config.php
            sed -i "s/database_name_here/$dbname/" wp-config.php
            sed -i "s/username_here/$dbuser/" wp-config.php
            sed -i "s/password_here/$dbpass/" wp-config.php
            
            # Tao key cho WordPress
            for i in {1..8}; do
                sed -i "0,/put your unique phrase here/s//$(openssl rand -base64 32)/" wp-config.php
            done
            ;;
            
        3) # Code normal
            # Tao file index.html mac dinh
            cat > "$WEB_ROOT/$domain/public_html/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $domain</title>
</head>
<body>
    <h1>Welcome to $domain</h1>
    <p>This is the default page for your domain.</p>
</body>
</html>
EOF
            ;;
            
        *)
            echo -e "${RED}Lua chon khong hop le${NC}"
            return 1
            ;;
    esac
    
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
    log "Thu muc goc: $WEB_ROOT/$domain/public_html"
    
    # Hien thi thong tin database neu co
    if [ "$domain_type" = "1" ] || [ "$domain_type" = "2" ]; then
        log "Thong tin database:"
        log "Database: $dbname"
        log "User: $dbuser"
        log "Password: $dbpass"
    fi
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

# Ham xoa domain
delete_domain() {
    read -p "Nhap ten domain can xoa: " domain
    if [ -z "$domain" ]; then
        echo -e "${RED}Ten domain khong duoc de trong${NC}"
        return 1
    fi
    
    # Kiem tra domain co ton tai khong
    if [ ! -d "$WEB_ROOT/$domain" ]; then
        echo -e "${RED}Domain $domain khong ton tai${NC}"
        return 1
    fi
    
    # Xac nhan xoa
    read -p "Ban co chac chan muon xoa domain $domain? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo -e "${YELLOW}Da huy xoa domain${NC}"
        return 0
    fi
    
    # Xoa thu muc domain
    rm -rf "$WEB_ROOT/$domain"
    
    # Xoa cau hinh Nginx
    rm -f "$NGINX_CONF/$domain"
    rm -f "$NGINX_ENABLED/$domain"
    
    # Khoi dong lai Nginx
    nginx -t && systemctl reload nginx
    
    log "Da xoa domain $domain thanh cong"
}

# Ham xem danh sach domain
list_domains() {
    echo -e "\n${YELLOW}=== Danh sach domain ===${NC}"
    for domain in $(ls $WEB_ROOT); do
        if [ -d "$WEB_ROOT/$domain" ]; then
            echo -e "${GREEN}$domain${NC}"
            echo "  Thu muc: $WEB_ROOT/$domain/public_html"
            echo "  Nginx config: $NGINX_CONF/$domain"
            echo "  Status: $(systemctl is-active nginx >/dev/null 2>&1 && echo "Active" || echo "Inactive")"
            echo
        fi
    done
}

# Ham xoa database
delete_database() {
    read -p "Nhap ten database can xoa: " dbname
    if [ -z "$dbname" ]; then
        echo -e "${RED}Ten database khong duoc de trong${NC}"
        return 1
    fi
    
    # Kiem tra database co ton tai khong
    if ! mysql -e "SHOW DATABASES LIKE '$dbname';" | grep -q "$dbname"; then
        echo -e "${RED}Database $dbname khong ton tai${NC}"
        return 1
    fi
    
    # Xac nhan xoa
    read -p "Ban co chac chan muon xoa database $dbname? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo -e "${YELLOW}Da huy xoa database${NC}"
        return 0
    fi
    
    # Xoa database
    mysql -e "DROP DATABASE $dbname;"
    
    # Xoa user neu co
    user=$(mysql -e "SELECT User FROM mysql.user WHERE User LIKE '%$dbname%';" | tail -n 1)
    if [ ! -z "$user" ]; then
        mysql -e "DROP USER '$user'@'localhost';"
    fi
    
    log "Da xoa database $dbname thanh cong"
}

# Ham xem danh sach database
list_databases() {
    echo -e "\n${YELLOW}=== Danh sach database ===${NC}"
    mysql -e "SHOW DATABASES;" | while read dbname; do
        if [ "$dbname" != "Database" ] && [ "$dbname" != "information_schema" ] && [ "$dbname" != "mysql" ] && [ "$dbname" != "performance_schema" ]; then
            echo -e "${GREEN}$dbname${NC}"
            # Lay thong tin user
            user=$(mysql -e "SELECT User FROM mysql.user WHERE User LIKE '%$dbname%';" | tail -n 1)
            if [ ! -z "$user" ]; then
                echo "  User: $user"
                # Lay thong tin quyen
                mysql -e "SHOW GRANTS FOR '$user'@'localhost';" | while read grant; do
                    echo "  $grant"
                done
            fi
            echo
        fi
    done
}

# Hàm quản lý menu chính
manage_main_menu() {
    while true; do
        show_main_menu
        read -p "Chọn tác vụ: " choice
        
        case $choice in
            1) # Quản lý domain
                while true; do
                    show_domain_menu
                    read -p "Chọn tác vụ: " domain_choice
                    
                    case $domain_choice in
                        1) create_domain ;;
                        2) delete_domain ;;
                        3) list_domains ;;
                        4) break ;;
                        *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
                    esac
                done
                ;;
                
            2) # Quản lý database
                while true; do
                    show_database_menu
                    read -p "Chọn tác vụ: " db_choice
                    
                    case $db_choice in
                        1) create_database ;;
                        2) delete_database ;;
                        3) list_databases ;;
                        4) break ;;
                        *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
                    esac
                done
                ;;
            
            3) install_ssl ;;
            4) backup ;;
            5) # Quản lý service
                while true; do
                    show_service_menu
                    read -p "Chọn service: " service_choice
                    
                    case $service_choice in
                        1) manage_service "nginx" ;;
                        2) manage_service "php8.1-fpm" ;;
                        3) manage_service "mariadb" ;;
                        4) manage_service "redis-server" ;;
                        5) manage_service "postgresql" ;;
                        6) manage_service "php8.3-fpm" ;;
                        7) break ;;
                        *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
                    esac
                done
                ;;
            6) setup_git_hook ;;
            7) update_webestvps ;;
            8) manage_install_menu ;;
            9) exit 0 ;;
            *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
        esac
    done
}

# Hàm quản lý menu cài đặt thêm
manage_install_menu() {
    while true; do
        show_install_menu
        read -p "Chọn tác vụ: " choice
        
        case $choice in
            1) manage_postgresql ;;
            2) manage_php83 ;;
            3) return ;;
            *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
        esac
    done
}

# Khởi động WebEST VPS Panel
manage_main_menu
EOF_WEBESTVPS

# nginx.conf
cat > /usr/local/bin/configs/nginx.conf << 'EOF_NGINX'
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
EOF_NGINX

# php.ini
cat > /usr/local/bin/configs/php.ini << 'EOF_PHP'
upload_max_filesize = 64M
post_max_size = 64M
memory_limit = 256M
max_execution_time = 300
EOF_PHP

# php83.sh
cat > /usr/local/bin/configs/php83.sh << 'EOF_PHP83'
#!/bin/bash

# Ham cai dat PHP 8.3
install_php83() {
    echo -e "${YELLOW}Dang cai dat PHP 8.3...${NC}"
    
    # Them PPA neu chua
    apt-get update
    apt-get install -y software-properties-common
    add-apt-repository ppa:ondrej/php -y
    apt-get update
    
    # Cai dat PHP 8.3
    apt-get install -y php8.3-fpm php8.3-cli php8.3-common php8.3-mysql php8.3-zip php8.3-gd php8.3-mbstring php8.3-curl php8.3-xml php8.3-bcmath php8.3-intl php8.3-pgsql
    
    # Khoi dong service
    systemctl start php8.3-fpm
    systemctl enable php8.3-fpm
    
    echo -e "${GREEN}Da cai dat PHP 8.3 thanh cong!${NC}"
}

# Ham cau hinh PHP 8.3
configure_php83() {
    echo -e "${YELLOW}Dang cau hinh PHP 8.3...${NC}"
    
    # Tao backup
    cp /etc/php/8.3/fpm/php.ini /etc/php/8.3/fpm/php.ini.bak
    
    # Cau hinh PHP
    sed -i 's/memory_limit = .*/memory_limit = 256M/' /etc/php/8.3/fpm/php.ini
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' /etc/php/8.3/fpm/php.ini
    sed -i 's/post_max_size = .*/post_max_size = 64M/' /etc/php/8.3/fpm/php.ini
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.3/fpm/php.ini
    
    # Khoi dong lai PHP-FPM
    systemctl restart php8.3-fpm
    
    echo -e "${GREEN}Da cau hinh PHP 8.3 thanh cong!${NC}"
}

# Ham chuyen doi Nginx sang su dung PHP 8.3
switch_to_php83() {
    echo -e "${YELLOW}Dang chuyen doi Nginx sang su dung PHP 8.3...${NC}"
    
    # Tim tat ca cac file cau hinh Nginx
    nginx_configs=$(find /etc/nginx/sites-available -type f)
    
    for config in $nginx_configs; do
        # Kiem tra xem file co chua fastcgi_pass va php-fpm socket khong
        if grep -q "fastcgi_pass.*php.*-fpm.sock" "$config"; then
            # Thay the php*-fpm.sock bang php8.3-fpm.sock
            sed -i 's/fastcgi_pass unix:\/var\/run\/php\/php[0-9]\.[0-9]-fpm\.sock/fastcgi_pass unix:\/var\/run\/php\/php8.3-fpm.sock/g' "$config"
            echo -e "Da cap nhat file cau hinh: ${GREEN}$config${NC}"
        fi
    done
    
    # Khoi dong lai Nginx
    systemctl restart nginx
    
    echo -e "${GREEN}Da chuyen doi Nginx sang su dung PHP 8.3 thanh cong!${NC}"
}

# Ham quan ly PHP 8.3
manage_php83() {
    while true; do
        echo -e "\n${YELLOW}=== Quan ly PHP 8.3 ===${NC}"
        echo "1. Cai dat PHP 8.3"
        echo "2. Cau hinh PHP 8.3"
        echo "3. Chuyen doi Nginx sang PHP 8.3"
        echo "4. Kiem tra phien ban PHP"
        echo "5. Quay lai menu chinh"
        read -p "Chon tac vu: " choice
        
        case $choice in
            1) install_php83 ;;
            2) configure_php83 ;;
            3) switch_to_php83 ;;
            4) php -v ;;
            5) return ;;
            *) echo -e "${RED}Lua chon khong hop le${NC}" ;;
        esac
    done
}
EOF_PHP83
chmod +x /usr/local/bin/configs/php83.sh

# Tao script webestvps chinh
log "Dang tao script chinh..."
cat > $PANEL_SCRIPT << 'EOF_MAINSCRIPT'
#!/bin/bash

# Import cac file cau hinh
CONFIG_DIR="/usr/local/bin/configs"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "ERROR: Khong tim thay thu muc cau hinh $CONFIG_DIR"
    exit 1
fi

# Import cac file theo thu tu phu thuoc
source "$CONFIG_DIR/colors.sh" || { echo "ERROR: Khong the import colors.sh"; exit 1; }
source "$CONFIG_DIR/paths.sh" || { echo "ERROR: Khong the import paths.sh"; exit 1; }
source "$CONFIG_DIR/functions.sh" || { echo "ERROR: Khong the import functions.sh"; exit 1; }
source "$CONFIG_DIR/dependencies.sh" || { echo "ERROR: Khong the import dependencies.sh"; exit 1; }
source "$CONFIG_DIR/services.sh" || { echo "ERROR: Khong the import services.sh"; exit 1; }
source "$CONFIG_DIR/menu.sh" || { echo "ERROR: Khong the import menu.sh"; exit 1; }
source "$CONFIG_DIR/postgresql.sh" || { echo "ERROR: Khong the import postgresql.sh"; exit 1; }
source "$CONFIG_DIR/webestvps.sh" || { echo "ERROR: Khong the import webestvps.sh"; exit 1; }
source "$CONFIG_DIR/php83.sh" || { echo "ERROR: Khong the import php83.sh"; exit 1; }

# Kiem tra cac bien can thiet
if [ -z "$WEB_ROOT" ] || [ -z "$PANEL_VERSION" ] || [ -z "$PANEL_SCRIPT" ] || [ -z "$NGINX_CONF" ] || [ -z "$NGINX_ENABLED" ]; then
    echo "ERROR: Thieu bien cau hinh can thiet"
    exit 1
fi

# Kiem tra cac service can thiet
if ! systemctl is-active --quiet nginx || ! systemctl is-active --quiet php8.1-fpm || ! systemctl is-active --quiet mariadb; then
    echo "ERROR: Mot hoac nhieu service can thiet khong hoat dong"
    exit 1
fi

while true; do
    show_main_menu
    read -p "Chon tac vu: " choice
    
    case $choice in
        1) # Quan ly domain
            while true; do
                show_domain_menu
                read -p "Chon tac vu: " domain_choice
                
                case $domain_choice in
                    1) create_domain ;;
                    2) delete_domain ;;
                    3) list_domains ;;
                    4) break ;;
                    *) echo -e "${RED}Lua chon khong hop le${NC}" ;;
                esac
            done
            ;;
            
        2) # Quan ly database
            while true; do
                show_database_menu
                read -p "Chon tac vu: " db_choice
                
                case $db_choice in
                    1) create_database ;;
                    2) delete_database ;;
                    3) list_databases ;;
                    4) break ;;
                    *) echo -e "${RED}Lua chon khong hop le${NC}" ;;
                esac
            done
            ;;
            
        3) install_ssl ;;
        4) backup ;;
        5)
            show_service_menu
            read -p "Chon service: " service_choice
            case $service_choice in
                1) manage_service nginx ;;
                2) manage_service php8.1-fpm ;;
                3) manage_service mariadb ;;
                4) manage_service redis-server ;;
                *) echo -e "${RED}Lua chon khong hop le${NC}" ;;
            esac
            ;;
        6) setup_git_hook ;;
        7) update_webestvps ;;
        8) manage_install_menu ;;
        9) exit 0 ;;
        *) echo -e "${RED}Lua chon khong hop le${NC}" ;;
    esac
done
EOF_MAINSCRIPT

chmod +x $PANEL_SCRIPT
check_error "Khong the tao script chinh"

# Tao symlink
log "Dang tao symlink..."
ln -sf "$PANEL_SCRIPT" "/usr/bin/webestvps"
check_error "Khong the tao symlink"

# Ham cai dat cac goi can thiet
install_dependencies() {
    log "Dang cai dat cac goi can thiet..."
    
    # Cap nhat he thong
    apt-get update
    apt-get upgrade -y
    
    # Import cac file cau hinh
    source "/usr/local/bin/configs/dependencies.sh"
    
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
    
    # Import cac file cau hinh
    source "/usr/local/bin/configs/paths.sh"
    
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
    source "/usr/local/bin/configs/php.ini"
    cat > /etc/php/8.1/fpm/conf.d/99-webestvps.ini << EOF
upload_max_filesize = 64M
post_max_size = 64M
memory_limit = 256M
max_execution_time = 300
EOF
    
    systemctl restart php8.1-fpm
}

# Ham kiem tra cai dat
check_installation() {
    log "Dang kiem tra cai dat..."
    
    # Import cac file cau hinh
    source "/usr/local/bin/configs/paths.sh"
    source "/usr/local/bin/configs/services.sh"
    
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
apt-get clean
apt-get update
apt-get install -f -y
dpkg --configure -a

# Cai dat cac goi can thiet
install_dependencies

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
