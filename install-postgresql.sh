#!/bin/bash

# Màu sắc cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ghi log
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Vui lòng chạy script với quyền root (sudo)${NC}"
    exit 1
fi

echo -e "${YELLOW}=== Cài đặt và Cấu hình PostgreSQL cho WebEST VPS Panel ===${NC}"

# Bước 1: Cài đặt PostgreSQL nếu chưa được cài đặt
log "Kiểm tra và cài đặt PostgreSQL..."
if ! command -v psql &> /dev/null; then
    apt-get update
    apt-get install -y postgresql postgresql-contrib
    systemctl start postgresql
    systemctl enable postgresql
    log "Đã cài đặt PostgreSQL thành công"
else
    log "PostgreSQL đã được cài đặt"
fi

# Bước 2: Tạo file postgresql.sh nếu chưa tồn tại
log "Tạo file quản lý PostgreSQL..."
mkdir -p /usr/local/bin/configs
cat > /usr/local/bin/configs/postgresql.sh << 'EOF'
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

# Hàm quản lý PostgreSQL
manage_postgresql() {
    while true; do
        echo -e "\n${YELLOW}=== Quản lý PostgreSQL ===${NC}"
        echo "1. Cài đặt PostgreSQL"
        echo "2. Tạo database"
        echo "3. Xóa database"
        echo "4. Xem danh sách database"
        echo "5. Quay lại menu chính"
        read -p "Chọn tác vụ: " choice
        
        case $choice in
            1) install_postgresql ;;
            2) create_postgresql_database ;;
            3) delete_postgresql_database ;;
            4) list_postgresql_databases ;;
            5) return ;;
            *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
        esac
    done
}
EOF
chmod +x /usr/local/bin/configs/postgresql.sh
log "Đã tạo file postgresql.sh"

# Bước 3: Cập nhật file services.sh để thêm PostgreSQL
log "Cập nhật file services.sh..."
if [ -f "/usr/local/bin/configs/services.sh" ]; then
    # Kiểm tra xem PostgreSQL đã được thêm vào chưa
    if grep -q "postgresql" /usr/local/bin/configs/services.sh; then
        log "PostgreSQL đã được thêm vào file services.sh"
    else
        # Thêm PostgreSQL vào danh sách services
        sed -i '/SERVICES=(/a \ \ \ \ "postgresql"' /usr/local/bin/configs/services.sh
        log "Đã thêm PostgreSQL vào file services.sh"
    fi
else
    log "File services.sh không tồn tại, sẽ được tạo khi cài đặt WebEST VPS Panel"
fi

# Bước 4: Cập nhật file menu.sh để thêm menu PostgreSQL
log "Cập nhật file menu.sh..."
if [ -f "/usr/local/bin/configs/menu.sh" ]; then
    # Kiểm tra xem menu PostgreSQL đã được thêm vào chưa
    if grep -q "Cai dat PostgreSQL" /usr/local/bin/configs/menu.sh; then
        log "Menu PostgreSQL đã được thêm vào file menu.sh"
    else
        # Thêm PostgreSQL vào menu chính
        sed -i 's/echo "8. Thoat"/echo "8. Cai dat PostgreSQL"\n    echo "9. Thoat"/' /usr/local/bin/configs/menu.sh
        
        # Thêm PostgreSQL vào menu service
        sed -i '/echo "4. Redis"/a \ \ \ \ echo "5. PostgreSQL"' /usr/local/bin/configs/menu.sh
        log "Đã thêm PostgreSQL vào file menu.sh"
    fi
else
    log "File menu.sh không tồn tại, sẽ được tạo khi cài đặt WebEST VPS Panel"
fi

# Bước 5: Cập nhật file webestvps chính
log "Cập nhật file webestvps chính..."
if [ -f "/usr/local/bin/webestvps" ]; then
    # Kiểm tra xem postgresql.sh đã được import chưa
    if grep -q "postgresql.sh" /usr/local/bin/webestvps; then
        log "File postgresql.sh đã được import trong webestvps"
    else
        # Thêm import postgresql.sh
        sed -i '/source "$CONFIG_DIR\/menu.sh"/a source "$CONFIG_DIR/postgresql.sh" || { echo "ERROR: Khong the import postgresql.sh"; exit 1; }' /usr/local/bin/webestvps
        log "Đã thêm import postgresql.sh vào webestvps"
    fi
    
    # Kiểm tra xử lý menu PostgreSQL
    if grep -q "8) manage_postgresql" /usr/local/bin/webestvps; then
        log "Xử lý menu PostgreSQL đã tồn tại trong webestvps"
    else
        # Thay thế exit 0 để thêm menu PostgreSQL
        sed -i 's/7) update_webestvps ;;/7) update_webestvps ;;\n        8) manage_postgresql ;;/' /usr/local/bin/webestvps
        sed -i 's/8) exit 0 ;;/9) exit 0 ;;/' /usr/local/bin/webestvps
        log "Đã thêm xử lý menu PostgreSQL vào webestvps"
    fi
else
    log "File webestvps không tồn tại, sẽ được tạo khi cài đặt WebEST VPS Panel"
fi

# Bước 6: Thêm PHP PostgreSQL module
log "Cài đặt PHP PostgreSQL module..."
apt-get install -y php8.1-pgsql
systemctl restart php8.1-fpm

# Bước 7: Khởi động lại các service
log "Khởi động lại các service..."
systemctl restart postgresql

# Hoàn tất
echo -e "\n${GREEN}=== Cài đặt và Cấu hình PostgreSQL Hoàn Tất ===${NC}"
echo -e "Bạn có thể sử dụng lệnh ${YELLOW}webestvps${NC} và chọn option 8 để quản lý PostgreSQL"
echo -e "Mật khẩu mặc định cho user postgres: ${YELLOW}postgres${NC}"
echo -e "Để thay đổi mật khẩu, sử dụng lệnh: ${BLUE}sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD 'mật_khẩu_mới';\"${NC}" 