#!/bin/bash

install_php_version() {
    local version=$1
    log "Bắt đầu cài đặt PHP $version..."
    
    # Thêm repository
    add-apt-repository -y ppa:ondrej/php
    apt update
    
    # Cài đặt PHP và các extension
    apt install -y php$version php$version-fpm php$version-common \
    php$version-mysql php$version-xml php$version-xmlrpc php$version-curl \
    php$version-gd php$version-imagick php$version-cli php$version-dev \
    php$version-imap php$version-mbstring php$version-opcache php$version-soap \
    php$version-zip php$version-intl php$version-bcmath
    
    # Backup file cấu hình gốc
    cp /etc/php/$version/fpm/php.ini /etc/php/$version/fpm/php.ini.backup
    cp /etc/php/$version/fpm/pool.d/www.conf /etc/php/$version/fpm/pool.d/www.conf.backup
    
    # Cấu hình PHP
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' /etc/php/$version/fpm/php.ini
    sed -i 's/post_max_size = 8M/post_max_size = 64M/' /etc/php/$version/fpm/php.ini
    sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/$version/fpm/php.ini
    sed -i 's/max_execution_time = 30/max_execution_time = 180/' /etc/php/$version/fpm/php.ini
    sed -i 's/max_input_time = 60/max_input_time = 180/' /etc/php/$version/fpm/php.ini
    
    # Cấu hình PHP-FPM
    sed -i 's/pm = dynamic/pm = ondemand/' /etc/php/$version/fpm/pool.d/www.conf
    sed -i 's/pm.max_children = 5/pm.max_children = 50/' /etc/php/$version/fpm/pool.d/www.conf
    sed -i 's/pm.start_servers = 2/pm.start_servers = 5/' /etc/php/$version/fpm/pool.d/www.conf
    sed -i 's/pm.min_spare_servers = 1/pm.min_spare_servers = 5/' /etc/php/$version/fpm/pool.d/www.conf
    sed -i 's/pm.max_spare_servers = 3/pm.max_spare_servers = 35/' /etc/php/$version/fpm/pool.d/www.conf
    
    # Khởi động lại PHP-FPM
    systemctl restart php$version-fpm
    systemctl enable php$version-fpm
    
    log "Cài đặt PHP $version hoàn tất"
    echo -e "${GREEN}PHP $version đã được cài đặt và cấu hình thành công!${NC}"
}

install_composer() {
    log "Bắt đầu cài đặt Composer..."
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
    log "Cài đặt Composer hoàn tất"
    echo -e "${GREEN}Composer đã được cài đặt thành công!${NC}"
}

# Hiển thị menu cài đặt PHP
while true; do
    echo -e "${GREEN}=== Cài đặt PHP ===${NC}"
    echo "1) Cài đặt PHP 8.1"
    echo "2) Cài đặt PHP 8.3"
    echo "3) Cài đặt Composer"
    echo "4) Cài đặt cả PHP 8.1 và 8.3"
    echo "5) Quay lại menu chính"
    echo
    echo -n "Nhập lựa chọn của bạn [1-5]: "
    read -r php_choice

    case $php_choice in
        1) 
            install_php_version "8.1"
            ;;
        2)
            install_php_version "8.3"
            ;;
        3)
            install_composer
            ;;
        4)
            install_php_version "8.1"
            install_php_version "8.3"
            install_composer
            ;;
        5)
            break
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            ;;
    esac

    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
done 