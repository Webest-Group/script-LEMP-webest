#!/bin/bash

# Hàm kiểm tra và cập nhật script
check_and_update() {
    echo -e "${YELLOW}Đang kiểm tra và cập nhật script...${NC}"
    
    # Tạo thư mục tạm
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    # Clone repository mới
    git clone https://github.com/Webest-Group/script-LEMP-webest.git .
    
    # Kiểm tra version mới
    NEW_VERSION=$(cat install.sh | grep "VERSION=" | cut -d'"' -f2)
    CURRENT_VERSION=$(cat /usr/local/bin/webestvps | grep "VERSION=" | cut -d'"' -f2)
    
    echo -e "${YELLOW}Phiên bản hiện tại: $CURRENT_VERSION${NC}"
    echo -e "${YELLOW}Phiên bản mới: $NEW_VERSION${NC}"
    
    # Xóa file cũ
    echo -e "${YELLOW}Đang xóa file cũ...${NC}"
    rm -rf /usr/local/bin/webestvps
    rm -rf /usr/local/bin/configs/
    
    # Sao chép file mới
    echo -e "${YELLOW}Đang sao chép file mới...${NC}"
    cp install.sh /usr/local/bin/webestvps
    cp -r configs/* /usr/local/bin/configs/
    
    # Cấp quyền thực thi
    echo -e "${YELLOW}Đang cấp quyền thực thi...${NC}"
    chmod +x /usr/local/bin/webestvps
    chmod +x /usr/local/bin/configs/*.sh
    
    # Cập nhật file install.sh gốc
    if [ -f "/root/install.sh" ]; then
        cp install.sh /root/install.sh
        chmod +x /root/install.sh
        echo -e "${GREEN}Đã cập nhật file install.sh gốc${NC}"
    fi
    
    # Xóa thư mục tạm
    rm -rf "$TMP_DIR"
    
    echo -e "${GREEN}Đã cập nhật script thành công!${NC}"
    echo -e "${YELLOW}Vui lòng khởi động lại panel để áp dụng thay đổi${NC}"
    
    # Khởi động lại script
    exec /usr/local/bin/webestvps
}

# Gọi hàm kiểm tra và cập nhật
check_and_update 