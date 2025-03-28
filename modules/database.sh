#!/bin/bash

install_mariadb() {
    log "Bắt đầu cài đặt MariaDB..."
    
    # Thêm repository MariaDB
    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
    
    # Cài đặt MariaDB
    apt update
    apt install -y mariadb-server mariadb-client
    
    # Cấu hình bảo mật cơ bản
    mysql_secure_installation <<EOF

y
your_root_password
your_root_password
y
y
y
y
EOF
    
    # Backup file cấu hình gốc
    cp /etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf.backup
    
    # Tối ưu cấu hình MariaDB
    cat > /etc/mysql/mariadb.conf.d/50-server.cnf <<EOF
[mysqld]
bind-address            = 127.0.0.1
key_buffer_size         = 128M
max_allowed_packet      = 64M
thread_stack            = 192K
thread_cache_size       = 8
max_connections         = 100
query_cache_limit       = 2M
query_cache_size        = 64M
expire_logs_days        = 10
character-set-server    = utf8mb4
collation-server        = utf8mb4_unicode_ci

# InnoDB Configuration
innodb_buffer_pool_size = 1G
innodb_log_file_size    = 256M
innodb_file_per_table   = 1
innodb_flush_method     = O_DIRECT
innodb_flush_log_at_trx_commit = 1
EOF
    
    # Khởi động lại MariaDB
    systemctl restart mariadb
    systemctl enable mariadb
    
    log "Cài đặt MariaDB hoàn tất"
    echo -e "${GREEN}MariaDB đã được cài đặt và cấu hình thành công!${NC}"
}

install_postgresql() {
    log "Bắt đầu cài đặt PostgreSQL..."
    
    # Thêm repository PostgreSQL
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    
    # Cài đặt PostgreSQL
    apt update
    apt install -y postgresql postgresql-contrib
    
    # Backup file cấu hình gốc
    cp /etc/postgresql/*/main/postgresql.conf /etc/postgresql/*/main/postgresql.conf.backup
    
    # Tối ưu cấu hình PostgreSQL
    cat > /etc/postgresql/*/main/postgresql.conf <<EOF
# Connection Settings
listen_addresses = 'localhost'
max_connections = 100

# Memory Settings
shared_buffers = 256MB
work_mem = 6MB
maintenance_work_mem = 64MB

# Write Ahead Log
wal_level = replica
synchronous_commit = on
wal_sync_method = fsync
wal_buffers = 16MB
checkpoint_timeout = 5min
max_wal_size = 1GB
min_wal_size = 80MB

# Query Planner
effective_cache_size = 768MB
random_page_cost = 4.0
cpu_tuple_cost = 0.01
cpu_index_tuple_cost = 0.005
cpu_operator_cost = 0.0025

# Locale and Encoding
datestyle = 'iso, mdy'
timezone = 'UTC'
lc_messages = 'en_US.UTF-8'
lc_monetary = 'en_US.UTF-8'
lc_numeric = 'en_US.UTF-8'
lc_time = 'en_US.UTF-8'
default_text_search_config = 'pg_catalog.english'
EOF
    
    # Khởi động lại PostgreSQL
    systemctl restart postgresql
    systemctl enable postgresql
    
    # Tạo user và database mặc định
    sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'your_postgres_password';"
    
    log "Cài đặt PostgreSQL hoàn tất"
    echo -e "${GREEN}PostgreSQL đã được cài đặt và cấu hình thành công!${NC}"
}

# Hiển thị menu cài đặt Database
while true; do
    echo -e "${GREEN}=== Cài đặt Database ===${NC}"
    echo "1) Cài đặt MariaDB"
    echo "2) Cài đặt PostgreSQL"
    echo "3) Cài đặt cả MariaDB và PostgreSQL"
    echo "4) Quay lại menu chính"
    echo
    echo -n "Nhập lựa chọn của bạn [1-4]: "
    read -r db_choice

    case $db_choice in
        1)
            install_mariadb
            ;;
        2)
            install_postgresql
            ;;
        3)
            install_mariadb
            install_postgresql
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