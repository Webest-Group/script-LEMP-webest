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

# --- Phần còn lại của script panel ---
# Quản lý SSL, Database, Backup, Service, Laravel, Server Info, Update Panel, Menu Chính
# Lược bỏ để tiết kiệm dung lượng

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
while true; do show_menu; done
EOF_PANEL_SCRIPT

    check_install_error "Không thể tạo file panel" || return 1
    chmod +x "$INSTALL_DIR/webestvps"
    check_install_error "Không thể phân quyền execute cho file panel" || return 1

    # Tạo symlink để sử dụng từ bất kỳ đâu
    ln -sf "$INSTALL_DIR/webestvps" /usr/local/bin/webestvps
    check_install_error "Không thể tạo symlink webestvps" || return 1

    # Lưu phiên bản vào file
    echo "$PANEL_VERSION" > "$CONFIG_DIR/version"
    check_install_error "Không thể lưu thông tin phiên bản" || return 1

    log "${GREEN}Đã tạo file panel thành công.${NC}"
    return 0
}

# Function cấu hình dịch vụ
configure_services() {
    log "===== Bắt đầu Cấu hình Dịch vụ ====="
    
    # --- Cấu hình Nginx ---
    log "Cấu hình Nginx cho trang chào mừng và tài liệu..."
    
    # Tạo file web chào mừng
    if [ ! -d "$WEB_ROOT/default" ]; then
        mkdir -p "$WEB_ROOT/default"
        check_install_error "Không thể tạo thư mục root mặc định" || return 1
        cat > "$WEB_ROOT/default/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>WEBESTVPS - Chào mừng!</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 50px; line-height: 1.6; }
        h1 { color: #336699; }
        .container { max-width: 800px; margin: 0 auto; padding: 20px; border: 1px solid #ddd; border-radius: 5px; }
        .footer { margin-top: 40px; font-size: 12px; color: #777; text-align: center; }
        .cmd { background: #f5f5f5; padding: 10px; border-radius: 3px; font-family: monospace; }
    </style>
</head>
<body>
    <div class="container">
        <h1>WEBESTVPS - Server đã sẵn sàng!</h1>
        <p>Nếu bạn thấy trang này, LEMP stack đã được cài đặt thành công trên server của bạn.</p>
        <p>Để quản lý server, sử dụng lệnh:</p>
        <p class="cmd">sudo webestvps</p>
        <div class="footer">
            <p>WEBESTVPS Panel v$PANEL_VERSION | Cài đặt lúc: $(date '+%Y-%m-%d %H:%M:%S')</p>
        </div>
    </div>
</body>
</html>
EOF
        check_install_error "Không thể tạo file index.html" || return 1
        chown -R www-data:www-data "$WEB_ROOT/default"
        check_install_error "Không thể phân quyền thư mục web mặc định" || return 1
    fi

    # Cấu hình Nginx mặc định
    NGINX_DEFAULT_CONF="/etc/nginx/sites-available/default"
    if [ -f "$NGINX_DEFAULT_CONF" ]; then
        cp "$NGINX_DEFAULT_CONF" "$NGINX_DEFAULT_CONF.backup.$$"
        check_install_error "Không thể backup file cấu hình Nginx mặc định" || return 1
    fi

    cat > "$NGINX_DEFAULT_CONF" << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root $WEB_ROOT/default;
    index index.html index.php;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF
    check_install_error "Không thể tạo file cấu hình Nginx mặc định" || return 1

    # Kiểm tra cấu hình Nginx và khởi động lại
    nginx -t
    check_install_error "Cấu hình Nginx không hợp lệ" || return 1
    systemctl restart nginx
    check_install_error "Không thể khởi động lại Nginx" || return 1

    # --- Cấu hình MariaDB ---
    if ! mysql -e "SELECT 1" &>/dev/null; then
        log "Cấu hình cơ bản MariaDB..."
        # Đảm bảo MariaDB đang chạy
        systemctl restart mariadb
        sleep 3
        
        # Tạo file cấu hình tạm thời
        TMP_SQL="/tmp/mariadb_secure_$$.sql"
        cat > "$TMP_SQL" << EOF
UPDATE mysql.user SET Password=PASSWORD('') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
        mysql < "$TMP_SQL"
        check_install_error "Không thể thực hiện cấu hình bảo mật cơ bản cho MariaDB" || return 1
        rm -f "$TMP_SQL"
    else
        log "MariaDB đã được cấu hình trước đó."
    fi

    # --- Cấu hình PHP ---
    if [ -f "/etc/php/8.1/fpm/php.ini" ]; then
        log "Cấu hình PHP..."
        cp "/etc/php/8.1/fpm/php.ini" "/etc/php/8.1/fpm/php.ini.backup.$$"
        check_install_error "Không thể backup file cấu hình PHP" || return 1
        
        # Cập nhật các giá trị
        sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/g' "/etc/php/8.1/fpm/php.ini"
        sed -i 's/post_max_size = .*/post_max_size = 64M/g' "/etc/php/8.1/fpm/php.ini"
        sed -i 's/memory_limit = .*/memory_limit = 256M/g' "/etc/php/8.1/fpm/php.ini"
        sed -i 's/max_execution_time = .*/max_execution_time = 300/g' "/etc/php/8.1/fpm/php.ini"
        
        # Khởi động lại PHP-FPM
        systemctl restart php8.1-fpm
        check_install_error "Không thể khởi động lại PHP-FPM" || return 1
    fi

    log "${GREEN}===== Hoàn tất Cấu hình Dịch vụ =====${NC}"
    return 0
}

# Function kiểm tra cài đặt
check_installation() {
    log "===== Bắt đầu Kiểm tra Cài đặt ====="
    
    # Kiểm tra các service cần thiết
    local services=("nginx" "php8.1-fpm" "mariadb" "redis-server" "supervisor")
    local failed=0
    
    log "Kiểm tra trạng thái các service..."
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "${GREEN}Service $service: Đang chạy${NC}"
        else
            log "${RED}Service $service: Không chạy${NC}"
            failed=1
        fi
    done
    
    # Kiểm tra file webestvps và symlink
    if [ -f "$INSTALL_DIR/webestvps" ]; then
        log "${GREEN}File panel $INSTALL_DIR/webestvps: Tồn tại${NC}"
    else
        log "${RED}File panel $INSTALL_DIR/webestvps: Không tồn tại${NC}"
        failed=1
    fi
    
    if [ -L "/usr/local/bin/webestvps" ]; then
        log "${GREEN}Symlink /usr/local/bin/webestvps: Tồn tại${NC}"
    else
        log "${RED}Symlink /usr/local/bin/webestvps: Không tồn tại${NC}"
        failed=1
    fi
    
    # Kiểm tra Nginx
    if nginx -t &>/dev/null; then
        log "${GREEN}Cấu hình Nginx: Hợp lệ${NC}"
    else
        log "${RED}Cấu hình Nginx: Không hợp lệ${NC}"
        nginx -t
        failed=1
    fi
    
    # Kiểm tra MariaDB
    if mysql -e "SELECT 1" &>/dev/null; then
        log "${GREEN}Kết nối MariaDB: OK${NC}"
    else
        log "${RED}Kết nối MariaDB: Lỗi${NC}"
        failed=1
    fi
    
    if [ $failed -eq 0 ]; then
        log "${GREEN}===== Kiểm tra Cài đặt THÀNH CÔNG =====${NC}"
        return 0
    else
        log "${RED}===== Kiểm tra Cài đặt CÓ LỖI =====${NC}"
        return 1
    fi
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
