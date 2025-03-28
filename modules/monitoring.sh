#!/bin/bash

install_monit() {
    log "Bắt đầu cài đặt Monit..."
    
    apt install -y monit
    
    # Cấu hình Monit
    cat > /etc/monit/conf.d/system <<EOF
# System checks
check system \$HOST
    if loadavg (1min) > 4 then alert
    if loadavg (5min) > 2 then alert
    if memory usage > 75% then alert
    if swap usage > 25% then alert
    if cpu usage (user) > 70% then alert
    if cpu usage (system) > 30% then alert

# Nginx check
check process nginx with pidfile /var/run/nginx.pid
    start program = "/etc/init.d/nginx start"
    stop program = "/etc/init.d/nginx stop"
    if failed host 127.0.0.1 port 80 protocol http then restart
    if cpu > 60% for 2 cycles then alert
    if cpu > 80% for 5 cycles then restart
    if totalmem > 1024.0 MB for 5 cycles then restart
    if children > 250 then restart
    if loadavg(5min) greater than 10 for 8 cycles then stop
    group www-data

# MariaDB check
check process mysql with pidfile /var/run/mysqld/mysqld.pid
    start program = "/etc/init.d/mysql start"
    stop program = "/etc/init.d/mysql stop"
    if failed host 127.0.0.1 port 3306 then restart
    if cpu > 60% for 2 cycles then alert
    if cpu > 80% for 5 cycles then restart
    if totalmem > 1024.0 MB for 5 cycles then restart
    group mysql

# PHP-FPM check
check process php8.1-fpm with pidfile /var/run/php/php8.1-fpm.pid
    start program = "/etc/init.d/php8.1-fpm start"
    stop program = "/etc/init.d/php8.1-fpm stop"
    if cpu > 60% for 2 cycles then alert
    if cpu > 80% for 5 cycles then restart
    if totalmem > 1024.0 MB for 5 cycles then restart
    group www-data
EOF
    
    # Cấu hình Monit web interface
    cat > /etc/monit/conf.d/web <<EOF
set httpd port 2812
    allow localhost
    allow admin:monit
EOF
    
    # Khởi động lại Monit
    systemctl restart monit
    systemctl enable monit
    
    log "Cài đặt Monit hoàn tất"
    echo -e "${GREEN}Monit đã được cài đặt và cấu hình thành công!${NC}"
}

install_netdata() {
    log "Bắt đầu cài đặt Netdata..."
    
    # Cài đặt dependencies
    apt install -y zlib1g-dev uuid-dev libuv1-dev liblz4-dev libjudy-dev libssl-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config curl python3
    
    # Tải và cài đặt Netdata
    bash <(curl -Ss https://my-netdata.io/kickstart.sh) --non-interactive
    
    # Cấu hình Netdata
    cat > /etc/netdata/netdata.conf <<EOF
[global]
    memory mode = ram
    history = 3600
    update every = 1
    
[web]
    web files owner = root
    web files group = root
    default port = 19999
EOF
    
    # Khởi động lại Netdata
    systemctl restart netdata
    systemctl enable netdata
    
    log "Cài đặt Netdata hoàn tất"
    echo -e "${GREEN}Netdata đã được cài đặt và cấu hình thành công!${NC}"
}

# Hiển thị menu cài đặt Monitoring
while true; do
    echo -e "${GREEN}=== Cài đặt Monitoring ===${NC}"
    echo "1) Cài đặt Monit"
    echo "2) Cài đặt Netdata"
    echo "3) Cài đặt tất cả"
    echo "4) Quay lại menu chính"
    echo
    echo -n "Nhập lựa chọn của bạn [1-4]: "
    read -r monitoring_choice

    case $monitoring_choice in
        1)
            install_monit
            ;;
        2)
            install_netdata
            ;;
        3)
            install_monit
            install_netdata
            ;;
        4)
            break
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ${NC}"
            ;;
    esac

    echo
    read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
done 