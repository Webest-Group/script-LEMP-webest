#!/bin/bash

# Mau sac cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ghi log
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Kiem tra quyen root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Vui long chay script voi quyen root (sudo)${NC}"
    exit 1
fi

echo -e "${YELLOW}=== Cai dat va Cau hinh PostgreSQL cho WebEST VPS Panel ===${NC}"

# Buoc 1: Cai dat PostgreSQL neu chua duoc cai dat
log "Kiem tra va cai dat PostgreSQL..."
if ! command -v psql &> /dev/null; then
    apt-get update
    apt-get install -y postgresql postgresql-contrib
    systemctl start postgresql
    systemctl enable postgresql
    log "Da cai dat PostgreSQL thanh cong"
else
    log "PostgreSQL da duoc cai dat"
fi

# Buoc 2: Tao file postgresql.sh neu chua ton tai
log "Tao file quan ly PostgreSQL..."
mkdir -p /usr/local/bin/configs
cat > /usr/local/bin/configs/postgresql.sh << 'EOF'
#!/bin/bash

# Ham cai dat PostgreSQL
install_postgresql() {
    echo -e "${YELLOW}Dang cai dat PostgreSQL...${NC}"
    
    # Cai dat PostgreSQL
    apt-get update
    apt-get install -y postgresql postgresql-contrib
    
    # Khoi dong service
    systemctl start postgresql
    systemctl enable postgresql
    
    echo -e "${GREEN}Da cai dat PostgreSQL thanh cong!${NC}"
    echo -e "Mat khau mac dinh cho user postgres: postgres"
    echo -e "De thay doi mat khau, su dung lenh: sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD 'mat_khau_moi';\""
}

# Ham tao database PostgreSQL
create_postgresql_database() {
    read -p "Nhap ten database: " dbname
    read -p "Nhap ten user: " dbuser
    read -s -p "Nhap mat khau: " dbpass
    echo
    
    # Tao database va user
    sudo -u postgres psql -c "CREATE DATABASE $dbname;"
    sudo -u postgres psql -c "CREATE USER $dbuser WITH PASSWORD '$dbpass';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $dbname TO $dbuser;"
    
    log "Da tao PostgreSQL database $dbname thanh cong"
}

# Ham xoa database PostgreSQL
delete_postgresql_database() {
    read -p "Nhap ten database can xoa: " dbname
    read -p "Nhap ten user can xoa: " dbuser
    
    # Xoa database va user
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $dbname;"
    sudo -u postgres psql -c "DROP USER IF EXISTS $dbuser;"
    
    log "Da xoa PostgreSQL database $dbname va user $dbuser thanh cong"
}

# Ham hien thi danh sach database PostgreSQL
list_postgresql_databases() {
    echo -e "\n${YELLOW}Danh sach PostgreSQL databases:${NC}"
    sudo -u postgres psql -c "\l"
    
    echo -e "\n${YELLOW}Danh sach PostgreSQL users:${NC}"
    sudo -u postgres psql -c "\du"
}

# Ham quan ly PostgreSQL
manage_postgresql() {
    while true; do
        echo -e "\n${YELLOW}=== Quan ly PostgreSQL ===${NC}"
        echo "1. Cai dat PostgreSQL"
        echo "2. Tao database"
        echo "3. Xoa database"
        echo "4. Xem danh sach database"
        echo "5. Quay lai menu chinh"
        read -p "Chon tac vu: " choice
        
        case $choice in
            1) install_postgresql ;;
            2) create_postgresql_database ;;
            3) delete_postgresql_database ;;
            4) list_postgresql_databases ;;
            5) return ;;
            *) echo -e "${RED}Lua chon khong hop le${NC}" ;;
        esac
    done
}
EOF
chmod +x /usr/local/bin/configs/postgresql.sh
log "Da tao file postgresql.sh"

