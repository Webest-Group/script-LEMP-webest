#!/bin/bash

setup_backup_dirs() {
    log "Thiết lập thư mục backup..."
    
    # Tạo thư mục backup
    mkdir -p /backup/{databases,files,configs}
    chmod 700 /backup
    
    log "Thiết lập thư mục backup hoàn tất"
    echo -e "${GREEN}Đã tạo thư mục backup thành công!${NC}"
}

setup_database_backup() {
    log "Thiết lập backup database..."
    
    # Tạo script backup database
    cat > /usr/local/bin/backup-databases.sh <<EOF
#!/bin/bash

# Thông tin backup
BACKUP_DIR="/backup/databases"
DATE=\$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Backup MariaDB
if command -v mysql &> /dev/null; then
    echo "Backing up MariaDB databases..."
    databases=\$(mysql -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)")
    
    for db in \$databases; do
        mysqldump --single-transaction \$db > "\$BACKUP_DIR/mariadb_\${db}_\${DATE}.sql"
        gzip "\$BACKUP_DIR/mariadb_\${db}_\${DATE}.sql"
    done
fi

# Backup PostgreSQL
if command -v psql &> /dev/null; then
    echo "Backing up PostgreSQL databases..."
    databases=\$(psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;")
    
    for db in \$databases; do
        pg_dump -U postgres \$db > "\$BACKUP_DIR/postgresql_\${db}_\${DATE}.sql"
        gzip "\$BACKUP_DIR/postgresql_\${db}_\${DATE}.sql"
    done
fi

# Xóa backup cũ
find \$BACKUP_DIR -type f -mtime +\$RETENTION_DAYS -delete
EOF
    
    chmod +x /usr/local/bin/backup-databases.sh
    
    # Tạo cronjob
    echo "0 2 * * * /usr/local/bin/backup-databases.sh" > /etc/cron.d/database-backup
    
    log "Thiết lập backup database hoàn tất"
    echo -e "${GREEN}Đã thiết lập backup database thành công!${NC}"
}

setup_files_backup() {
    log "Thiết lập backup files..."
    
    # Tạo script backup files
    cat > /usr/local/bin/backup-files.sh <<EOF
#!/bin/bash

# Thông tin backup
BACKUP_DIR="/backup/files"
DATE=\$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Backup web files
tar -czf "\$BACKUP_DIR/www_\${DATE}.tar.gz" /var/www

# Backup nginx configs
tar -czf "\$BACKUP_DIR/nginx_\${DATE}.tar.gz" /etc/nginx

# Backup PHP configs
tar -czf "\$BACKUP_DIR/php_\${DATE}.tar.gz" /etc/php

# Xóa backup cũ
find \$BACKUP_DIR -type f -mtime +\$RETENTION_DAYS -delete
EOF
    
    chmod +x /usr/local/bin/backup-files.sh
    
    # Tạo cronjob
    echo "0 3 * * * /usr/local/bin/backup-files.sh" > /etc/cron.d/files-backup
    
    log "Thiết lập backup files hoàn tất"
    echo -e "${GREEN}Đã thiết lập backup files thành công!${NC}"
}

setup_remote_backup() {
    log "Thiết lập backup remote..."
    
    # Cài đặt rclone
    curl https://rclone.org/install.sh | bash
    
    # Tạo script sync backup
    cat > /usr/local/bin/sync-backup.sh <<EOF
#!/bin/bash

# Thông tin remote
REMOTE_NAME="remote"
REMOTE_PATH="backup"

# Sync backup to remote
rclone sync /backup \$REMOTE_NAME:\$REMOTE_PATH
EOF
    
    chmod +x /usr/local/bin/sync-backup.sh
    
    # Tạo cronjob
    echo "0 4 * * * /usr/local/bin/sync-backup.sh" > /etc/cron.d/remote-backup
    
    log "Thiết lập backup remote hoàn tất"
    echo -e "${GREEN}Đã thiết lập backup remote thành công!${NC}"
    echo -e "${YELLOW}Lưu ý: Bạn cần cấu hình rclone bằng lệnh 'rclone config' để sử dụng tính năng backup remote${NC}"
}

# Hiển thị menu backup
while true; do
    echo -e "${GREEN}=== Thiết Lập Backup ===${NC}"
    echo "1) Thiết lập thư mục backup"
    echo "2) Thiết lập backup database"
    echo "3) Thiết lập backup files"
    echo "4) Thiết lập backup remote"
    echo "5) Thiết lập tất cả"
    echo "6) Quay lại menu chính"
    echo
    echo -n "Nhập lựa chọn của bạn [1-6]: "
    read -r backup_choice

    case $backup_choice in
        1)
            setup_backup_dirs
            ;;
        2)
            setup_database_backup
            ;;
        3)
            setup_files_backup
            ;;
        4)
            setup_remote_backup
            ;;
        5)
            setup_backup_dirs
            setup_database_backup
            setup_files_backup
            setup_remote_backup
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