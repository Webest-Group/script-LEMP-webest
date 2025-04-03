#!/bin/bash

# Màu sắc cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Script này cần chạy với quyền root${NC}"
    exit 1
fi

echo -e "${GREEN}=== CÀI ĐẶT WEBEST VPS PANEL ===${NC}"
echo

# Các đường dẫn
INSTALL_DIR="/opt/webestvps"
CONFIG_DIR="/etc/webestvps"
LOG_DIR="/var/log/webestvps"
WEB_ROOT="/home/websites"

# Tạo các thư mục cần thiết
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR" "$WEB_ROOT"

# Sao chép các file script từ thư mục hiện tại
cp laravel_install.sh "$INSTALL_DIR/"
cp webestvps "$INSTALL_DIR/"
cp setup.sh "$INSTALL_DIR/"
cp -r modules "$INSTALL_DIR/"

# Phân quyền thực thi
chmod +x "$INSTALL_DIR/laravel_install.sh"
chmod +x "$INSTALL_DIR/webestvps"
chmod +x "$INSTALL_DIR/setup.sh"
chmod +x "$INSTALL_DIR/modules"/*.sh

# Tạo liên kết symbolic để sử dụng lệnh webestvps từ bất kỳ đâu
ln -sf "$INSTALL_DIR/webestvps" /usr/local/bin/webestvps

# Tạo file version
echo "1.0.0" > "$CONFIG_DIR/version"
touch "$CONFIG_DIR/installed"

# Tạo file version.txt trong repository
echo "1.0.0" > version.txt

echo -e "${GREEN}Cài đặt WebEST VPS Panel hoàn tất!${NC}"
echo -e "Bạn có thể sử dụng lệnh ${YELLOW}webestvps${NC} để mở panel quản lý."
echo 