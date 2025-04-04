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

echo -e "${YELLOW}=== Cai dat va Cau hinh PHP 8.3 cho WebEST VPS Panel ===${NC}"

# Buoc 1: Them PPA cho PHP 8.3
log "Them PPA cho PHP 8.3..."
apt-get update
apt-get install -y software-properties-common
add-apt-repository ppa:ondrej/php -y
apt-get update

# Buoc 2: Cai dat PHP 8.3
log "Cai dat PHP 8.3 va cac extension..."
apt-get install -y php8.3-fpm php8.3-cli php8.3-common php8.3-mysql php8.3-zip php8.3-gd php8.3-mbstring php8.3-curl php8.3-xml php8.3-bcmath php8.3-intl php8.3-pgsql

# Buoc 3: Tao file php83.sh
log "Tao file quan ly PHP 8.3..."
mkdir -p /usr/local/bin/configs
cat > /usr/local/bin/configs/php83.sh << 'EOF'
#!/bin/bash

# Ham cai dat PHP 8.3
install_php83() {
    echo -e "${YELLOW}Dang cai dat PHP 8.3...${NC}"
    
    # Them PPA neu chua
    apt-get update
    apt-get install -y software-properties-common
    add-apt-repository ppa:ondrej/php -y
    apt-get update
    
    # Cai dat PHP 8.3
    apt-get install -y php8.3-fpm php8.3-cli php8.3-common php8.3-mysql php8.3-zip php8.3-gd php8.3-mbstring php8.3-curl php8.3-xml php8.3-bcmath php8.3-intl php8.3-pgsql
    
    # Khoi dong service
    systemctl start php8.3-fpm
    systemctl enable php8.3-fpm
    
    echo -e "${GREEN}Da cai dat PHP 8.3 thanh cong!${NC}"
}

# Ham cau hinh PHP 8.3
configure_php83() {
    echo -e "${YELLOW}Dang cau hinh PHP 8.3...${NC}"
    
    # Tao backup
    cp /etc/php/8.3/fpm/php.ini /etc/php/8.3/fpm/php.ini.bak
    
    # Cau hinh PHP
    sed -i 's/memory_limit = .*/memory_limit = 256M/' /etc/php/8.3/fpm/php.ini
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' /etc/php/8.3/fpm/php.ini
    sed -i 's/post_max_size = .*/post_max_size = 64M/' /etc/php/8.3/fpm/php.ini
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.3/fpm/php.ini
    
    # Khoi dong lai PHP-FPM
    systemctl restart php8.3-fpm
    
    echo -e "${GREEN}Da cau hinh PHP 8.3 thanh cong!${NC}"
}

# Ham chuyen doi Nginx sang su dung PHP 8.3
switch_to_php83() {
    echo -e "${YELLOW}Dang chuyen doi Nginx sang su dung PHP 8.3...${NC}"
    
    # Tim tat ca cac file cau hinh Nginx
    nginx_configs=$(find /etc/nginx/sites-available -type f)
    
    for config in $nginx_configs; do
        # Kiem tra xem file co chua fastcgi_pass va php-fpm socket khong
        if grep -q "fastcgi_pass.*php.*-fpm.sock" "$config"; then
            # Thay the php*-fpm.sock bang php8.3-fpm.sock
            sed -i 's/fastcgi_pass unix:\/var\/run\/php\/php[0-9]\.[0-9]-fpm\.sock/fastcgi_pass unix:\/var\/run\/php\/php8.3-fpm.sock/g' "$config"
            echo -e "Da cap nhat file cau hinh: ${GREEN}$config${NC}"
        fi
    done
    
    # Khoi dong lai Nginx
    systemctl restart nginx
    
    echo -e "${GREEN}Da chuyen doi Nginx sang su dung PHP 8.3 thanh cong!${NC}"
}

# Ham quan ly PHP 8.3
manage_php83() {
    while true; do
        echo -e "\n${YELLOW}=== Quan ly PHP 8.3 ===${NC}"
        echo "1. Cai dat PHP 8.3"
        echo "2. Cau hinh PHP 8.3"
        echo "3. Chuyen doi Nginx sang PHP 8.3"
        echo "4. Kiem tra phien ban PHP"
        echo "5. Quay lai menu chinh"
        read -p "Chon tac vu: " choice
        
        case $choice in
            1) install_php83 ;;
            2) configure_php83 ;;
            3) switch_to_php83 ;;
            4) php -v ;;
            5) return ;;
            *) echo -e "${RED}Lua chon khong hop le${NC}" ;;
        esac
    done
}
EOF
chmod +x /usr/local/bin/configs/php83.sh
log "Da tao file php83.sh"

