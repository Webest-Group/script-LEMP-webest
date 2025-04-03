#!/bin/bash

# --- Phần Khai báo và Cấu hình ---
# Màu sắc cho terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Kiểm tra quyền root ngay từ đầu
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Script này cần chạy với quyền root (sudo).${NC}"
    exit 1
fi

# Các đường dẫn
INSTALL_DIR="/opt/webestvps"
CONFIG_DIR="/etc/webestvps"
LOG_DIR="/var/log/webestvps"
WEB_ROOT="/home/websites"
PANEL_VERSION="1.0.1" # Cập nhật phiên bản

# Phân biệt chế độ chạy: true khi cài đặt, false khi chạy menu
# Mặc định là cài đặt, trừ khi có tham số 'menu'
if [[ "$1" == "menu" ]]; then
    INSTALL_MODE=false
else
    INSTALL_MODE=true
fi

# Tạo thư mục log cơ bản ngay từ đầu cho hàm log hoạt động
mkdir -p "$LOG_DIR"

# --- Tất cả Định nghĩa Hàm ---

# Function ghi log cài đặt (install.log)
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/install.log"
}

# Function ghi log cho panel (webestvps.log) - Dùng trong script panel được tạo ra
panel_log() {
    mkdir -p "$LOG_DIR"
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/webestvps.log"
}

# Function kiểm tra lỗi chung
# $1: Mã lỗi $?
# $2: Thông điệp lỗi
# $3: (optional) Tên hàm log để sử dụng (log hoặc panel_log)
# Trả về 0 nếu OK, 1 nếu có lỗi. Sẽ exit nếu INSTALL_MODE=true và có lỗi.
_check_error_internal() {
    local exit_code=$1
    local message=$2
    local log_func=${3:-log} # Mặc định dùng log cài đặt

    if [ "$exit_code" -ne 0 ]; then
        "$log_func" "${RED}Lỗi: $message (Exit Code: $exit_code)${NC}"
        # Hiển thị lỗi ra màn hình nếu là panel log
        if [[ "$log_func" == "panel_log" ]]; then
            echo -e "${RED}Lỗi: $message${NC}"
        fi

        if [ "$INSTALL_MODE" = true ]; then
            echo -e "${RED}Lỗi nghiêm trọng trong quá trình cài đặt. Dừng lại.${NC}"
            echo -e "${RED}Xem chi tiết: $LOG_DIR/install.log${NC}"
            exit 1 # Thoát script cài đặt nếu có lỗi nghiêm trọng
        else
            return 1 # Chỉ trả về mã lỗi nếu đang chạy panel menu
        fi
    fi
    return 0 # Không có lỗi
}

# Wrapper cho check_error trong script cài đặt chính
check_install_error() {
    _check_error_internal $? "$1" "log"
}

# Wrapper cho check_error trong script panel được tạo ra
# $? phải được truyền ngay lập tức
check_panel_error() {
    local last_exit_code=$?
    _check_error_internal "$last_exit_code" "$1" "panel_log"
    return $last_exit_code # Trả về mã lỗi gốc để hàm gọi có thể xử lý tiếp
}


# Function sửa lỗi apt
fix_apt() {
    log "Đang sửa lỗi apt..."
    # Xóa các file lock
    rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock*
    # Cấu hình dpkg
    dpkg --configure -a
    apt update
    check_install_error "Không thể chạy apt update sau khi sửa lock" || return 1
    apt --fix-broken install -y
    check_install_error "Không thể chạy apt --fix-broken install" || return 1
    apt upgrade -y
    check_install_error "Không thể chạy apt upgrade" || return 1
    apt install -y ubuntu-advantage-tools python3-software-properties
    check_install_error "Không thể cài đặt lại gói cần thiết sau khi sửa apt" || return 1
    log "${GREEN}Đã sửa lỗi apt thành công${NC}"
    return 0
}

# Function sửa lỗi repository
fix_repository() {
    log "Đang sửa lỗi repository..."
    # Backup sources.list
    cp /etc/apt/sources.list /etc/apt/sources.list.backup.$$ # Thêm PID để tránh ghi đè nếu chạy nhiều lần
    check_install_error "Không thể backup sources.list" || return 1
    # Tạo sources.list mới
    cat > /etc/apt/sources.list << EOF
deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
EOF
    check_install_error "Không thể ghi đè sources.list" || return 1
    apt update
    check_install_error "Không thể chạy apt update sau khi sửa repository" || return 1
    log "${GREEN}Đã sửa lỗi repository thành công${NC}"
    return 0
}

# Function sửa lỗi network
fix_network() {
    log "Đang sửa lỗi network..."
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log "${YELLOW}Không có kết nối internet. Đang thử khởi động lại network...${NC}"
        if systemctl is-active --quiet networking &> /dev/null; then systemctl restart networking; fi
        if systemctl is-active --quiet systemd-networkd &> /dev/null; then systemctl restart systemd-networkd; fi
        sleep 5
        if ! ping -c 1 8.8.8.8 &> /dev/null; then
            log "${YELLOW}Vẫn không có kết nối internet. Thử cấu hình DNS...${NC}"
        fi
    fi
    # Cấu hình DNS
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf # Thêm Cloudflare DNS
    check_install_error "Không thể ghi file /etc/resolv.conf" || return 1
    log "${GREEN}Đã kiểm tra/sửa lỗi network thành công${NC}"
    return 0
}

# Function kiểm tra gói đã cài đặt
is_package_installed() {
    dpkg -l | grep -q "^ii  $1 "
}

# Function kiểm tra service đang chạy
is_service_active() {
    systemctl is-active --quiet "$1"
}

# Function kiểm tra service đã enable
is_service_enabled() {
    systemctl is-enabled --quiet "$1"
}

