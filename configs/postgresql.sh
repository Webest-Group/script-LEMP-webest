#!/bin/bash

# Hàm cài đặt PostgreSQL
install_postgresql() {
    echo -e "${YELLOW}Đang cài đặt PostgreSQL...${NC}"
    
    # Cài đặt PostgreSQL
    apt-get update
    apt-get install -y postgresql postgresql-contrib
    
    # Khởi động service
    systemctl start postgresql
    systemctl enable postgresql
    
    echo -e "${GREEN}Đã cài đặt PostgreSQL thành công!${NC}"
    echo -e "Mật khẩu mặc định cho user postgres: postgres"
    echo -e "Để thay đổi mật khẩu, sử dụng lệnh: sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD 'mật_khẩu_mới';\""
}

# Hàm tạo database PostgreSQL
create_postgresql_database() {
    read -p "Nhập tên database: " dbname
    read -p "Nhập tên user: " dbuser
    read -s -p "Nhập mật khẩu: " dbpass
    echo
    
    # Tạo database và user
    sudo -u postgres psql -c "CREATE DATABASE $dbname;"
    sudo -u postgres psql -c "CREATE USER $dbuser WITH PASSWORD '$dbpass';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $dbname TO $dbuser;"
    
    log "Đã tạo PostgreSQL database $dbname thành công"
}

# Hàm xóa database PostgreSQL
delete_postgresql_database() {
    read -p "Nhập tên database cần xóa: " dbname
    read -p "Nhập tên user cần xóa: " dbuser
    
    # Xóa database và user
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $dbname;"
    sudo -u postgres psql -c "DROP USER IF EXISTS $dbuser;"
    
    log "Đã xóa PostgreSQL database $dbname và user $dbuser thành công"
}

# Hàm hiển thị danh sách database PostgreSQL
list_postgresql_databases() {
    echo -e "\n${YELLOW}Danh sách PostgreSQL databases:${NC}"
    sudo -u postgres psql -c "\l"
    
    echo -e "\n${YELLOW}Danh sách PostgreSQL users:${NC}"
    sudo -u postgres psql -c "\du"
} 