# WebEST VPS Panel

Panel quản lý VPS với các tính năng tự động hóa cho LEMP stack.

## Cài đặt

```bash
curl -sSL https://raw.githubusercontent.com/Webest-Group/script-LEMP-webest/main/install.sh | sudo bash
```

Sau khi cài đặt xong, sử dụng lệnh:
```bash
webestvps
```

## Hướng dẫn sử dụng

### 1. Tạo domain
- Chọn mục 1
- Nhập tên domain (ví dụ: example.com)
- Script sẽ tạo thư mục và cấu hình Nginx tự động

### 2. Cài đặt SSL
- Chọn mục 2
- Nhập tên domain cần cài SSL
- Script sẽ cài đặt Certbot và cấu hình SSL tự động

### 3. Tạo database
- Chọn mục 3
- Nhập tên database
- Nhập tên user
- Nhập mật khẩu
- Script sẽ tạo database và user với quyền truy cập

### 4. Backup
- Chọn mục 4
- Nhập tên domain cần backup
- Script sẽ backup:
  - Toàn bộ file trong thư mục domain
  - Database (nếu là WordPress)

### 5. Quản lý service
- Chọn mục 5
- Chọn service cần quản lý:
  1. Nginx
  2. PHP-FPM
  3. MariaDB
  4. Redis
- Chọn tác vụ:
  1. Khởi động service
  2. Dừng service
  3. Khởi động lại service
  4. Kiểm tra trạng thái service

### 6. Setup Git Hook (Tự động cập nhật code từ GitHub)

#### Bước 1: Tạo SSH key trên server
```bash
# Tạo SSH key
ssh-keygen -t ed25519 -C "your-email@example.com"
# Hiển thị public key
cat ~/.ssh/id_ed25519.pub
```

#### Bước 2: Thêm SSH key vào GitHub
1. Vào GitHub > Settings > SSH and GPG keys
2. Click "New SSH key"
3. Nhập:
   - Title: Tên server (ví dụ: Production Server)
   - Key: Dán nội dung public key đã copy ở bước 1
4. Click "Add SSH key"

#### Bước 3: Cấu hình Git Hook
1. Chọn mục 6 trong menu
2. Nhập thông tin:
   - Tên domain: example.com
   - Tên repository: user/repo (ví dụ: Webest-Group/script-LEMP-webest)
   - Tên branch: main (hoặc branch bạn muốn theo dõi)

#### Bước 4: Cấu hình Webhook trên GitHub
1. Vào repository trên GitHub
2. Vào Settings > Webhooks > Add webhook
3. Nhập thông tin:
   - Payload URL: `http://example.com/webhook.php`
   - Content type: `application/json`
   - Secret: `webestvps`
   - Events: Chọn "Just the push event"
4. Click "Add webhook"

#### Bước 5: Kiểm tra hoạt động
1. Push một thay đổi lên repository
2. Kiểm tra log webhook trên GitHub
3. Kiểm tra file trên server đã được cập nhật

### 7. Cập nhật WebEST VPS
- Chọn mục 7
- Script sẽ kiểm tra phiên bản mới
- Nếu có phiên bản mới, chọn y để cập nhật

### 8. Thoát
- Chọn mục 8 để thoát khỏi panel

## Lưu ý
- Đảm bảo chạy script với quyền root (sudo)
- Kiểm tra log nếu gặp lỗi
- Đảm bảo domain đã được trỏ về server
- Đảm bảo server có quyền truy cập repository GitHub
- Nếu gặp lỗi webhook, kiểm tra log của Nginx và PHP-FPM 