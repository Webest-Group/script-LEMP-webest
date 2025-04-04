#!/bin/bash

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

# Hàm setup git hook
setup_git_hook() {
    read -p "Nhập tên domain: " domain
    if [ -z "$domain" ]; then
        echo -e "${RED}Tên domain không được để trống${NC}"
        return 1
    fi

    read -p "Nhập tên repository (user/repo): " repo
    if [ -z "$repo" ]; then
        echo -e "${RED}Tên repository không được để trống${NC}"
        return 1
    fi

    read -p "Nhập tên branch (mặc định: main): " branch
    branch=${branch:-main}

    # Khoi tao git repository
    cd "$WEB_ROOT/$domain"
    git init
    git remote add origin "https://github.com/$repo.git"
    git fetch origin
    git checkout -b $branch "origin/$branch"

    # Tao file hook
    cat > "$WEB_ROOT/$domain/webhook.php" << EOF
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
chdir(\$web_root . '/' . \$domain);
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
    root $WEB_ROOT/$domain;
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
    NEW_VERSION=$(cat install.sh | grep "VERSION=" | cut -d'"' -f2)
    CURRENT_VERSION=$(cat /usr/local/bin/webestvps | grep "VERSION=" | cut -d'"' -f2)
    
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
    cp install.sh /usr/local/bin/webestvps
    cp -r configs/* /usr/local/bin/configs/
    
    # Cap quyen thuc thi
    chmod +x /usr/local/bin/webestvps
    chmod +x /usr/local/bin/configs/*.sh
    
    # Cập nhật file install.sh gốc
    if [ -f "/root/install.sh" ]; then
        cp install.sh /root/install.sh
        chmod +x /root/install.sh
        echo -e "${GREEN}Đã cập nhật file install.sh gốc${NC}"
    fi
    
    # Xoa thu muc tam
    rm -rf "$TMP_DIR"
    
    log "Da cap nhat WebEST VPS Panel len phien ban $NEW_VERSION"
    log "Da cap nhat file install.sh goc"
    log "Vui long khoi dong lai panel de ap dung thay doi"
    
    # Khởi động lại script
    exec /usr/local/bin/webestvps
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
            5) manage_services ;;
            6) setup_git_hook ;;
            7) update_webestvps ;;
            8) manage_postgresql ;;
            9) exit 0 ;;
            *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
        esac
    done
}

# Hàm quản lý service
manage_services() {
    while true; do
        show_service_menu
        read -p "Chọn service: " choice
        
        case $choice in
            1) manage_service "nginx" ;;
            2) manage_service "php8.1-fpm" ;;
            3) manage_service "mariadb" ;;
            4) manage_service "redis-server" ;;
            5) manage_postgresql ;;
            *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
        esac
    done
}

# Hàm quản lý PostgreSQL
manage_postgresql() {
    while true; do
        echo -e "\n${YELLOW}=== Quản lý PostgreSQL ===${NC}"
        echo "1. Cài đặt PostgreSQL"
        echo "2. Tạo database"
        echo "3. Xóa database"
        echo "4. Xem danh sách database"
        echo "5. Quay lại menu chính"
        read -p "Chọn tác vụ: " choice
        
        case $choice in
            1) install_postgresql ;;
            2) create_postgresql_database ;;
            3) delete_postgresql_database ;;
            4) list_postgresql_databases ;;
            5) return ;;
            *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
        esac
    done
}

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

# Gọi hàm quản lý menu chính
manage_main_menu 