# Buoc 4: Cap nhat menu.sh de them menu cai dat them
log "Cap nhat file menu.sh..."
if [ -f "/usr/local/bin/configs/menu.sh" ]; then
    # Them menu cai dat them vao menu chinh neu chua co
    if ! grep -q "Cai dat them" /usr/local/bin/configs/menu.sh; then
        # Neu co option Cai dat PostgreSQL, chuyen no vao menu cai dat them
        if grep -q "Cai dat PostgreSQL" /usr/local/bin/configs/menu.sh; then
            # Thay the menu PostgreSQL bang menu cai dat them
            sed -i 's/echo "8. Cai dat PostgreSQL"/echo "8. Cai dat them"/' /usr/local/bin/configs/menu.sh
        else
            # Them menu cai dat them vao truoc Thoat
            sed -i 's/echo "8. Thoat"/echo "8. Cai dat them"\n    echo "9. Thoat"/' /usr/local/bin/configs/menu.sh
        fi
        log "Da them menu Cai dat them vao menu chinh"
    fi
    
    # Tao menu cai dat them neu chua co
    if ! grep -q "show_install_menu" /usr/local/bin/configs/menu.sh; then
        cat >> /usr/local/bin/configs/menu.sh << 'EOF'

# Menu cai dat them
show_install_menu() {
    echo -e "\n${YELLOW}=== Cai dat them ===${NC}"
    echo "1. Cai dat PostgreSQL"
    echo "2. Cai dat PHP 8.3"
    echo "3. Tro ve menu chinh"
}
EOF
        log "Da tao menu Cai dat them"
    else
        # Kiem tra xem PHP 8.3 da co trong menu cai dat them chua
        if ! grep -q "Cai dat PHP 8.3" /usr/local/bin/configs/menu.sh; then
            # Them PHP 8.3 vao menu cai dat them
            sed -i '/show_install_menu/,/}/ s/echo "2. Tro ve menu chinh"/echo "2. Cai dat PHP 8.3"\n    echo "3. Tro ve menu chinh"/' /usr/local/bin/configs/menu.sh
            log "Da them PHP 8.3 vao menu Cai dat them"
        fi
    fi
else
    log "File menu.sh khong ton tai, se duoc tao khi cai dat WebEST VPS Panel"
fi

# Buoc 5: Cap nhat file webestvps.sh de xu ly menu cai dat them
log "Cap nhat file webestvps.sh..."
if [ -f "/usr/local/bin/configs/webestvps.sh" ]; then
    # Kiem tra ham xu ly menu cai dat them
    if ! grep -q "manage_install_menu" /usr/local/bin/configs/webestvps.sh; then
        # Them ham xu ly menu cai dat them
        cat >> /usr/local/bin/configs/webestvps.sh << 'EOF'

# Ham quan ly menu cai dat them
manage_install_menu() {
    while true; do
        show_install_menu
        read -p "Chon tac vu: " choice
        
        case $choice in
            1) manage_postgresql ;;
            2) manage_php83 ;;
            3) return ;;
            *) echo -e "${RED}Lua chon khong hop le${NC}" ;;
        esac
    done
}
EOF
        log "Da them ham xu ly menu cai dat them"
        
        # Them xu ly cho menu cai dat them trong menu chinh
        sed -i 's/8) manage_postgresql ;;/8) manage_install_menu ;;/' /usr/local/bin/configs/webestvps.sh
        log "Da cap nhat xu ly menu cai dat them trong menu chinh"
    fi
else
    log "File webestvps.sh khong ton tai, se duoc tao khi cai dat WebEST VPS Panel"
fi

# Buoc 6: Cap nhat file webestvps chinh de import php83.sh
log "Cap nhat file webestvps chinh..."
if [ -f "/usr/local/bin/webestvps" ]; then
    # Them import php83.sh neu chua co
    if ! grep -q "php83.sh" /usr/local/bin/webestvps; then
        sed -i '/source "$CONFIG_DIR\/postgresql.sh"/a source "$CONFIG_DIR/php83.sh" || { echo "ERROR: Khong the import php83.sh"; exit 1; }' /usr/local/bin/webestvps
        log "Da them import php83.sh vao webestvps"
    fi
else
    log "File webestvps khong ton tai, se duoc tao khi cai dat WebEST VPS Panel"
fi

# Buoc 7: Cap nhat services.sh de them PHP 8.3
log "Cap nhat file services.sh..."
if [ -f "/usr/local/bin/configs/services.sh" ]; then
    # Them PHP 8.3 vao danh sach service neu chua co
    if ! grep -q "php8.3-fpm" /usr/local/bin/configs/services.sh; then
        sed -i '/SERVICES=(/a \ \ \ \ "php8.3-fpm"' /usr/local/bin/configs/services.sh
        log "Da them PHP 8.3 vao danh sach service"
    fi
else
    log "File services.sh khong ton tai, se duoc tao khi cai dat WebEST VPS Panel"
fi

# Buoc 8: Khoi dong lai PHP 8.3 va Nginx
log "Khoi dong lai cac service..."
systemctl restart php8.3-fpm
systemctl restart nginx

# Hoan tat
echo -e "\n${GREEN}=== Cai dat va Cau hinh PHP 8.3 Hoan Tat ===${NC}"
echo -e "Ban co the su dung lenh ${YELLOW}webestvps${NC} va chon menu Cai dat them > Cai dat PHP 8.3 de quan ly PHP 8.3"
echo -e "Phien ban PHP hien tai: ${YELLOW}$(php8.3 -v | head -n1 | cut -d' ' -f2)${NC}" 