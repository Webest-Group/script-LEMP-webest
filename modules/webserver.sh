#!/bin/bash

install_nginx() {
    log "Bắt đầu cài đặt Nginx..."
    
    # Thêm repository nginx
    apt install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring
    curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
        | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
    
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
    http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" \
        | tee /etc/apt/sources.list.d/nginx.list
    
    # Cài đặt nginx
    apt update
    apt install -y nginx
    
    # Tạo thư mục cho virtual hosts
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled
    
    # Backup file cấu hình gốc
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    
    # Tạo cấu hình nginx tối ưu
    cat > /etc/nginx/nginx.conf <<EOF
user nginx;
worker_processes auto;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    multi_accept on;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;
    
    # Tối ưu hiệu suất
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    # Giới hạn kích thước body
    client_max_body_size 64M;
    
    # Bảo mật
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;
    
    # Virtual Hosts
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

    # Tạo virtual host mặc định
    cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.php index.html index.htm;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    # PHP-FPM Configuration
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    # Deny access to . files
    location ~ /\. {
        deny all;
    }
}
EOF

    # Tạo thư mục web root
    mkdir -p /var/www/html
    chown -R nginx:nginx /var/www/html
    
    # Kiểm tra cấu hình và khởi động lại nginx
    nginx -t
    if [ $? -eq 0 ]; then
        systemctl restart nginx
        systemctl enable nginx
        log "Cài đặt Nginx hoàn tất"
        echo -e "${GREEN}Nginx đã được cài đặt và cấu hình thành công!${NC}"
    else
        log "Lỗi trong file cấu hình Nginx"
        echo -e "${RED}Có lỗi trong file cấu hình Nginx. Vui lòng kiểm tra logs.${NC}"
    fi
}

# Hiển thị menu cài đặt Nginx
echo -e "${GREEN}=== Cài đặt Nginx ===${NC}"
echo "1) Cài đặt Nginx"
echo "2) Quay lại menu chính"
echo
echo -n "Nhập lựa chọn của bạn [1-2]: "
read -r nginx_choice

case $nginx_choice in
    1) install_nginx ;;
    2) return ;;
    *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
esac 