# Function cài đặt các gói cần thiết
install_dependencies() {
    log "===== Bắt đầu Cài đặt Dependencies ====="
    apt update || log "${YELLOW}apt update có lỗi nhẹ, tiếp tục...${NC}"

    local base_pkgs=(git curl wget unzip software-properties-common apt-transport-https ca-certificates gnupg)
    local lemp_pkgs=(nginx php8.1-fpm php8.1-cli php8.1-common php8.1-mysql php8.1-zip php8.1-gd php8.1-mbstring php8.1-curl php8.1-xml php8.1-bcmath php8.1-intl mariadb-server redis-server)
    local other_pkgs=(nodejs composer certbot python3-certbot-nginx supervisor) # Composer, Nodejs sẽ cài riêng

    local all_pkgs=("${base_pkgs[@]}" "${lemp_pkgs[@]}" supervisor certbot python3-certbot-nginx) # Nodejs, Composer xử lý riêng
    local pkgs_to_install=()

    log "Kiểm tra các gói cần thiết..."
    for pkg in "${all_pkgs[@]}"; do
        if ! is_package_installed "$pkg"; then
            pkgs_to_install+=("$pkg")
        fi
    done

    if [ ${#pkgs_to_install[@]} -gt 0 ]; then
        log "Các gói cần cài đặt/cập nhật: ${pkgs_to_install[*]}"
        # Thêm PPA PHP trước khi cài
        if ! apt-cache policy | grep -q "ondrej/php"; then
            log "Thêm repository PPA:ondrej/php..."
            add-apt-repository -y ppa:ondrej/php
            check_install_error "Không thể thêm repository PPA:ondrej/php" || return 1
            apt update
            check_install_error "apt update sau khi thêm PPA thất bại" || return 1
        fi
        DEBIAN_FRONTEND=noninteractive apt install -y "${pkgs_to_install[@]}"
        check_install_error "Không thể cài đặt các gói: ${pkgs_to_install[*]}" || return 1
        log "${GREEN}Đã cài đặt các gói cơ bản thành công.${NC}"
    else
        log "${GREEN}Tất cả các gói cơ bản đã được cài đặt.${NC}"
    fi

    # Cài đặt/Kiểm tra Composer
    if ! command -v composer &> /dev/null; then
        log "${YELLOW}Đang cài đặt Composer...${NC}"
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
        check_install_error "Không thể cài đặt Composer" || return 1
        log "${GREEN}Composer đã được cài đặt.${NC}"
    else
        log "${GREEN}Composer ($(composer --version)) đã được cài đặt.${NC}"
    fi

    # Cài đặt/Kiểm tra Node.js 18.x và npm
    NODE_VERSION_REQUIRED="18."
    if ! command -v node &> /dev/null || ! [[ "$(node -v 2>/dev/null)" == v${NODE_VERSION_REQUIRED}* ]]; then
        log "${YELLOW}Đang cài đặt/cập nhật Node.js v${NODE_VERSION_REQUIRED}x...${NC}"
        # Gỡ cài đặt nodejs cũ nếu cần
        if command -v node &> /dev/null && ! [[ "$(node -v)" == v${NODE_VERSION_REQUIRED}* ]]; then
             log "Gỡ bỏ phiên bản Node.js hiện tại ($(node -v))..."
             apt remove -y nodejs npm &> /dev/null
             apt autoremove -y &> /dev/null
        fi
        # Cài đặt từ NodeSource
        curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION_REQUIRED}x | bash -
        check_install_error "Không thể chạy script setup NodeSource" || return 1
        apt install -y nodejs
        check_install_error "Không thể cài đặt nodejs" || return 1
        log "${GREEN}Đã cài đặt Node.js ($(node -v)) và npm ($(npm -v)) thành công.${NC}"
    else
        log "${GREEN}Node.js ($(node -v)) và npm ($(npm -v)) đã được cài đặt.${NC}"
    fi

    # Kích hoạt và Khởi động các service cốt lõi
    log "Kích hoạt và khởi động các service cốt lõi..."
    local core_services=(nginx php8.1-fpm mariadb redis-server supervisor)
    for service in "${core_services[@]}"; do
        if ! is_service_enabled "$service"; then systemctl enable "$service"; fi
        if ! is_service_active "$service"; then systemctl start "$service"; fi
        # Kiểm tra lại sau khi start
        sleep 1 # Chờ service khởi động
        if ! is_service_active "$service"; then
             log "${RED}Service $service không thể khởi động!${NC}"
             # Có thể thêm lệnh xem status ở đây để debug
             # systemctl status "$service" --no-pager
             # return 1 # Quyết định có nên dừng cài đặt hay không
             log "${YELLOW}Cảnh báo: Service $service không khởi động được, tiếp tục cài đặt...${NC}"
        fi
    done

    log "${GREEN}===== Hoàn tất Cài đặt Dependencies ====="
    return 0
}


# Function tạo file webestvps (script chính của panel)
create_webestvps_script() {
    log "===== Bắt đầu Tạo Script Panel ====="
    log "Đang tạo file panel /opt/webestvps/webestvps..."

    mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR" "$WEB_ROOT"
    check_install_error "Không thể tạo các thư mục cơ bản" || return 1

    # Ghi nội dung script panel vào file
    cat > "$INSTALL_DIR/webestvps" << 'EOF_PANEL_SCRIPT'
#!/bin/bash
# =============================================
#        WEBEST VPS PANEL - Main Script
# =============================================
# Version: 1.0.1

# --- Khai báo ---
# Màu sắc
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
# Đường dẫn
INSTALL_DIR="/opt/webestvps"; CONFIG_DIR="/etc/webestvps"; LOG_DIR="/var/log/webestvps"; WEB_ROOT="/home/websites"
PANEL_LOG_FILE="$LOG_DIR/webestvps.log"

# --- Các Hàm Tiện Ích ---
# Ghi log panel
panel_log() { mkdir -p "$LOG_DIR"; echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$PANEL_LOG_FILE"; }
# Kiểm tra lỗi panel
check_panel_error() {
    local exit_code=$?; local message=$1
    if [ "$exit_code" -ne 0 ]; then
        panel_log "${RED}Lỗi: $message (Exit Code: $exit_code)${NC}"
        echo -e "${RED}Lỗi: $message${NC}"; return 1
    fi; return 0
}
# Hàm chờ người dùng nhấn phím
press_any_key() { echo; read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."; }
# Hàm kiểm tra root
check_root() { if [[ $EUID -ne 0 ]]; then echo -e "${RED}Lệnh này cần quyền root (sudo).${NC}"; exit 1; fi; }
# Hàm thực thi lệnh mysql
run_mysql_command() {
    local command=$1; local success_msg=$2; local failure_msg=$3
    output=$(mysql -u root -e "$command" 2>&1); local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        panel_log "${RED}Lỗi MariaDB: $failure_msg. Output: $output${NC}"
        echo -e "${RED}Lỗi: $failure_msg.${NC}"; echo "Chi tiết: $output"; return 1
    else
        panel_log "$success_msg"; echo -e "${GREEN}$success_msg${NC}"
        if [[ -n "$output" && ! "$output" =~ ^(Query OK|Database changed|User created|Privileges flushed|Rows matched|Changed) ]]; then echo "$output"; fi
        return 0
    fi
}
# Hàm cài đặt SSL cho domain
install_ssl_for_domain() {
    local domain_to_ssl=$1; check_root
    panel_log "Bắt đầu cài đặt SSL cho $domain_to_ssl"; echo "Đang cài đặt SSL cho $domain_to_ssl..."
    if ! command -v certbot &> /dev/null; then echo -e "${RED}Lệnh certbot không tồn tại.${NC}"; return 1; fi
    certbot --nginx -d "$domain_to_ssl" -d "www.$domain_to_ssl" --non-interactive --agree-tos --email "admin@$domain_to_ssl" --redirect --hsts --uir
    if check_panel_error "Không thể cài đặt SSL cho domain $domain_to_ssl"; then echo -e "${RED}Cài đặt SSL thất bại.${NC}"; return 1; fi
    echo -e "${GREEN}Đã cài đặt/gia hạn SSL cho $domain_to_ssl thành công.${NC}"; panel_log "Cài đặt SSL cho $domain_to_ssl thành công."
    nginx -t && systemctl reload nginx; return 0
}

# --- Các Hàm Quản Lý Chính ---

# Quản lý Domain
manage_domain() {
    check_root
    while true; do
        clear; echo -e "${GREEN}=== QUẢN LÝ DOMAIN ===${NC}"
        echo "1) Thêm domain"; echo "2) Xóa domain"; echo "3) Liệt kê domain"; echo "0) Quay lại"
        echo -n "Lựa chọn [0-3]: "; read -r choice
        case $choice in
            1) # Thêm domain
                echo -n "Tên domain (vd: example.com): "; read -r domain
                if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then echo "${RED}Tên domain không hợp lệ.${NC}"; sleep 2; continue; fi
                default_web_path=$(echo "$domain" | tr '.' '_'); echo -n "Đường dẫn thư mục web (vd: $default_web_path) [$default_web_path]: "; read -r web_path; web_path=${web_path:-$default_web_path}
                target_web_dir="$WEB_ROOT/$web_path"
                nginx_conf="/etc/nginx/sites-available/$domain"
                nginx_link="/etc/nginx/sites-enabled/$domain"

                if [ -f "$nginx_conf" ]; then echo -n "${YELLOW}Cấu hình $nginx_conf đã tồn tại. Ghi đè? (y/n): ${NC}"; read -r ovr; if [[ "$ovr" != "y" ]]; then continue; fi; fi
                panel_log "Thêm domain: $domain, path: $target_web_dir"
                mkdir -p "$target_web_dir"; check_panel_error "Tạo thư mục $target_web_dir thất bại" || continue
                chown -R www-data:www-data "$target_web_dir"; check_panel_error "Phân quyền $target_web_dir thất bại" || continue
                if [ ! -f "$target_web_dir/index.html" ]; then echo "<h1>Welcome to $domain</h1>" > "$target_web_dir/index.html"; chown www-data:www-data "$target_web_dir/index.html"; fi

                cat > "$nginx_conf" << EOF_NGINX_CONF
server { listen 80; listen [::]:80; server_name $domain www.$domain; root $target_web_dir; index index.html index.php; location / { try_files \$uri \$uri/ /index.php?\$query_string; } location = /favicon.ico { access_log off; log_not_found off; } location = /robots.txt { access_log off; log_not_found off; } error_page 404 /index.php; location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/var/run/php/php8.1-fpm.sock; fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name; include fastcgi_params; } location ~ /\.(?!well-known).* { deny all; } access_log /var/log/nginx/${domain}_access.log; error_log /var/log/nginx/${domain}_error.log; }
EOF_NGINX_CONF
                check_panel_error "Tạo cấu hình Nginx $nginx_conf thất bại" || continue
                ln -sf "$nginx_conf" "$nginx_link"; check_panel_error "Tạo symlink Nginx thất bại" || continue
                nginx -t; if check_panel_error "Cấu hình Nginx có lỗi"; then systemctl reload nginx; if check_panel_error "Reload Nginx thất bại"; then rm -f "$nginx_link"; echo "${RED}Thêm domain thất bại.${NC}"; else echo "${GREEN}Thêm domain $domain thành công.${NC}"; panel_log "Thêm domain $domain thành công."; echo -n "Cài SSL? (y/n): "; read -r sslnow; if [[ "$sslnow" == "y" ]]; then install_ssl_for_domain "$domain"; fi; fi; else rm -f "$nginx_link"; fi ;;
            2) # Xóa domain
                echo -n "Tên domain cần xóa: "; read -r domain; if [[ -z "$domain" ]]; then continue; fi
                echo -n "${YELLOW}Xóa cấu hình Nginx và SSL (nếu có) cho '$domain'? (Thư mục web không bị xóa) (y/n): ${NC}"; read -r conf; if [[ "$conf" != "y" ]]; then continue; fi
                panel_log "Xóa domain: $domain"
                nginx_conf="/etc/nginx/sites-available/$domain"; nginx_link="/etc/nginx/sites-enabled/$domain"
                rm -f "$nginx_link"; rm -f "$nginx_conf"
                echo -n "Thử xóa SSL? (y/n): "; read -r sslrem; if [[ "$sslrem" == "y" ]]; then if command -v certbot &>/dev/null; then certbot delete --cert-name "$domain" --non-interactive; fi; fi
                nginx -t; if check_panel_error "Lỗi Nginx sau khi xóa"; then : ; else systemctl reload nginx; echo "${GREEN}Đã xóa cấu hình domain $domain.${NC}"; panel_log "Xóa domain $domain thành công."; fi ;;
            3) # Liệt kê domain
                echo "${GREEN}Enabled:${NC}"; ls -l /etc/nginx/sites-enabled/ | grep -v default | awk '{print $9}'; ;;
            0) return ;; *) echo "${RED}Lựa chọn không hợp lệ.${NC}"; sleep 1 ;;
        esac; press_any_key
    done
}