# Buoc 3: Cap nhat file services.sh de them PostgreSQL
log "Cap nhat file services.sh..."
if [ -f "/usr/local/bin/configs/services.sh" ]; then
    # Kiem tra xem PostgreSQL da duoc them vao chua
    if grep -q "postgresql" /usr/local/bin/configs/services.sh; then
        log "PostgreSQL da duoc them vao file services.sh"
    else
        # Them PostgreSQL vao danh sach services
        sed -i '/SERVICES=(/a \ \ \ \ "postgresql"' /usr/local/bin/configs/services.sh
        log "Da them PostgreSQL vao file services.sh"
    fi
else
    log "File services.sh khong ton tai, se duoc tao khi cai dat WebEST VPS Panel"
fi

# Buoc 4: Cap nhat file menu.sh de them menu PostgreSQL
log "Cap nhat file menu.sh..."
if [ -f "/usr/local/bin/configs/menu.sh" ]; then
    # Kiem tra xem menu PostgreSQL da duoc them vao chua
    if grep -q "Cai dat PostgreSQL" /usr/local/bin/configs/menu.sh; then
        log "Menu PostgreSQL da duoc them vao file menu.sh"
    else
        # Them PostgreSQL vao menu chinh
        sed -i 's/echo "8. Thoat"/echo "8. Cai dat PostgreSQL"\n    echo "9. Thoat"/' /usr/local/bin/configs/menu.sh
        
        # Them PostgreSQL vao menu service
        sed -i '/echo "4. Redis"/a \ \ \ \ echo "5. PostgreSQL"' /usr/local/bin/configs/menu.sh
        log "Da them PostgreSQL vao file menu.sh"
    fi
else
    log "File menu.sh khong ton tai, se duoc tao khi cai dat WebEST VPS Panel"
fi

# Buoc 5: Cap nhat file webestvps chinh
log "Cap nhat file webestvps chinh..."
if [ -f "/usr/local/bin/webestvps" ]; then
    # Kiem tra xem postgresql.sh da duoc import chua
    if grep -q "postgresql.sh" /usr/local/bin/webestvps; then
        log "File postgresql.sh da duoc import trong webestvps"
    else
        # Them import postgresql.sh
        sed -i '/source "$CONFIG_DIR\/menu.sh"/a source "$CONFIG_DIR/postgresql.sh" || { echo "ERROR: Khong the import postgresql.sh"; exit 1; }' /usr/local/bin/webestvps
        log "Da them import postgresql.sh vao webestvps"
    fi
    
    # Kiem tra xu ly menu PostgreSQL
    if grep -q "8) manage_postgresql" /usr/local/bin/webestvps; then
        log "Xu ly menu PostgreSQL da ton tai trong webestvps"
    else
        # Thay the exit 0 de them menu PostgreSQL
        sed -i 's/7) update_webestvps ;;/7) update_webestvps ;;\n        8) manage_postgresql ;;/' /usr/local/bin/webestvps
        sed -i 's/8) exit 0 ;;/9) exit 0 ;;/' /usr/local/bin/webestvps
        log "Da them xu ly menu PostgreSQL vao webestvps"
    fi
else
    log "File webestvps khong ton tai, se duoc tao khi cai dat WebEST VPS Panel"
fi

# Buoc 6: Them PHP PostgreSQL module
log "Cai dat PHP PostgreSQL module..."
apt-get install -y php8.1-pgsql
systemctl restart php8.1-fpm

# Buoc 7: Khoi dong lai cac service
log "Khoi dong lai cac service..."
systemctl restart postgresql

# Hoan tat
echo -e "\n${GREEN}=== Cai dat va Cau hinh PostgreSQL Hoan Tat ===${NC}"
echo -e "Ban co the su dung lenh ${YELLOW}webestvps${NC} va chon option 8 de quan ly PostgreSQL"
echo -e "Mat khau mac dinh cho user postgres: ${YELLOW}postgres${NC}"
echo -e "De thay doi mat khau, su dung lenh: ${BLUE}sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD 'mat_khau_moi';\"${NC}" 