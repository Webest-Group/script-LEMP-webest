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