# Quản lý SSL
manage_ssl() {
    check_root
    while true; do
        clear; echo -e "${GREEN}=== QUẢN LÝ SSL (Let's Encrypt) ===${NC}"
        echo "1) Cài đặt/Làm mới SSL"; echo "2) Gia hạn tất cả (Dry Run)"; echo "3) Gia hạn tất cả (Thực tế)"; echo "4) Liệt kê chứng chỉ"; echo "5) Xóa chứng chỉ"; echo "0) Quay lại"
        echo -n "Lựa chọn [0-5]: "; read -r choice
        case $choice in
            1) echo -n "Tên domain: "; read -r domain; if [[ -z "$domain" ]]; then continue; fi; install_ssl_for_domain "$domain"; ;;
            2) panel_log "SSL Renew Dry Run"; certbot renew --dry-run; check_panel_error "Lỗi Dry Run"; ;;
            3) panel_log "SSL Renew"; certbot renew; check_panel_error "Lỗi Renew SSL"; nginx -t && systemctl reload nginx; ;;
            4) panel_log "List SSL Certs"; certbot certificates; ;;
            5) echo -n "Tên domain của cert cần xóa: "; read -r domain; if [[ -z "$domain" ]]; then continue; fi; echo -n "${YELLOW}Xóa cert '$domain'? (y/n): ${NC}"; read -r conf; if [[ "$conf" != "y" ]]; then continue; fi; panel_log "Delete SSL Cert: $domain"; certbot delete --cert-name "$domain" --non-interactive; check_panel_error "Lỗi xóa SSL Cert"; nginx -t && systemctl reload nginx; ;;
            0) return ;; *) echo "${RED}Lựa chọn không hợp lệ.${NC}"; sleep 1 ;;
        esac; press_any_key
    done
}

