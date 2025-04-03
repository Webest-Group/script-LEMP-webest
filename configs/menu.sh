#!/bin/bash

# Menu chính
show_main_menu() {
    echo -e "\n${YELLOW}=== WebEST VPS Panel ===${NC}"
    echo "1. Tạo domain"
    echo "2. Cài đặt SSL"
    echo "3. Tạo database"
    echo "4. Backup"
    echo "5. Quản lý service"
    echo "6. Cài đặt Laravel"
    echo "7. Thoát"
}

# Menu service
show_service_menu() {
    echo "1. Nginx"
    echo "2. PHP-FPM"
    echo "3. MariaDB"
    echo "4. Redis"
} 