# Script Cài Đặt LEMP Stack Tự Động

Script tự động cài đặt và cấu hình LEMP Stack (Linux, Nginx, MySQL/MariaDB, PHP) cho Ubuntu Server. Script này được thiết kế để tối ưu hóa và bảo mật server cho môi trường production.

## Tính Năng

### 1. Webserver
- Nginx (phiên bản stable mới nhất)
- Cấu hình tối ưu cho hiệu suất cao
- Hỗ trợ HTTP/2, SSL/TLS
- Tự động cấu hình theo tài nguyên server

### 2. PHP
- Hỗ trợ PHP 8.1 và 8.3
- Tùy chọn phiên bản PHP cho từng domain
- Cài đặt sẵn các extension phổ biến cho Laravel
- PHP-FPM được tối ưu theo tài nguyên server

### 3. Database
- MariaDB (phiên bản stable)
- PostgreSQL (tùy chọn)
- Tự động tối ưu cấu hình theo RAM
- Backup tự động

### 4. Bảo Mật
- Tự động cài đặt SSL với Let's Encrypt
- UFW Firewall được cấu hình sẵn
- Fail2ban chống brute force
- ModSecurity WAF
- ClamAV Antivirus
- Các thiết lập bảo mật PHP tối ưu

### 5. Monitoring & Logging
- Monit để giám sát service
- Log rotation
- Error logging
- Access logging

### 6. Performance
- Redis/Memcached cho caching
- Nginx FastCGI cache
- PHP OpCache
- MariaDB Query Cache

### 7. Backup System
- Backup tự động database
- Backup tự động files
- Tùy chọn backup remote (rclone)
- Rotation policy

### 8. Quản Lý Domain
- Thêm/xóa domain dễ dàng
- Tùy chọn phiên bản PHP cho từng domain
- Tùy chọn loại database
- Hỗ trợ Cloudflare

## Yêu Cầu Hệ Thống

- Ubuntu 20.04/22.04/23.04 LTS
- Tối thiểu 1GB RAM (khuyến nghị 2GB)
- Tối thiểu 20GB dung lượng ổ cứng
- Kết nối internet ổn định
- Quyền root hoặc sudo

## Cách Sử Dụng

### Cài Đặt Nhanh

```bash
curl -sSL https://raw.githubusercontent.com/Webest-Group/script-LEMP-webest/main/setup.sh | sudo bash
```

hoặc

```bash
wget -O - https://raw.githubusercontent.com/Webest-Group/script-LEMP-webest/main/setup.sh | sudo bash
```

### Cài Đặt An Toàn (Khuyến Nghị)

1. Tải script về:
```bash
wget https://raw.githubusercontent.com/Webest-Group/script-LEMP-webest/main/setup.sh
```

2. Phân quyền thực thi:
```bash
chmod +x setup.sh
```

3. Chạy script:
```bash
sudo ./setup.sh
```

## Sử Dụng Menu

Sau khi chạy script, bạn sẽ thấy menu chính với các tùy chọn:

1. Cài đặt Nginx
2. Cài đặt PHP (8.1/8.3)
3. Cài đặt Database (MariaDB/PostgreSQL)
4. Cài đặt SSL
5. Cài đặt Bảo mật
6. Cài đặt Monitoring
7. Cài đặt Performance Optimization
8. Cài đặt Backup System
9. Quản lý Domain
10. Cài đặt Development Tools
11. Cài đặt NodeJS & MongoDB
12. Xem logs

## Quản Lý Domain

### Thêm Domain Mới

1. Chọn option "Quản lý Domain" từ menu chính
2. Chọn "Thêm domain mới"
3. Nhập thông tin:
   - Tên miền (vd: example.com)
   - Phiên bản PHP (8.1 hoặc 8.3)
   - Loại database (MariaDB/PostgreSQL/None)
   - Sử dụng Cloudflare (Yes/No)

### Xóa Domain

1. Chọn option "Quản lý Domain" từ menu chính
2. Chọn "Xóa domain"
3. Nhập tên miền cần xóa

## Bảo Mật

- Tất cả các file cấu hình gốc đều được backup trước khi thay đổi
- Các mật khẩu được tạo ngẫu nhiên và lưu tại `/root/.server-info`
- Firewall được cấu hình chỉ cho phép các port cần thiết
- Fail2ban được cấu hình để bảo vệ khỏi các cuộc tấn công brute force

## Backup

- Database được backup hàng ngày lúc 2 giờ sáng
- Files được backup hàng ngày lúc 3 giờ sáng
- Backup được lưu tại `/backup`
- Các backup cũ hơn 7 ngày sẽ tự động bị xóa
- Nếu cấu hình backup remote, dữ liệu sẽ được đồng bộ lúc 4 giờ sáng

## Monitoring

- Monit Web Interface: http://your-server-ip:2812
- Netdata (nếu được cài đặt): http://your-server-ip:19999

## Hỗ Trợ VPS Provider

Script đã được test và tương thích với các nhà cung cấp VPS phổ biến:
- Digital Ocean
- Linode
- Vultr
- AWS EC2
- Google Cloud Platform
- Azure

## Xử Lý Sự Cố

### Log Files

- Nginx: `/var/log/nginx/`
- PHP-FPM: `/var/log/php/`
- MariaDB: `/var/log/mysql/`
- Script Installation: `/var/log/server-setup/`

### Rollback

Nếu có lỗi trong quá trình cài đặt, script sẽ tự động rollback về trạng thái trước đó.
Các file backup được lưu tại `/root/server-setup-backup-[timestamp]`

## Cập Nhật

Script tự động kiểm tra và cài đặt các bản cập nhật bảo mật quan trọng.
Để cập nhật script lên phiên bản mới nhất, chạy lại lệnh cài đặt.

## Đóng Góp

Mọi đóng góp đều được chào đón! Vui lòng tạo issue hoặc pull request.

## Giấy Phép

MIT License

## Tác Giả

Webest Group
- Website: [https://webest.com](https://webest.com)
- Email: support@webest.com 