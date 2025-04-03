#!/bin/bash

# Hàm ghi log
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Hàm kiểm tra lỗi
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Lỗi: $1${NC}"
        exit 1
    fi
}

# Hàm sửa lỗi apt
fix_apt() {
    log "Đang sửa lỗi apt..."
    apt-get clean
    apt-get update
    apt-get install -f -y
    dpkg --configure -a
} 