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