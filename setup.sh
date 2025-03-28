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

# Kiểm tra OS
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

# Tạo thư mục cài đặt
INSTALL_DIR="/tmp/server-setup"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit

# Tải các module từ GitHub
echo -e "${GREEN}Đang tải các module...${NC}"

# URL của repository (thay thế bằng URL thực tế của bạn)
REPO_URL="https://raw.githubusercontent.com/yourusername/server-setup/main"

# Tải các module
modules=(
    "install.sh"
    "modules/webserver.sh"
    "modules/php.sh"
    "modules/database.sh"
    "modules/ssl.sh"
    "modules/security.sh"
    "modules/monitoring.sh"
    "modules/optimization.sh"
    "modules/backup.sh"
    "modules/domain.sh"
    "modules/development.sh"
)

# Tạo thư mục modules
mkdir -p modules

# Tải từng module
for module in "${modules[@]}"; do
    echo "Đang tải $module..."
    curl -sSL "$REPO_URL/$module" -o "$module"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Lỗi khi tải $module${NC}"
        exit 1
    fi
done

# Cấp quyền thực thi cho các script
chmod +x install.sh
chmod +x modules/*.sh

# Chạy script cài đặt
./install.sh

# Dọn dẹp
cd /
rm -rf "$INSTALL_DIR"

echo -e "${GREEN}Cài đặt hoàn tất!${NC}" 