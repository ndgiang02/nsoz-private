# NSO Server

Hướng dẫn cài đặt và chạy server bằng Docker Compose. Project không commit thư mục `Data/` và không commit file build trong `target/`; Docker sẽ tự build server từ source code.
ls
## Yêu cầu

- Git
- Docker Desktop hoặc Docker Engine
- Docker Compose
- `wget`
- `unzip`

Trên Ubuntu/VPS, có thể cài các gói cần thiết bằng:

```sh
sudo apt update
sudo apt install -y git wget unzip
```

## Cài đặt trên VPS Ubuntu

Clone source:

```sh
git clone <repository-url>
cd nsoz
```

Tải `Data.zip` từ GitHub Release:

```sh
wget -O Data.zip "https://github.com/ndgiang02/nsoz-private/releases/download/data/Data.zip"
```

Giải nén Data vào thư mục gốc project:

```sh
unzip Data.zip
```

Sau khi giải nén, cấu trúc phải đúng dạng:

```text
nsoz/Data/...
```

Kiểm tra nhanh:

```sh
ls Data
```

Nếu thấy các thư mục như `Map`, `Img`, `Lang` là đúng.

Chạy toàn bộ hệ thống:

```sh
docker compose up --build
```

Lần đầu chạy có thể mất vài phút vì Docker cần tải image và Maven dependencies. Các lần sau có thể chạy nhanh hơn:

```sh
docker compose up
```

Nếu muốn chạy nền:

```sh
docker compose up -d --build
```

Xem log server:

```sh
docker compose logs -f server
```

## Cài đặt trên Windows

Cài các phần mềm cần thiết:

- Git for Windows
- Docker Desktop
- 7-Zip hoặc WinRAR để giải nén file zip

Mở PowerShell hoặc Git Bash, sau đó clone source:

```powershell
git clone <repository-url>
cd nsoz
```

Tải `Data.zip` từ GitHub Release bằng PowerShell:

```powershell
Invoke-WebRequest -Uri "https://github.com/ndgiang02/nsoz-private/releases/download/data/Data.zip" -OutFile "Data.zip"
```

Hoặc mở link này bằng trình duyệt để tải thủ công:

```text
https://github.com/ndgiang02/nsoz-private/releases/download/data/Data.zip
```

Giải nén `Data.zip` vào thư mục gốc project sao cho đúng cấu trúc:

```text
nsoz\Data\...
```

Ví dụ sau khi giải nén, trong project phải có các thư mục/tệp như:

```text
Data\Map
Data\Img
Data\Lang
```

Kiểm tra nhanh bằng PowerShell:

```powershell
dir Data
```

Chạy toàn bộ hệ thống:

```powershell
docker compose up --build
```

Nếu muốn chạy nền:

```powershell
docker compose up -d --build
```

Xem log server:

```powershell
docker compose logs -f server
```

## Dịch vụ

- Game server: `127.0.0.1:14444`
- Server list: `http://127.0.0.1:8080`
- phpMyAdmin: `http://127.0.0.1:8081`
- MariaDB: `127.0.0.1:3306`
- MongoDB: `127.0.0.1:27017`

Thông tin đăng nhập database mặc định:

```text
Server: db
Username: nsoz
Password: nsoz_password
Database: nsoz2
```

Tài khoản root MariaDB:

```text
Username: root
Password: root_password
```

## Dừng server

Nếu đang chạy trực tiếp trong terminal, nhấn `Ctrl + C`.

Nếu đang chạy nền, dùng:

```sh
docker compose down
```

Trên Windows PowerShell cũng dùng cùng lệnh:

```powershell
docker compose down
```

Nếu muốn xóa toàn bộ dữ liệu database và import lại từ `database/database.sql`:

```sh
docker compose down -v
docker compose up --build
```

Trên Windows PowerShell:

```powershell
docker compose down -v
docker compose up --build
```

## Ghi chú cho Git

Các thư mục `target/`, `out/`, `Data/` và các file jar build local đã được bỏ qua trong `.gitignore`, nên không đẩy file build hoặc tài nguyên nặng lên Git.

Nếu repository cũ đã từng commit `target/` hoặc `Data/`, hãy xóa chúng khỏi Git index một lần:

```sh
git rm -r --cached target
git rm -r --cached Data
git add .
git commit -m "Ignore build output and external game data"
```

## Cấu hình

Container server tạo file `config.properties` lúc khởi động từ biến môi trường trong `docker-compose.yml`. Muốn đổi port, database hoặc cấu hình game, sửa phần `environment` của service `server`.