# Quản lý Database
manage_database() {
    check_root
    while true; do
        clear; echo -e "${GREEN}=== QUẢN LÝ DATABASE (MariaDB) ===${NC}"
        echo "1) Tạo DB"; echo "2) Xóa DB"; echo "3) Liệt kê DB"; echo "4) Tạo User"; echo "5) Xóa User"; echo "6) Liệt kê User"; echo "7) Gán quyền User->DB"; echo "0) Quay lại"
        echo -n "Lựa chọn [0-7]: "; read -r choice
        case $choice in
            1) echo -n "Tên DB mới: "; read -r dbname; if [[ -z "$dbname" ]]; then continue; fi; run_mysql_command "CREATE DATABASE IF NOT EXISTS \`$dbname\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" "Tạo DB '$dbname' OK." "Lỗi tạo DB '$dbname'"; ;;
            2) echo -n "Tên DB cần xóa: "; read -r dbname; if [[ "$dbname" =~ ^(mysql|information_schema|performance_schema|sys)$ || -z "$dbname" ]]; then echo "${RED}Không hợp lệ/hệ thống.${NC}"; sleep 2; continue; fi; echo -n "${YELLOW}Xóa DB '$dbname'? (y/n): ${NC}"; read -r conf; if [[ "$conf" != "y" ]]; then continue; fi; run_mysql_command "DROP DATABASE IF EXISTS \`$dbname\`;" "Xóa DB '$dbname' OK." "Lỗi xóa DB '$dbname'"; ;;
            3) echo "${GREEN}Danh sách DB:${NC}"; run_mysql_command "SHOW DATABASES;" "Liệt kê DB OK." "Lỗi liệt kê DB"; ;;
            4) echo -n "Tên user mới: "; read -r username; if [[ -z "$username" ]]; then continue; fi; password=$(openssl rand -base64 12); echo -n "Mật khẩu [$password]: "; read -r input_pass; password=${input_pass:-$password}; run_mysql_command "CREATE USER IF NOT EXISTS '$username'@'localhost' IDENTIFIED BY '$password';" "Tạo user '$username'@'localhost' OK. Pass: $password" "Lỗi tạo user '$username'"; ;;
            5) echo -n "Tên user cần xóa: "; read -r username; if [[ "$username" =~ ^(root|mysql.*|mariadb\.sys)$ || -z "$username" ]]; then echo "${RED}Không hợp lệ/hệ thống.${NC}"; sleep 2; continue; fi; echo -n "${YELLOW}Xóa user '$username'@'localhost'? (y/n): ${NC}"; read -r conf; if [[ "$conf" != "y" ]]; then continue; fi; run_mysql_command "DROP USER IF EXISTS '$username'@'localhost';" "Xóa user '$username' OK." "Lỗi xóa user '$username'" && run_mysql_command "FLUSH PRIVILEGES;" "Flush OK." "Lỗi Flush"; ;;
            6) echo "${GREEN}Danh sách User:${NC}"; run_mysql_command "SELECT User, Host FROM mysql.user;" "Liệt kê User OK." "Lỗi liệt kê User"; ;;
            7) echo -n "Tên user: "; read -r username; if [[ -z "$username" ]]; then continue; fi; echo -n "Tên DB: "; read -r dbname; if [[ -z "$dbname" ]]; then continue; fi; run_mysql_command "GRANT ALL PRIVILEGES ON \`$dbname\`.* TO '$username'@'localhost';" "Gán quyền $username -> $dbname OK." "Lỗi gán quyền" && run_mysql_command "FLUSH PRIVILEGES;" "Flush OK." "Lỗi Flush"; ;;
            0) return ;; *) echo "${RED}Lựa chọn không hợp lệ.${NC}"; sleep 1 ;;
        esac; press_any_key
    done
}

