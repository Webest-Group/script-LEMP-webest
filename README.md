# WebEST VPS Panel

Panel quan ly VPS voi cac chuc nang:
- Quan ly domain (Laravel, WordPress, Code normal)
- Quan ly database
- Cai dat SSL
- Backup
- Quan ly service
- Setup Git Hook
- Cap nhat tu dong

## Cai dat

```bash
curl -sSL https://raw.githubusercontent.com/Webest-Group/script-LEMP-webest/main/install.sh | sudo bash
```

Sau khi cai dat xong, chay lenh `webestvps` de su dung panel.

## Huong dan su dung

### 1. Quan ly Domain

#### 1.1. Tao domain moi
- Nhap ten domain
- Chon loai domain:
  - Laravel: Tu dong tao .env, database va cau hinh
  - WordPress: Tu dong tai va cai dat WordPress
  - Code normal: Tao trang web co ban

#### 1.2. Xoa domain
- Nhap ten domain can xoa
- Xac nhan xoa
- Tu dong xoa thu muc va cau hinh Nginx

#### 1.3. Xem danh sach domain
- Hien thi tat ca domain dang co
- Thong tin chi tiet:
  - Duong dan thu muc
  - Cau hinh Nginx
  - Trang thai hoat dong

### 2. Quan ly Database

#### 2.1. Tao database moi
- Nhap ten database
- Nhap ten user
- Nhap mat khau
- Tu dong tao database va user

#### 2.2. Xoa database
- Nhap ten database can xoa
- Xac nhan xoa
- Tu dong xoa database va user

#### 2.3. Xem danh sach database
- Hien thi tat ca database dang co
- Thong tin chi tiet:
  - Ten database
  - User
  - Quyen truy cap

### 3. Cai dat SSL
- Nhap ten domain can cai SSL
- Tu dong cai dat Certbot
- Cau hinh Nginx voi SSL

### 4. Backup
- Nhap ten domain can backup
- Tu dong backup:
  - Files trong thu muc domain
  - Database (neu co)

### 5. Quan ly Service
- Chon service can quan ly:
  - Nginx
  - PHP-FPM
  - MariaDB
  - Redis
- Cac tac vu:
  - Khoi dong
  - Dung
  - Khoi dong lai
  - Kiem tra trang thai

### 6. Setup Git Hook
- Nhap ten domain
- Nhap ten repository (user/repo)
- Nhap ten branch (mac dinh: main)
- Tu dong:
  - Khoi tao Git repository
  - Tao webhook endpoint
  - Cau hinh Nginx
  - Cap nhat code tu dong khi co push

### 7. Cap nhat WebEST VPS
- Tu dong kiem tra phien ban moi
- Cap nhat cac file cau hinh
- Khoi dong lai panel

## Yeu cau he thong
- Ubuntu 20.04 hoac cao hon
- Quyen root hoac sudo
- Ket noi Internet
- Toi thieu 1GB RAM
- Toi thieu 10GB dung luong

## Lien he
- Website: https://webest.vn
- Email: support@webest.vn
- GitHub: https://github.com/Webest-Group/script-LEMP-webest 