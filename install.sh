#!/bin/bash

# Import các file cấu hình
source configs/colors.sh
source configs/paths.sh
source configs/functions.sh
source configs/dependencies.sh
source configs/services.sh
source configs/menu.sh
source configs/webestvps.sh

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Vui lòng chạy script với quyền root (sudo)${NC}"
    exit 1
fi

# Hàm cài đặt các gói cần thiết
install_dependencies() {
    log "Đang cài đặt các gói cần thiết..."
    
    # Cập nhật hệ thống
    apt-get update
    apt-get upgrade -y
    
    # Cài đặt các gói cơ bản
    apt-get install -y "${BASIC_PACKAGES[@]}"
    
    # Cài đặt Nginx
    apt-get install -y "${NGINX_PACKAGES[@]}"
    
    # Cài đặt MariaDB với mật khẩu root mặc định
    debconf-set-selections <<< 'mariadb-server mysql-server/root_password password webestroot'
    debconf-set-selections <<< 'mariadb-server mysql-server/root_password_again password webestroot'
    apt-get install -y "${MARIADB_PACKAGES[@]}"
    
    # Cài đặt PHP 8.1 và các module cần thiết
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt-get update
    apt-get install -y "${PHP_PACKAGES[@]}"
    
    # Cài đặt các gói khác
    apt-get install -y "${OTHER_PACKAGES[@]}"
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
$(cat configs/nginx.conf)
EOF
    
    # Khởi động lại Nginx
    systemctl restart nginx
    nginx -t
    
    # Cấu hình MariaDB
    if [ ! -f "/root/.my.cnf" ]; then
        cat > /root/.my.cnf << EOF
[client]
user=root
password=webestroot
EOF
        chmod 600 /root/.my.cnf
    fi
    
    # Cấu hình PHP
    if [ -f "configs/php.ini" ]; then
        while IFS= read -r line; do
            sed -i "s/^${line%=*}.*/$line/" /etc/php/8.1/fpm/php.ini
        done < configs/php.ini
    else
        # Cấu hình PHP mặc định nếu không có file cấu hình
        sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' /etc/php/8.1/fpm/php.ini
        sed -i 's/post_max_size = 8M/post_max_size = 64M/' /etc/php/8.1/fpm/php.ini
        sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.1/fpm/php.ini
        sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/8.1/fpm/php.ini
    fi
    
    systemctl restart php8.1-fpm
}

# Hàm kiểm tra cài đặt
check_installation() {
    log "Đang kiểm tra cài đặt..."
    
    # Kiểm tra các service
    for service in "${SERVICES[@]}"; do
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
    read -p "Chọn tác vụ: " choice
    
    case \$choice in
        1) create_domain ;;
        2) install_ssl ;;
        3) create_database ;;
        4) backup ;;
        5)
            show_service_menu
            read -p "Chọn service: " service_choice
            case \$service_choice in
                1) manage_service nginx ;;
                2) manage_service php8.1-fpm ;;
                3) manage_service mariadb ;;
                4) manage_service redis-server ;;
                *) echo -e "\${RED}Lựa chọn không hợp lệ\${NC}" ;;
            esac
            ;;
        6) install_laravel ;;
        7) exit 0 ;;
        *) echo -e "\${RED}Lựa chọn không hợp lệ\${NC}" ;;
    esac
done
EOF

chmod +x "$PANEL_SCRIPT"

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