# Quản lý Backup
manage_backup() {
    check_root; BACKUP_DIR="$INSTALL_DIR/backups"; mkdir -p "$BACKUP_DIR"
    while true; do
        clear; echo -e "${GREEN}=== QUẢN LÝ BACKUP ($BACKUP_DIR) ===${NC}"
        echo "1) Backup Website"; echo "2) Backup Database"; echo "3) Backup All Websites"; echo "4) Backup All Databases"
        echo "5) Restore Website"; echo "6) Restore Database"; echo "7) Liệt kê Backups"; echo "8) Xóa Backup"; echo "0) Quay lại"
        echo -n "Lựa chọn [0-8]: "; read -r choice
        case $choice in
            1) # Backup web
                echo -n "Domain (để đặt tên file): "; read -r domain; if [[ -z "$domain" ]]; then continue; fi; web_dir=$(echo "$domain" | tr '.' '_'); default_path="$WEB_ROOT/$web_dir"; echo -n "Đường dẫn thư mục web [$default_path]: "; read -r wp; wp=${wp:-$default_path}; if [ ! -d "$wp" ]; then echo "${RED}Thư mục '$wp' không tồn tại.${NC}"; sleep 2; continue; fi; fname="${domain}_web_$(date +%Y%m%d_%H%M%S).tar.gz"; target="$BACKUP_DIR/$fname"; panel_log "Backup web $domain -> $fname"; tar -czf "$target" -C "$(dirname "$wp")" "$(basename "$wp")"; if check_panel_error "Backup web $domain thất bại"; then rm -f "$target"; else echo "${GREEN}Backup web $domain -> $fname OK.${NC}"; fi ;;
            2) # Backup DB
                echo -n "Tên DB: "; read -r dbname; if [[ "$dbname" =~ ^(information_schema|performance_schema|sys)$ || -z "$dbname" ]]; then echo "${RED}Không hợp lệ/hệ thống.${NC}"; sleep 2; continue; fi; fname="${dbname}_db_$(date +%Y%m%d_%H%M%S).sql.gz"; target="$BACKUP_DIR/$fname"; panel_log "Backup DB $dbname -> $fname"; if ! mysql -u root -e "USE \`$dbname\`;" &>/dev/null; then echo "${RED}DB '$dbname' không tồn tại.${NC}"; sleep 2; continue; fi; mysqldump -u root --databases "$dbname" | gzip > "$target"; if [ "${PIPESTATUS[0]}" -ne 0 ] || [ "${PIPESTATUS[1]}" -ne 0 ]; then panel_log "${RED}Lỗi backup DB $dbname.${NC}"; echo "${RED}Backup DB $dbname thất bại.${NC}"; rm -f "$target"; else echo "${GREEN}Backup DB $dbname -> $fname OK.${NC}"; fi ;;
            3) # Backup all web
                fname="all_websites_$(date +%Y%m%d_%H%M%S).tar.gz"; target="$BACKUP_DIR/$fname"; panel_log "Backup all web -> $fname"; tar -czf "$target" -C "$(dirname "$WEB_ROOT")" "$(basename "$WEB_ROOT")"; if check_panel_error "Backup all web thất bại"; then rm -f "$target"; else echo "${GREEN}Backup all web -> $fname OK.${NC}"; fi ;;
            4) # Backup all DB
                fname="all_databases_$(date +%Y%m%d_%H%M%S).sql.gz"; target="$BACKUP_DIR/$fname"; panel_log "Backup all DB -> $fname"; dbs=$(mysql -u root -e "SHOW DATABASES;" | grep -Ev "^(Database|information_schema|performance_schema|sys)$"); if [ -z "$dbs" ]; then echo "${YELLOW}Không có DB người dùng nào.${NC}"; sleep 2; continue; fi; mysqldump -u root --databases $dbs | gzip > "$target"; if [ "${PIPESTATUS[0]}" -ne 0 ] || [ "${PIPESTATUS[1]}" -ne 0 ]; then panel_log "${RED}Lỗi backup all DB.${NC}"; echo "${RED}Backup all DB thất bại.${NC}"; rm -f "$target"; else echo "${GREEN}Backup all DB -> $fname OK.${NC}"; fi ;;
            5) # Restore web
                ls -lh "$BACKUP_DIR" | grep '\.tar\.gz$'; echo -n "Tên file web backup (.tar.gz): "; read -r fname; if [[ -z "$fname" ]]; then continue; fi; src="$BACKUP_DIR/$fname"; if [ ! -f "$src" ]; then echo "${RED}File '$src' không tồn tại.${NC}"; sleep 2; continue; fi; echo -n "Đường dẫn gốc để restore vào (vd: $WEB_ROOT): "; read -r rpath; if [ ! -d "$rpath" ]; then mkdir -p "$rpath"; fi; echo -n "${YELLOW}Restore '$fname' vào '$rpath'? (Ghi đè file!) (y/n): ${NC}"; read -r conf; if [[ "$conf" != "y" ]]; then continue; fi; panel_log "Restore web $fname -> $rpath"; tar -xzf "$src" -C "$rpath"; if check_panel_error "Restore web thất bại"; then : ; else echo "${GREEN}Restore web $fname -> $rpath OK.${NC}"; echo "${YELLOW}Kiểm tra lại quyền!${NC}"; fi ;;
            6) # Restore DB
                ls -lh "$BACKUP_DIR" | grep '\.sql\(\.gz\)\?$' ; echo -n "Tên file DB backup (.sql/.sql.gz): "; read -r fname; if [[ -z "$fname" ]]; then continue; fi; src="$BACKUP_DIR/$fname"; if [ ! -f "$src" ]; then echo "${RED}File '$src' không tồn tại.${NC}"; sleep 2; continue; fi; guessed_db=$(echo "$fname" | sed -n 's/^\([^_]*\)_db_.*\.sql\(\.gz\)\?$/\1/p'); echo -n "Tên DB đích [$guessed_db]: "; read -r db_in; dbname=${db_in:-$guessed_db}; if [[ -z "$dbname" ]]; then continue; fi; if ! mysql -u root -e "USE \`$dbname\`;" &>/dev/null; then echo -n "${YELLOW}DB '$dbname' không tồn tại. Tạo mới? (y/n): ${NC}"; read -r conf; if [[ "$conf" != "y" ]]; then continue; fi; run_mysql_command "CREATE DATABASE IF NOT EXISTS \`$dbname\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" "" "" || continue; else echo -n "${YELLOW}Restore vào DB '$dbname' đã tồn tại? (Ghi đè!) (y/n): ${NC}"; read -r conf; if [[ "$conf" != "y" ]]; then continue; fi; fi; panel_log "Restore DB $fname -> $dbname"; echo "Restoring..."; if [[ "$src" == *.gz ]]; then gunzip < "$src" | mysql -u root "$dbname"; else mysql -u root "$dbname" < "$src"; fi; if [ "${PIPESTATUS[${#PIPESTATUS[@]}-1]}" -ne 0 ]; then panel_log "${RED}Lỗi restore DB $dbname.${NC}"; echo "${RED}Restore DB $dbname thất bại.${NC}"; else echo "${GREEN}Restore DB $dbname từ $fname OK.${NC}"; fi ;;
            7) echo "${GREEN}Files in $BACKUP_DIR:${NC}"; ls -lh "$BACKUP_DIR"; ;;
            8) ls -lh "$BACKUP_DIR"; echo -n "Tên file backup cần xóa: "; read -r fname; if [[ -z "$fname" ]]; then continue; fi; target="$BACKUP_DIR/$fname"; if [ ! -f "$target" ]; then echo "${RED}File '$target' không tồn tại.${NC}"; sleep 2; continue; fi; echo -n "${YELLOW}Xóa file '$fname'? (y/n): ${NC}"; read -r conf; if [[ "$conf" != "y" ]]; then continue; fi; rm -f "$target"; if check_panel_error "Xóa file thất bại"; then : ; else echo "${GREEN}Đã xóa $fname.${NC}"; panel_log "Deleted backup $target"; fi ;;
            0) return ;; *) echo "${RED}Lựa chọn không hợp lệ.${NC}"; sleep 1 ;;
        esac; press_any_key
    done
}

