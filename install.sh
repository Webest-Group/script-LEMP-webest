#!/bin/bash

# Màu sắc cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Tạo thư mục logs nếu chưa tồn tại
mkdir -p logs

# Log file
LOG_FILE="logs/install_$(date +%Y%m%d_%H%M%S).log"

# Function ghi log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function kiểm tra OS
check_os() {
    if [[ -f /etc/lsb-release ]]; then
        os_version=$(lsb_release -rs)
        if [[ "$os_version" != "22.04" ]]; then
            echo -e "${RED}Script này chỉ hỗ trợ Ubuntu 22.04${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Script này chỉ hỗ trợ Ubuntu 22.04${NC}"
        exit 1
    fi
}

# Function kiểm tra quyền root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Script này cần chạy với quyền root${NC}"
        exit 1
    fi
}

# Function cập nhật system
update_system() {
    log "Đang cập nhật system..."
    apt update && apt upgrade -y
    log "Cập nhật system hoàn tất"
}

# Menu chính
show_menu() {
    clear
    echo -e "${GREEN}=== MENU CÀI ĐẶT SERVER ===${NC}"
    echo "1) Cài đặt Nginx"
    echo "2) Cài đặt PHP (8.1/8.3)"
    echo "3) Cài đặt Database (MariaDB/PostgreSQL)"
    echo "4) Cài đặt SSL (Let's Encrypt)"
    echo "5) Cài đặt Bảo mật (UFW/Fail2ban/ModSecurity)"
    echo "6) Cài đặt Monitoring Tools"
    echo "7) Cài đặt Performance Optimization"
    echo "8) Cài đặt Backup System"
    echo "9) Quản lý Domain"
    echo "10) Cài đặt Development Tools"
    echo "11) Cài đặt NodeJS & MongoDB"
    echo "12) Xem logs"
    echo "0) Thoát"
    echo
    echo -n "Nhập lựa chọn của bạn [0-12]: "
}

# Main script
check_root
check_os
update_system

while true; do
    show_menu
    read -r choice

    case $choice in
        1) source modules/webserver.sh ;;
        2) source modules/php.sh ;;
        3) source modules/database.sh ;;
        4) source modules/ssl.sh ;;
        5) source modules/security.sh ;;
        6) source modules/monitoring.sh ;;
        7) source modules/optimization.sh ;;
        8) source modules/backup.sh ;;
        9) source modules/domain.sh ;;
        10) source modules/development.sh ;;
        11) 
            if [ -f modules/nodejs_mongodb.sh ]; then
                source modules/nodejs_mongodb.sh
            else
                echo -e "${RED}Module NodeJS & MongoDB chưa được cài đặt.${NC}"
                sleep 2
            fi 
            ;;
        12) 
            if [ -f "$LOG_FILE" ]; then
                less "$LOG_FILE" 
            else
                echo -e "${RED}File log không tồn tại.${NC}"
                sleep 2
            fi
            ;;
        0) 
            echo -e "${GREEN}Cảm ơn bạn đã sử dụng script!${NC}"
            exit 0 
            ;;
        *) 
            echo -e "${RED}Lựa chọn không hợp lệ${NC}" 
            ;;
    esac

    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
done 