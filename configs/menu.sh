#!/bin/bash

# Menu chinh
show_main_menu() {
    echo -e "\n${YELLOW}=== WebEST VPS Panel ===${NC}"
    echo "1. Quan ly domain"
    echo "2. Quan ly database"
    echo "3. Cai dat SSL"
    echo "4. Backup"
    echo "5. Quan ly service"
    echo "6. Setup Git Hook"
    echo "7. Cap nhat WebEST VPS"
    echo "8. Cai dat PostgreSQL"
    echo "9. Thoat"
}

# Menu quan ly domain
show_domain_menu() {
    echo -e "\n${YELLOW}=== Quan ly Domain ===${NC}"
    echo "1. Tao domain moi"
    echo "2. Xoa domain"
    echo "3. Xem danh sach domain"
    echo "4. Tro ve menu chinh"
}

# Menu quan ly database
show_database_menu() {
    echo -e "\n${YELLOW}=== Quan ly Database ===${NC}"
    echo "1. Tao database moi"
    echo "2. Xoa database"
    echo "3. Xem danh sach database"
    echo "4. Tro ve menu chinh"
}

# Menu service
show_service_menu() {
    echo "1. Nginx"
    echo "2. PHP-FPM"
    echo "3. MariaDB"
    echo "4. Redis"
    echo "5. PostgreSQL"
} 