#!/bin/bash

# Danh sách các service cần kiểm tra
SERVICES=(
    "nginx"
    "php8.1-fpm"
    "mariadb"
    "redis-server"
    "supervisor"
)

# Hàm quản lý service
manage_service() {
    echo "1. Khởi động service"
    echo "2. Dừng service"
    echo "3. Khởi động lại service"
    echo "4. Kiểm tra trạng thái service"
    read -p "Chọn tác vụ: " choice
    
    case $choice in
        1) systemctl start $1 ;;
        2) systemctl stop $1 ;;
        3) systemctl restart $1 ;;
        4) systemctl status $1 ;;
        *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
    esac
} 