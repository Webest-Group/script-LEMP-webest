#!/bin/bash

# Menu chinh
show_main_menu() {
    echo -e "\n${YELLOW}=== WebEST VPS Panel ===${NC}"
    echo "1. Tao domain"
    echo "2. Cai dat SSL"
    echo "3. Tao database"
    echo "4. Backup"
    echo "5. Quan ly service"
    echo "6. Setup Git Hook"
    echo "7. Cap nhat WebEST VPS"
    echo "8. Thoat"
}

# Menu service
show_service_menu() {
    echo "1. Nginx"
    echo "2. PHP-FPM"
    echo "3. MariaDB"
    echo "4. Redis"
} 