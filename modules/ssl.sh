#!/bin/bash

# Màu sắc cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Log file
LOG_FILE="../logs/install_$(date +%Y%m%d_%H%M%S).log"

# Function ghi log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Tiêu đề
clear
echo -e "${GREEN}=== CÀI ĐẶT SSL (LET'S ENCRYPT) ===${NC}"
echo

# Kiểm tra xem Certbot đã được cài đặt chưa
if ! command -v certbot &> /dev/null; then
    log "Đang cài đặt Certbot..."
    apt update
    apt install -y certbot python3-certbot-nginx
    log "Certbot đã được cài đặt thành công"
else
    log "Certbot đã được cài đặt trước đó"
fi

# Menu SSL
show_ssl_menu() {
    echo
    echo "1) Cài đặt SSL cho domain mới"
    echo "2) Gia hạn tất cả SSL hiện có"
    echo "3) Xem danh sách SSL hiện có"
    echo "4) Xóa SSL"
    echo "0) Quay lại menu chính"
    echo
    echo -n "Nhập lựa chọn của bạn [0-4]: "
}

# Function cài đặt SSL cho domain
install_ssl() {
    echo
    echo -n "Nhập tên miền (VD: example.com): "
    read -r domain
    
    # Kiểm tra xem domain có tồn tại trong cấu hình Nginx không
    if [ ! -f "/etc/nginx/sites-available/$domain" ]; then
        echo -e "${RED}Domain $domain không tồn tại trong cấu hình Nginx!${NC}"
        echo -e "${YELLOW}Vui lòng thêm domain vào Nginx trước khi cài đặt SSL.${NC}"
        return 1
    fi
    
    log "Đang cài đặt SSL cho domain $domain..."
    certbot --nginx -d "$domain" -d "www.$domain"
    
    if [ $? -eq 0 ]; then
        log "Cài đặt SSL cho domain $domain thành công!"
        echo -e "${GREEN}SSL cho domain $domain đã được cài đặt thành công!${NC}"
        
        # Kiểm tra và đảm bảo cron job cho certbot đã được cài đặt
        if ! crontab -l | grep -q 'certbot renew'; then
            (crontab -l 2>/dev/null; echo "0 3 * * * /usr/bin/certbot renew --quiet") | crontab -
            log "Đã thêm cron job tự động gia hạn SSL"
        fi
    else
        log "Cài đặt SSL cho domain $domain thất bại!"
        echo -e "${RED}Cài đặt SSL thất bại. Vui lòng kiểm tra lại!${NC}"
    fi
}

# Function gia hạn tất cả SSL hiện có
renew_ssl() {
    log "Đang gia hạn tất cả SSL..."
    certbot renew
    
    if [ $? -eq 0 ]; then
        log "Gia hạn SSL thành công!"
        echo -e "${GREEN}Tất cả SSL đã được gia hạn thành công!${NC}"
    else
        log "Gia hạn SSL thất bại!"
        echo -e "${RED}Gia hạn SSL thất bại. Vui lòng kiểm tra lại!${NC}"
    fi
}

# Function xem danh sách SSL hiện có
list_ssl() {
    log "Liệt kê danh sách SSL hiện có..."
    certbot certificates
}

# Function xóa SSL
delete_ssl() {
    echo
    echo -n "Nhập tên miền muốn xóa SSL (VD: example.com): "
    read -r domain
    
    log "Đang xóa SSL cho domain $domain..."
    certbot delete --cert-name "$domain"
    
    if [ $? -eq 0 ]; then
        log "Xóa SSL cho domain $domain thành công!"
        echo -e "${GREEN}SSL cho domain $domain đã được xóa thành công!${NC}"
    else
        log "Xóa SSL cho domain $domain thất bại!"
        echo -e "${RED}Xóa SSL thất bại. Vui lòng kiểm tra lại!${NC}"
    fi
}

# Main SSL script
while true; do
    show_ssl_menu
    read -r ssl_choice
    
    case $ssl_choice in
        1) install_ssl ;;
        2) renew_ssl ;;
        3) list_ssl ;;
        4) delete_ssl ;;
        0) break ;;
        *) echo -e "${RED}Lựa chọn không hợp lệ${NC}" ;;
    esac
    
    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
    clear
    echo -e "${GREEN}=== CÀI ĐẶT SSL (LET'S ENCRYPT) ===${NC}"
done

# Quay lại menu chính 