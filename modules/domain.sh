#!/bin/bash

create_vhost() {
    local domain=$1
    local php_version=$2
    local db_type=$3
    local use_cloudflare=$4
    
    log "Bắt đầu tạo virtual host cho $domain..."
    
    # Tạo thư mục web
    mkdir -p /var/www/$domain/public_html
    mkdir -p /var/www/$domain/logs
    chown -R www-data:www-data /var/www/$domain
    
    # Tạo virtual host config
    cat > /etc/nginx/sites-available/$domain <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    root /var/www/$domain/public_html;
    
    index index.php index.html index.htm;
    
    access_log /var/www/$domain/logs/access.log;
    error_log /var/www/$domain/logs/error.log;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$php_version-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF
    
    # Enable virtual host
    ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
    
    # Tạo database nếu được yêu cầu
    if [ "$db_type" = "mariadb" ]; then
        mysql -e "CREATE DATABASE ${domain//./_};"
        mysql -e "CREATE USER '${domain//./_}'@'localhost' IDENTIFIED BY '$(openssl rand -base64 12)';"
        mysql -e "GRANT ALL PRIVILEGES ON ${domain//./_}.* TO '${domain//./_}'@'localhost';"
        mysql -e "FLUSH PRIVILEGES;"
    elif [ "$db_type" = "postgresql" ]; then
        sudo -u postgres psql -c "CREATE DATABASE ${domain//./_};"
        sudo -u postgres psql -c "CREATE USER ${domain//./_} WITH PASSWORD '$(openssl rand -base64 12)';"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${domain//./_} TO ${domain//./_};"
    fi
    
    # Cấu hình Cloudflare nếu được yêu cầu
    if [ "$use_cloudflare" = "yes" ]; then
        # Thêm cấu hình Cloudflare
        sed -i '/server {/a\    # Cloudflare\n    set_real_ip_from 103.21.244.0/22;\n    set_real_ip_from 103.22.200.0/22;\n    set_real_ip_from 103.31.4.0/22;\n    set_real_ip_from 104.16.0.0/12;\n    set_real_ip_from 108.162.192.0/18;\n    set_real_ip_from 131.0.72.0/22;\n    set_real_ip_from 141.101.64.0/18;\n    set_real_ip_from 162.158.0.0/15;\n    set_real_ip_from 172.64.0.0/13;\n    set_real_ip_from 173.245.48.0/20;\n    set_real_ip_from 188.114.96.0/20;\n    set_real_ip_from 190.93.240.0/20;\n    set_real_ip_from 197.234.240.0/22;\n    set_real_ip_from 198.41.128.0/17;\n    set_real_ip_from 2400:cb00::/32;\n    set_real_ip_from 2606:4700::/32;\n    set_real_ip_from 2803:f800::/32;\n    set_real_ip_from 2405:b500::/32;\n    set_real_ip_from 2405:8100::/32;\n    set_real_ip_from 2c0f:f248::/32;\n    set_real_ip_from 2a06:98c0::/29;\n    real_ip_header CF-Connecting-IP;' /etc/nginx/sites-available/$domain
    fi
    
    # Khởi động lại Nginx
    nginx -t && systemctl restart nginx
    
    # Tạo index.html mẫu
    cat > /var/www/$domain/public_html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $domain</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            text-align: center;
        }
    </style>
</head>
<body>
    <h1>Welcome to $domain</h1>
    <p>Your website is ready to be configured.</p>
</body>
</html>
EOF
    
    log "Tạo virtual host cho $domain hoàn tất"
    echo -e "${GREEN}Virtual host cho $domain đã được tạo thành công!${NC}"
}

delete_vhost() {
    local domain=$1
    
    log "Bắt đầu xóa virtual host $domain..."
    
    # Xóa virtual host config
    rm -f /etc/nginx/sites-enabled/$domain
    rm -f /etc/nginx/sites-available/$domain
    
    # Xóa thư mục web
    rm -rf /var/www/$domain
    
    # Xóa database
    mysql -e "DROP DATABASE IF EXISTS ${domain//./_};"
    mysql -e "DROP USER IF EXISTS '${domain//./_}'@'localhost';"
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${domain//./_};"
    sudo -u postgres psql -c "DROP USER IF EXISTS ${domain//./_};"
    
    # Khởi động lại Nginx
    nginx -t && systemctl restart nginx
    
    log "Xóa virtual host $domain hoàn tất"
    echo -e "${GREEN}Virtual host $domain đã được xóa thành công!${NC}"
}

# Hiển thị menu quản lý domain
while true; do
    echo -e "${GREEN}=== Quản Lý Domain ===${NC}"
    echo "1) Thêm domain mới"
    echo "2) Xóa domain"
    echo "3) Quay lại menu chính"
    echo
    echo -n "Nhập lựa chọn của bạn [1-3]: "
    read -r domain_choice

    case $domain_choice in
        1)
            echo -n "Nhập tên miền (ví dụ: example.com): "
            read -r domain
            echo -n "Chọn phiên bản PHP (8.1/8.3): "
            read -r php_version
            echo -n "Chọn loại database (mariadb/postgresql/none): "
            read -r db_type
            echo -n "Sử dụng Cloudflare? (yes/no): "
            read -r use_cloudflare
            create_vhost "$domain" "$php_version" "$db_type" "$use_cloudflare"
            ;;
        2)
            echo -n "Nhập tên miền cần xóa: "
            read -r domain
            delete_vhost "$domain"
            ;;
        3)
            break
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            ;;
    esac

    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
done 