# Quản lý Service
manage_service() {
    check_root
    declare -A services=( ["nginx"]="Nginx" ["php8.1-fpm"]="PHP FPM" ["mariadb"]="MariaDB" ["redis-server"]="Redis" ["supervisor"]="Supervisor" ); local keys=("${!services[@]}")
    while true; do
        clear; echo -e "${GREEN}=== QUẢN LÝ SERVICE ===${NC}"; i=1; for k in "${keys[@]}"; do echo "$i) ${services[$k]}"; i=$((i+1)); done; echo "A) Tất cả"; echo "0) Quay lại"
        echo -n "Chọn service [1-$((${#keys[@]})), A, 0]: "; read -r choice
        local target_key=""
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#keys[@]}" ]; then target_key="${keys[$((choice-1))]}"; elif [[ "$choice" =~ ^[Aa]$ ]]; then target_key="all"; elif [[ "$choice" == "0" ]]; then return; else echo "${RED}Lựa chọn không hợp lệ.${NC}"; sleep 1; continue; fi

        local target_name=${services[$target_key]:-"Tất cả"}
        echo "Chọn hành động cho '$target_name': 1)Start 2)Stop 3)Restart 4)Reload 5)Status 6)Enable 7)Disable 0)Back"; echo -n "Hành động [0-7]: "; read -r action_choice
        local action=""
        case $action_choice in 1) action="start";; 2) action="stop";; 3) action="restart";; 4) action="reload";; 5) action="status";; 6) action="enable";; 7) action="disable";; 0) continue;; *) echo "${RED}Invalid action.${NC}"; sleep 1; continue;; esac

        perform() { local act=$1; local key=$2; local nm=${services[$key]}; panel_log "$act $key"; if [[ "$act" == "reload" && ! "$key" =~ ^(nginx|php8.1-fpm|supervisor)$ ]]; then echo "${YELLOW}Reload không áp dụng cho $nm.${NC}"; return 1; fi; echo "Đang $act $nm..."; systemctl "$act" "$key"; if [[ "$act" != "status" ]]; then check_panel_error "$act $nm thất bại" || return 1; fi; }

        if [[ "$target_key" == "all" ]]; then for k in "${keys[@]}"; do perform "$action" "$k"; done; else perform "$action" "$target_key"; fi
        press_any_key
    done
}

