#!/bin/bash

install_git() {
    log "Bắt đầu cài đặt Git..."
    
    apt install -y git
    
    # Cấu hình Git
    git config --system core.fileMode false
    git config --system core.autocrlf input
    git config --system core.ignorecase false
    
    log "Cài đặt Git hoàn tất"
    echo -e "${GREEN}Git đã được cài đặt và cấu hình thành công!${NC}"
}

install_dev_tools() {
    log "Bắt đầu cài đặt các công cụ phát triển..."
    
    # Cài đặt các công cụ cơ bản
    apt install -y vim nano wget curl zip unzip htop screen tmux
    
    # Cài đặt các công cụ phát triển
    apt install -y build-essential software-properties-common
    
    log "Cài đặt công cụ phát triển hoàn tất"
    echo -e "${GREEN}Các công cụ phát triển đã được cài đặt thành công!${NC}"
}

install_nodejs() {
    log "Bắt đầu cài đặt NodeJS..."
    
    # Thêm NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    
    # Cài đặt NodeJS và npm
    apt install -y nodejs
    
    # Cài đặt các package toàn cục
    npm install -g pm2 yarn
    
    log "Cài đặt NodeJS hoàn tất"
    echo -e "${GREEN}NodeJS đã được cài đặt thành công!${NC}"
}

install_mongodb() {
    log "Bắt đầu cài đặt MongoDB..."
    
    # Thêm MongoDB repository
    wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    
    # Cài đặt MongoDB
    apt update
    apt install -y mongodb-org
    
    # Khởi động MongoDB
    systemctl start mongod
    systemctl enable mongod
    
    log "Cài đặt MongoDB hoàn tất"
    echo -e "${GREEN}MongoDB đã được cài đặt thành công!${NC}"
}

# Hiển thị menu development tools
while true; do
    echo -e "${GREEN}=== Cài Đặt Công Cụ Phát Triển ===${NC}"
    echo "1) Cài đặt Git"
    echo "2) Cài đặt các công cụ phát triển cơ bản"
    echo "3) Cài đặt NodeJS"
    echo "4) Cài đặt MongoDB"
    echo "5) Cài đặt tất cả"
    echo "6) Quay lại menu chính"
    echo
    echo -n "Nhập lựa chọn của bạn [1-6]: "
    read -r dev_choice

    case $dev_choice in
        1)
            install_git
            ;;
        2)
            install_dev_tools
            ;;
        3)
            install_nodejs
            ;;
        4)
            install_mongodb
            ;;
        5)
            install_git
            install_dev_tools
            install_nodejs
            install_mongodb
            ;;
        6)
            break
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            ;;
    esac

    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
done 