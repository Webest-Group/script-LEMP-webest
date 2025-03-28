#!/bin/bash

install_redis() {
    log "Bắt đầu cài đặt Redis..."
    
    apt install -y redis-server
    
    # Backup file cấu hình gốc
    cp /etc/redis/redis.conf /etc/redis/redis.conf.backup
    
    # Cấu hình Redis
    sed -i 's/# maxmemory <bytes>/maxmemory 256mb/' /etc/redis/redis.conf
    sed -i 's/# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf
    
    # Khởi động lại Redis
    systemctl restart redis-server
    systemctl enable redis-server
    
    log "Cài đặt Redis hoàn tất"
    echo -e "${GREEN}Redis đã được cài đặt và cấu hình thành công!${NC}"
}

install_memcached() {
    log "Bắt đầu cài đặt Memcached..."
    
    apt install -y memcached
    
    # Cấu hình Memcached
    sed -i 's/-m 64/-m 256/' /etc/memcached.conf
    sed -i 's/-l 127.0.0.1/-l 0.0.0.0/' /etc/memcached.conf
    
    # Khởi động lại Memcached
    systemctl restart memcached
    systemctl enable memcached
    
    log "Cài đặt Memcached hoàn tất"
    echo -e "${GREEN}Memcached đã được cài đặt và cấu hình thành công!${NC}"
}

optimize_php() {
    log "Bắt đầu tối ưu PHP..."
    
    # Tối ưu PHP 8.1
    if [ -f /etc/php/8.1/fpm/php.ini ]; then
        sed -i 's/opcache.enable=.*/opcache.enable=1/' /etc/php/8.1/fpm/php.ini
        sed -i 's/opcache.memory_consumption=.*/opcache.memory_consumption=256/' /etc/php/8.1/fpm/php.ini
        sed -i 's/opcache.max_accelerated_files=.*/opcache.max_accelerated_files=20000/' /etc/php/8.1/fpm/php.ini
        sed -i 's/opcache.revalidate_freq=.*/opcache.revalidate_freq=0/' /etc/php/8.1/fpm/php.ini
        systemctl restart php8.1-fpm
    fi
    
    # Tối ưu PHP 8.3
    if [ -f /etc/php/8.3/fpm/php.ini ]; then
        sed -i 's/opcache.enable=.*/opcache.enable=1/' /etc/php/8.3/fpm/php.ini
        sed -i 's/opcache.memory_consumption=.*/opcache.memory_consumption=256/' /etc/php/8.3/fpm/php.ini
        sed -i 's/opcache.max_accelerated_files=.*/opcache.max_accelerated_files=20000/' /etc/php/8.3/fpm/php.ini
        sed -i 's/opcache.revalidate_freq=.*/opcache.revalidate_freq=0/' /etc/php/8.3/fpm/php.ini
        systemctl restart php8.3-fpm
    fi
    
    log "Tối ưu PHP hoàn tất"
    echo -e "${GREEN}PHP đã được tối ưu thành công!${NC}"
}

optimize_nginx() {
    log "Bắt đầu tối ưu Nginx..."
    
    # Tối ưu worker_processes và worker_connections
    sed -i "s/worker_processes.*/worker_processes auto;/" /etc/nginx/nginx.conf
    sed -i "s/worker_connections.*/worker_connections 2048;/" /etc/nginx/nginx.conf
    
    # Thêm các tối ưu khác
    cat > /etc/nginx/conf.d/optimization.conf <<EOF
# Microcache
fastcgi_cache_path /tmp/nginx_cache levels=1:2 keys_zone=my_cache:10m max_size=10g inactive=60m use_temp_path=off;
fastcgi_cache_key "\$request_method\$request_uri\$args";
fastcgi_cache_use_stale error timeout invalid_header http_500;
fastcgi_cache_valid 200 301 302 60m;
fastcgi_cache_valid 404 1m;

# Gzip Compression
gzip_comp_level 6;
gzip_min_length 1100;
gzip_buffers 16 8k;
gzip_proxied any;
gzip_types
    text/plain
    text/css
    text/js
    text/xml
    text/javascript
    application/javascript
    application/x-javascript
    application/json
    application/xml
    application/xml+rss
    image/svg+xml;
gzip_vary on;

# Browser Cache
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg)$ {
    expires 365d;
    add_header Cache-Control "public, no-transform";
}
EOF
    
    # Khởi động lại Nginx
    systemctl restart nginx
    
    log "Tối ưu Nginx hoàn tất"
    echo -e "${GREEN}Nginx đã được tối ưu thành công!${NC}"
}

# Hiển thị menu tối ưu
while true; do
    echo -e "${GREEN}=== Tối Ưu Hiệu Suất ===${NC}"
    echo "1) Cài đặt Redis"
    echo "2) Cài đặt Memcached"
    echo "3) Tối ưu PHP"
    echo "4) Tối ưu Nginx"
    echo "5) Tối ưu tất cả"
    echo "6) Quay lại menu chính"
    echo
    echo -n "Nhập lựa chọn của bạn [1-6]: "
    read -r optimization_choice

    case $optimization_choice in
        1)
            install_redis
            ;;
        2)
            install_memcached
            ;;
        3)
            optimize_php
            ;;
        4)
            optimize_nginx
            ;;
        5)
            install_redis
            install_memcached
            optimize_php
            optimize_nginx
            ;;
        6)
            break
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            ;;
    esac

    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
done 