# Cài đặt Laravel
install_laravel() {
    check_root
    clear; echo -e "${GREEN}=== CÀI ĐẶT LARAVEL ===${NC}"
    echo -n "Tên project (vd: my_app): "; read -r pname; if [[ -z "$pname" ]]; then return; fi
    default_wp="$pname"; echo -n "Thư mục web root (trong $WEB_ROOT) [$default_wp]: "; read -r wp_in; wp=${wp_in:-$default_wp}; target_dir="$WEB_ROOT/$wp"
    if [ -d "$target_dir" ] && [ "$(ls -A $target_dir)" ]; then echo "${RED}Thư mục '$target_dir' đã tồn tại và không trống.${NC}"; sleep 3; return; fi
    default_dom="${pname}.local"; echo -n "Domain cho project này [$default_dom]: "; read -r dom_in; domain=${dom_in:-$default_dom}; if [[ -z "$domain" ]]; then return; fi
    echo -n "${YELLOW}Cài Laravel vào $target_dir, cấu hình domain $domain? (y/n): ${NC}"; read -r conf; if [[ "$conf" != "y" ]]; then return; fi

    panel_log "Cài Laravel $pname -> $target_dir, domain $domain"
    mkdir -p "$target_dir"; check_panel_error "Tạo thư mục $target_dir thất bại" || return
    echo "Đang chạy composer create-project..."; cd "$target_dir" && composer create-project --prefer-dist laravel/laravel .; if check_panel_error "Composer create-project thất bại"; then cd ..; rm -rf "$target_dir"; return; fi
    echo "Đang phân quyền..."; chown -R www-data:www-data "$target_dir"; chmod -R 775 "$target_dir/storage" "$target_dir/bootstrap/cache"; check_panel_error "Phân quyền Laravel thất bại" || return

    laravel_public="$target_dir/public"; nginx_conf="/etc/nginx/sites-available/$domain"; nginx_link="/etc/nginx/sites-enabled/$domain"
    panel_log "Tạo Nginx config cho Laravel: $domain"
    cat > "$nginx_conf" << EOF_NGINX_LARAVEL
server { listen 80; listen [::]:80; server_name $domain www.$domain; root $laravel_public; add_header X-Frame-Options "SAMEORIGIN"; add_header X-XSS-Protection "1; mode=block"; add_header X-Content-Type-Options "nosniff"; index index.php index.html; charset utf-8; location / { try_files \$uri \$uri/ /index.php?\$query_string; } location = /favicon.ico { access_log off; log_not_found off; } location = /robots.txt { access_log off; log_not_found off; } error_page 404 /index.php; location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/var/run/php/php8.1-fpm.sock; fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name; include fastcgi_params; } location ~ /\.(?!well-known).* { deny all; } access_log /var/log/nginx/${domain}_access.log; error_log /var/log/nginx/${domain}_error.log; }
EOF_NGINX_LARAVEL
    check_panel_error "Tạo config Nginx Laravel thất bại" || return
    ln -sf "$nginx_conf" "$nginx_link"; check_panel_error "Tạo symlink Nginx Laravel thất bại" || return
    nginx -t; if check_panel_error "Lỗi config Nginx Laravel"; then rm -f "$nginx_link"; else systemctl reload nginx; if check_panel_error "Reload Nginx thất bại"; then rm -f "$nginx_link"; else echo "${GREEN}Cài Laravel và cấu hình Nginx cho $domain OK.${NC}"; panel_log "Cài Laravel $domain OK."; echo -n "Cài SSL? (y/n): "; read -r sslnow; if [[ "$sslnow" == "y" ]]; then install_ssl_for_domain "$domain"; fi; echo "${YELLOW}Lưu ý: Cấu hình .env, chạy key:generate và migrate!${NC}"; fi; fi
    press_any_key
}

# Xem Thông tin Server
show_server_info() {
    clear; echo -e "${GREEN}=== THÔNG TIN SERVER ===${NC}"
    echo -e "${YELLOW}System:${NC}"; hostnamectl | grep -E 'Operating System|Kernel|Architecture'; echo
    echo -e "${YELLOW}CPU:${NC}"; lscpu | grep -E '^CPU\(s\):|^Model name:'; echo
    echo -e "${YELLOW}RAM:${NC}"; free -h | grep Mem; echo
    echo -e "${YELLOW}Disk:${NC}"; df -hT --exclude-type=tmpfs --exclude-type=devtmpfs; echo
    echo -e "${YELLOW}IP Addresses:${NC}"; ip -4 -o addr show scope global | awk '{print $2 ": " $4}' | cut -d'/' -f1; ip -6 -o addr show scope global | awk '{print $2 ": " $4}' | cut -d'/' -f1 || echo " (No IPv6 global address)"; echo
    echo -e "${YELLOW}Services Status:${NC}"; declare -A si=(["nginx"]="Nginx" ["php8.1-fpm"]="PHP FPM" ["mariadb"]="MariaDB" ["redis-server"]="Redis" ["supervisor"]="Supervisor"); for k in "${!si[@]}"; do if systemctl is-active --quiet "$k"; then echo " - ${si[$k]}: ${GREEN}Running${NC}"; elif systemctl is-enabled --quiet "$k"; then echo " - ${si[$k]}: ${YELLOW}Enabled but not running${NC}"; else echo " - ${si[$k]}: ${RED}Inactive/Disabled${NC}"; fi; done; echo
    echo -e "${YELLOW}Versions:${NC}"; echo " - Nginx: $(nginx -v 2>&1)"; echo " - PHP: $(php -v | head -n 1)"; echo " - MariaDB: $(mysql -V)"; echo " - Redis: $(redis-server -v | awk '{print $3}' | sed 's/v=//')"; echo " - Node: $(node -v)"; echo " - npm: $(npm -v)"; echo " - Composer: $(composer --version)"; echo
    press_any_key
}

