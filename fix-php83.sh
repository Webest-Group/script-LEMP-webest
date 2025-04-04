#!/bin/bash

# Mau sac cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}=== Fix loi PHP 8.3 trong WebEST VPS Panel ===${NC}"

# Kiem tra quyen root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Vui long chay script voi quyen root (sudo)${NC}"
    exit 1
fi

# Tao thu muc configs neu chua co
if [ ! -d "/usr/local/bin/configs" ]; then
    mkdir -p /usr/local/bin/configs
    echo -e "${GREEN}Da tao thu muc /usr/local/bin/configs${NC}"
fi

# Tao hoac cap nhat file php83.sh
echo -e "${YELLOW}Dang tao file php83.sh...${NC}"
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
echo -e "${GREEN}Da tao file php83.sh thanh cong${NC}"

# Cap nhat file webestvps de import php83.sh
echo -e "${YELLOW}Dang cap nhat file webestvps...${NC}"
if [ -f "/usr/local/bin/webestvps" ]; then
    # Kiem tra xem php83.sh da duoc import chua
    if grep -q "php83.sh" /usr/local/bin/webestvps; then
        echo -e "${GREEN}File php83.sh da duoc import trong webestvps${NC}"
    else
        # Them import php83.sh vao sau import postgresql.sh
        sed -i '/source "$CONFIG_DIR\/postgresql.sh"/a source "$CONFIG_DIR/php83.sh" || { echo "ERROR: Khong the import php83.sh"; exit 1; }' /usr/local/bin/webestvps
        echo -e "${GREEN}Da them import php83.sh vao webestvps${NC}"
    fi
else
    echo -e "${RED}Khong tim thay file webestvps${NC}"
    exit 1
fi

# Cap nhat file webestvps.sh de sua loi quan ly menu cai dat them
echo -e "${YELLOW}Dang cap nhat file webestvps.sh...${NC}"
if [ -f "/usr/local/bin/configs/webestvps.sh" ]; then
    # Kiem tra xem manage_install_menu da ton tai chua
    if grep -q "manage_install_menu" /usr/local/bin/configs/webestvps.sh; then
        # Sua lai ham manage_install_menu
        sed -i '/manage_install_menu/,/^}/c\
# Ham quan ly menu cai dat them\
manage_install_menu() {\
    while true; do\
        show_install_menu\
        read -p "Chon tac vu: " choice\
        \
        case $choice in\
            1) manage_postgresql ;;\
            2) \
                if type manage_php83 >/dev/null 2>&1; then\
                    manage_php83\
                else\
                    echo -e "${RED}Ham manage_php83 khong ton tai${NC}"\
                    echo -e "${YELLOW}Dang tai ham tu file php83.sh...${NC}"\
                    if [ -f "$CONFIG_DIR/php83.sh" ]; then\
                        source "$CONFIG_DIR/php83.sh"\
                        manage_php83\
                    else\
                        echo -e "${RED}File php83.sh khong ton tai${NC}"\
                    fi\
                fi\
                ;;\
            3) return ;;\
            *) echo -e "${RED}Lua chon khong hop le${NC}" ;;\
        esac\
    done\
}' /usr/local/bin/configs/webestvps.sh
        echo -e "${GREEN}Da sua lai ham manage_install_menu trong webestvps.sh${NC}"
    else
        # Them ham manage_install_menu vao cuoi file
        cat >> /usr/local/bin/configs/webestvps.sh << 'EOF'

# Ham quan ly menu cai dat them
manage_install_menu() {
    while true; do
        show_install_menu
        read -p "Chon tac vu: " choice
        
        case $choice in
            1) manage_postgresql ;;
            2) 
                if type manage_php83 >/dev/null 2>&1; then
                    manage_php83
                else
                    echo -e "${RED}Ham manage_php83 khong ton tai${NC}"
                    echo -e "${YELLOW}Dang tai ham tu file php83.sh...${NC}"
                    if [ -f "$CONFIG_DIR/php83.sh" ]; then
                        source "$CONFIG_DIR/php83.sh"
                        manage_php83
                    else
                        echo -e "${RED}File php83.sh khong ton tai${NC}"
                    fi
                fi
                ;;
            3) return ;;
            *) echo -e "${RED}Lua chon khong hop le${NC}" ;;
        esac
    done
}
EOF
        echo -e "${GREEN}Da them ham manage_install_menu vao webestvps.sh${NC}"
        
        # Them xu ly cho option 8 trong menu chinh
        sed -i 's/8) manage_postgresql ;;/8) manage_install_menu ;;/' /usr/local/bin/configs/webestvps.sh
        echo -e "${GREEN}Da cap nhat xu ly menu chinh trong webestvps.sh${NC}"
    fi
else
    echo -e "${RED}Khong tim thay file webestvps.sh${NC}"
    exit 1
fi

# Khoi dong lai panel
echo -e "${YELLOW}Dang khoi dong lai WebEST VPS Panel...${NC}"
kill -9 $(pgrep -f webestvps) >/dev/null 2>&1

# Hoan tat
echo -e "\n${GREEN}=== Fix loi PHP 8.3 hoan tat ===${NC}"
echo -e "Vui long chay lai lenh ${YELLOW}webestvps${NC} va chon menu Cai dat them > Cai dat PHP 8.3" 