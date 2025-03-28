#!/bin/bash

install_ufw() {
    log "Bắt đầu cài đặt UFW..."
    
    apt install -y ufw
    
    # Cấu hình UFW
    ufw default deny incoming
    ufw default allow outgoing
    
    # Cho phép các port thông dụng
    ufw allow ssh
    ufw allow http
    ufw allow https
    
    # Bật UFW
    echo "y" | ufw enable
    
    log "Cài đặt UFW hoàn tất"
    echo -e "${GREEN}UFW đã được cài đặt và cấu hình thành công!${NC}"
}

install_fail2ban() {
    log "Bắt đầu cài đặt Fail2ban..."
    
    apt install -y fail2ban
    
    # Tạo cấu hình Fail2ban
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[php-url-fopen]
enabled = true
port = http,https
filter = php-url-fopen
logpath = /var/log/nginx/access.log
EOF
    
    # Khởi động lại Fail2ban
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    log "Cài đặt Fail2ban hoàn tất"
    echo -e "${GREEN}Fail2ban đã được cài đặt và cấu hình thành công!${NC}"
}

install_modsecurity() {
    log "Bắt đầu cài đặt ModSecurity..."
    
    # Cài đặt ModSecurity cho Nginx
    apt install -y nginx-plus-module-modsecurity libmodsecurity3
    
    # Tải OWASP ModSecurity Core Rule Set
    cd /tmp
    wget https://github.com/coreruleset/coreruleset/archive/v3.3.2.tar.gz
    tar xvf v3.3.2.tar.gz
    mv coreruleset-3.3.2 /usr/local/coreruleset
    cp /usr/local/coreruleset/crs-setup.conf.example /usr/local/coreruleset/crs-setup.conf
    
    # Cấu hình ModSecurity
    cat > /etc/nginx/modsec/main.conf <<EOF
Include /usr/local/coreruleset/crs-setup.conf
Include /usr/local/coreruleset/rules/*.conf
SecRuleEngine On
SecRequestBodyAccess On
SecRequestBodyLimit 13107200
SecRequestBodyNoFilesLimit 131072
SecRequestBodyInMemoryLimit 131072
SecRequestBodyLimitAction Reject
SecRule REQUEST_HEADERS:Content-Type "text/xml" \
     "id:'200000',phase:1,t:none,t:lowercase,pass,nolog,ctl:requestBodyProcessor=XML"
SecRule REQUEST_HEADERS:Content-Type "application/json" \
     "id:'200001',phase:1,t:none,t:lowercase,pass,nolog,ctl:requestBodyProcessor=JSON"
EOF
    
    # Khởi động lại Nginx
    systemctl restart nginx
    
    log "Cài đặt ModSecurity hoàn tất"
    echo -e "${GREEN}ModSecurity đã được cài đặt và cấu hình thành công!${NC}"
}

install_clamav() {
    log "Bắt đầu cài đặt ClamAV..."
    
    apt install -y clamav clamav-daemon
    
    # Cập nhật virus database
    systemctl stop clamav-freshclam
    freshclam
    systemctl start clamav-freshclam
    systemctl enable clamav-freshclam
    
    # Tạo script quét virus tự động
    cat > /usr/local/bin/scan-system <<EOF
#!/bin/bash
DATE=\$(date +%Y-%m-%d)
clamscan -r / --exclude-dir=/sys --exclude-dir=/proc --exclude-dir=/dev --log=/var/log/clamav/scan-\$DATE.log
EOF
    
    chmod +x /usr/local/bin/scan-system
    
    # Tạo cronjob quét hàng ngày
    echo "0 2 * * * /usr/local/bin/scan-system" | crontab -
    
    log "Cài đặt ClamAV hoàn tất"
    echo -e "${GREEN}ClamAV đã được cài đặt và cấu hình thành công!${NC}"
}

# Hiển thị menu cài đặt Security
while true; do
    echo -e "${GREEN}=== Cài đặt Bảo Mật ===${NC}"
    echo "1) Cài đặt UFW Firewall"
    echo "2) Cài đặt Fail2ban"
    echo "3) Cài đặt ModSecurity"
    echo "4) Cài đặt ClamAV Antivirus"
    echo "5) Cài đặt tất cả"
    echo "6) Quay lại menu chính"
    echo
    echo -n "Nhập lựa chọn của bạn [1-6]: "
    read -r security_choice

    case $security_choice in
        1)
            install_ufw
            ;;
        2)
            install_fail2ban
            ;;
        3)
            install_modsecurity
            ;;
        4)
            install_clamav
            ;;
        5)
            install_ufw
            install_fail2ban
            install_modsecurity
            install_clamav
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