# Cập nhật Panel
update_panel() {
    clear; echo -e "${GREEN}=== CẬP NHẬT PANEL ===${NC}"
    echo "Đang kiểm tra phiên bản mới..."; CUR_VER="1.0.1"; if [ -f "$CONFIG_DIR/version" ]; then CUR_VER=$(cat "$CONFIG_DIR/version"); fi
    LATEST_VER_URL="https://raw.githubusercontent.com/Webest-Group/script-LEMP-webest/main/VERSION"; LATEST_VER=$(curl -sSL "$LATEST_VER_URL")
    if [[ -z "$LATEST_VER" ]]; then echo "${RED}Không thể kiểm tra phiên bản mới.${NC}"; elif [[ "$CUR_VER" == "$LATEST_VER" ]]; then echo "${GREEN}Bạn đang dùng bản mới nhất ($CUR_VER).${NC}"; else echo "${YELLOW}Có bản mới ($LATEST_VER)! Hiện tại: $CUR_VER.${NC}"; echo "Chạy lại lệnh cài đặt để cập nhật:"; echo "${YELLOW}curl -sSL https://raw.githubusercontent.com/Webest-Group/script-LEMP-webest/main/install.sh | sudo bash${NC}"; fi
    press_any_key
}

# --- Menu Chính ---
show_menu() {
    check_root # Cần root để chạy các chức năng
    clear; echo -e "${BLUE}=======================================${NC}"
    echo -e "${GREEN}       WEBEST VPS PANEL v1.0.1       ${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo "  1) Domain"; echo "  2) SSL"; echo "  3) Database"; echo "  4) Backup"; echo "  5) Service"; echo "  6) Laravel"; echo "  7) Server Info"; echo "  8) Check Update"; echo "  0) Thoát"
    echo -e "${BLUE}---------------------------------------${NC}"; echo -n "Lựa chọn [0-8]: "; read -r choice; panel_log "Menu choice: $choice"
    case $choice in
        1) manage_domain ;; 2) manage_ssl ;; 3) manage_database ;; 4) manage_backup ;; 5) manage_service ;;
        6) install_laravel ;; 7) show_server_info ;; 8) update_panel ;;
        0) echo "${GREEN}Tạm biệt!${NC}"; panel_log "Panel exited."; exit 0 ;;
        *) echo "${RED}Lựa chọn không hợp lệ.${NC}"; panel_log "Invalid menu choice: $choice"; sleep 1 ;;
    esac
}

# --- Điểm Bắt đầu Thực thi ---
# Chạy hàm main và lấy mã thoát
main() {
    if [ "$INSTALL_MODE" = true ]; then
        log "============================================="
        log "=== BẮT ĐẦU CÀI ĐẶT WEBEST VPS PANEL ==="
        log "============================================="
        echo -e "${GREEN}=== BẮT ĐẦU CÀI ĐẶT WEBEST VPS PANEL ===${NC}"
        echo "Nhật ký cài đặt chi tiết: $LOG_DIR/install.log"
        sleep 1

        # Thực hiện tuần tự các bước, thoát nếu có lỗi nghiêm trọng
        fix_network             || return 1 # Thoát nếu không sửa được network
        fix_apt                 || return 1 # Thoát nếu không sửa được apt
        # fix_repository        # Chỉ chạy nếu cần

        install_dependencies    || return 1 # Thoát nếu cài dependencies lỗi
        create_webestvps_script || return 1 # Thoát nếu tạo script panel lỗi
        configure_services      || return 1 # Thoát nếu cấu hình service lỗi
        check_installation      || return 1 # Thoát nếu kiểm tra cuối cùng lỗi

        # Nếu đến được đây là thành công
        echo
        echo -e "${GREEN}===============================================${NC}"
        echo -e "${GREEN}  CÀI ĐẶT WEBEST VPS PANEL HOÀN TẤT!           ${NC}"
        echo -e "${GREEN}===============================================${NC}"
        echo " Sử dụng lệnh: ${YELLOW}sudo webestvps${NC} để quản lý."
        echo " Trang web mặc định: http://<IP_SERVER>"
        echo " Nhật ký cài đặt: $LOG_DIR/install.log"
        echo " Nhật ký panel: $LOG_DIR/webestvps.log"
        echo
        log "=== CÀI ĐẶT HOÀN TẤT THÀNH CÔNG ==="
        return 0

    else
        # Chế độ Menu Tương tác (khi chạy install.sh menu)
        # Script /opt/webestvps/webestvps sẽ xử lý việc này khi được gọi bằng lệnh `webestvps`
        echo "Script cài đặt được gọi ở chế độ menu."
        echo "Để chạy panel quản lý, hãy sử dụng lệnh:"
        echo -e "  ${YELLOW}sudo webestvps${NC}"
        return 0
    fi
}

# --- Điểm Bắt đầu Thực thi ---
# Chạy hàm main và lấy mã thoát
main
main_exit_code=$?

# Ghi log kết thúc dựa trên mã thoát của main
if [ $main_exit_code -eq 0 ]; then
    log "Script install.sh kết thúc thành công."
else
    log "Script install.sh kết thúc với lỗi (Exit Code: $main_exit_code)."
    echo
    echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
    echo -e "${RED}   CÀI ĐẶT WEBEST VPS PANEL THẤT BẠI!         ${NC}"
    echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
    echo " Vui lòng kiểm tra log: ${YELLOW}$LOG_DIR/install.log${NC}"
fi

exit $main_exit_code 