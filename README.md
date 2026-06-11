# NSO Server

> Server game NSO chạy bằng Docker Compose. Docker build server từ source code .

---

## Mục lục

- [Yêu cầu](#yêu-cầu)
- [Cài đặt trên Ubuntu / VPS](#cài-đặt-trên-ubuntu--vps)
- [Cài đặt trên Windows](#cài-đặt-trên-windows)
- [Dịch vụ & Cổng kết nối](#dịch-vụ--cổng-kết-nối)
- [Quản lý server](#quản-lý-server)
- [Cấu hình](#cấu-hình)
- [Lưu ý về Git](#lưu-ý-về-git)

---

## Yêu cầu

| Công cụ | Ghi chú |
|---|---|
| Git | Clone repository |
| Docker Desktop / Docker Engine | Chạy container |
| Docker Compose | Quản lý các service |
| `wget` + `unzip` | Tải và giải nén dữ liệu (Linux) |

Trên Ubuntu/VPS, cài đặt các gói cần thiết bằng:

```sh
sudo apt update && sudo apt install -y git wget unzip
```

---

## Cài đặt trên Ubuntu / VPS

### 1. Clone repository

```sh
git clone https://github.com/ndgiang02/nsoz-private.git
cd nsoz
```

### 2. Tải dữ liệu game

```sh
wget -O Data.zip "https://github.com/ndgiang02/nsoz-private/releases/download/data/Data.zip"
unzip Data.zip
```

Sau khi giải nén, kiểm tra cấu trúc thư mục:

```sh
ls Data
# Kết quả mong đợi: Map  Img  Lang  ...
```

Cấu trúc đúng sẽ là:

```
nsoz/
└── Data/
    ├── Map/
    ├── Img/
    └── Lang/
```

### 3. Khởi động server

**Lần đầu chạy** (build image và khởi động):

```sh
docker compose up --build
```

> Lần đầu có thể mất vài phút do Docker cần tải image và Maven dependencies.

**Các lần tiếp theo:**

```sh
docker compose up
```

**Chạy nền (detached mode):**

```sh
docker compose up -d --build
```

**Xem log realtime:**

```sh
docker compose logs -f server
```

---

## Cài đặt trên Windows

### Cài đặt phần mềm cần thiết

- [Git for Windows](https://git-scm.com/download/win)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [7-Zip](https://www.7-zip.org/) hoặc WinRAR để giải nén

### 1. Clone repository

Mở **PowerShell** hoặc **Git Bash**:

```powershell
git clone <repository-url>
cd nsoz
```

### 2. Tải tài nguyên game

Tải bằng PowerShell:

```powershell
Invoke-WebRequest -Uri "https://github.com/ndgiang02/nsoz-private/releases/download/data/Data.zip" -OutFile "Data.zip"
```

Hoặc tải thủ công qua trình duyệt:

```
https://github.com/ndgiang02/nsoz-private/releases/download/data/Data.zip
```

Giải nén `Data.zip` vào thư mục gốc của project. Sau khi giải nén, kiểm tra:

```powershell
dir Data
# Kết quả mong đợi: Map  Img  Lang  ...
```

### 3. Khởi động server

```powershell
# Lần đầu (build + chạy)
docker compose up --build

# Chạy nền
docker compose up -d --build

# Xem log
docker compose logs -f server
```

---

## Dịch vụ & Cổng kết nối

| Dịch vụ | Địa chỉ |
|---|---|
| Game Server | `127.0.0.1:14444` |
| Server List | `http://127.0.0.1:8080` |
| phpMyAdmin | `http://127.0.0.1:8081` |
| MariaDB | `127.0.0.1:3306` |
| MongoDB | `127.0.0.1:27017` |

### Thông tin đăng nhập database mặc định

| | MariaDB (user) | MariaDB (root) |
|---|---|---|
| **Host** | `db` | `db` |
| **Username** | `nsoz` | `root` |
| **Password** | `nsoz_password` | `root_password` |
| **Database** | `nsoz2` | — |

---

## Quản lý server

### Dừng server

```sh
# Dừng nếu đang chạy trong terminal
Ctrl + C

# Dừng nếu đang chạy nền
docker compose down
```

### Reset toàn bộ dữ liệu

Xóa toàn bộ volume và import lại từ `database/database.sql`:

```sh
docker compose down -v
docker compose up --build
```

---

## Cấu hình

File `config.properties` được tạo tự động khi container khởi động, dựa trên biến môi trường trong `docker-compose.yml`.

Để thay đổi port, thông tin database, hoặc các tham số game — chỉnh sửa phần `environment` của service `server` trong `docker-compose.yml`.

---

## Lưu ý về Git

Các thư mục `target/`, `out/`, `Data/` và file `.jar` build local đã được khai báo trong `.gitignore`. Không commit file build hay tài nguyên nặng lên repository.

Nếu repository cũ đã từng commit `target/` hoặc `Data/`, chạy lệnh sau để xóa khỏi Git index:

```sh
git rm -r --cached target
git rm -r --cached Data
git add .
git commit -m "chore: remove build output and external game data from tracking"
```