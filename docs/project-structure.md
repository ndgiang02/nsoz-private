# Tài liệu cấu trúc dự án Nsoz

Tài liệu này mô tả cấu trúc repo, luồng khởi động server, vai trò từng package Java, nơi chỉnh các tính năng thường gặp, và những lưu ý khi sửa để tránh sửa nhầm chỗ.

## 1. Tổng quan repo

Các file/thư mục cấp cao:

| Đường dẫn | Vai trò |
| --- | --- |
| `pom.xml` | Cấu hình Maven, Java source/target 19, build jar có dependencies |
| `src/main/java/com/nsoz` | Source Java chính của game server |
| `src/main/resources` | Resource build-time, hiện có `log4j.properties` |
| `database/database.sql` | File seed database ban đầu |
| `database/update_giang_level69_tieu.sql` | Script update riêng cho nhân vật mẫu `giang` |
| `docs/database-guide.md` | Tài liệu database và chỉnh nhân vật |
| `docs/project-structure.md` | Tài liệu cấu trúc dự án này |
| `config.properties` | Cấu hình server khi chạy local bằng jar/source |
| `docker-compose.yml` | Chạy MariaDB, MongoDB, phpMyAdmin, server-list, server |
| `Dockerfile` | Build container server |
| `docker/server/entrypoint.sh` | Sinh `config.properties` trong container rồi chạy jar |
| `docker/database/Dockerfile` | Build image database |
| `docker/server-list` | File danh sách server cho client |
| `Data` | Dữ liệu client/server resource như map và ngôn ngữ |
| `client` | Các file client jar có sẵn |
| `logs` | Log server cũ |
| `target` | Output Maven build |
| `out` | Output IDE/build cũ |
| `app.jar`, `Nso.jar` | Jar build sẵn |

## 2. Build và entrypoint

### 2.1. Maven

`pom.xml` khai báo:

- `maven.compiler.source=19`
- `maven.compiler.target=19`
- Main class: `com.nsoz.server.NinjaSchool`
- Output assembly jar: `target/Nso-jar-with-dependencies.jar`

Build:

```bash
./mvnw clean package
```

Jar chính sau build thường nằm ở:

```text
target/Nso-jar-with-dependencies.jar
```

### 2.2. Entrypoint Java

Entrypoint:

```java
com.nsoz.server.NinjaSchool.main()
```

Luồng khởi động chính:

1. `Config.getInstance().load()` đọc `config.properties`.
2. `DbManager.getInstance().start()` mở pool MySQL/MariaDB.
3. Kiểm tra port server có rảnh không.
4. Tạo UI `NinjaSchool`.
5. `Server.init()` load dữ liệu DB/resource.
6. `Server.start()` mở socket/game loop/background threads.

Nếu sửa cấu hình trong `config.properties`, restart server.

Nếu sửa dữ liệu cache lúc `Server.init()` load, cũng restart server. Ví dụ: `others`, `item`, `store_data`, `skill`, `map`, `monster`, `npc`.

## 3. Cấu hình chạy local và Docker

### 3.1. Local

File local:

```text
config.properties
```

Các key quan trọng:

| Key | Ý nghĩa |
| --- | --- |
| `server.id` | ID server, phải khớp data trong DB |
| `server.port` | Port game server, mặc định `14444` |
| `db.host`, `db.port`, `db.user`, `db.password`, `db.dbname` | Kết nối MySQL/MariaDB |
| `mongodb.host`, `mongodb.port`, `mongodb.user`, `mongodb.password`, `mongodb.dbname` | Kết nối MongoDB |
| `websocket.host`, `websocket.port` | Socket.IO |
| `game.event` | Class event đang bật |
| `game.upgrade.percent.add` | Cộng phần trăm nâng cấp |
| `game.store.discount` | Giảm giá shop |
| `game.shinwa.active` | Bật/tắt Shinwa |
| `game.arena.active` | Bật/tắt lôi đài |
| `game.login.limit` | Giới hạn login theo IP |
| `game.data.version`, `game.item.version`, `game.map.version`, `game.skill.version` | Version dữ liệu gửi client |
| `game.isTest` | Chế độ test |

### 3.2. Docker

`docker-compose.yml` định nghĩa:

| Service | Vai trò |
| --- | --- |
| `db` | MariaDB, database `nsoz2`, user `nsoz` |
| `phpmyadmin` | UI quản lý DB tại port `8081` |
| `mongo` | MongoDB |
| `server-list` | Nginx serve file list server tại port `8080` |
| `server` | Game server Java tại port `14444` |

`docker/server/entrypoint.sh` sinh `config.properties` từ biến môi trường, ví dụ:

```properties
game.event=${GAME_EVENT:-com.nsoz.event.Halloween}
```

Nếu không set `GAME_EVENT`, container mặc định bật `Halloween`.

Khởi động:

```bash
docker compose up -d --build
```

Xem log:

```bash
docker compose logs -f server
```

Vào DB:

```bash
docker compose exec db mariadb -unsoz -pnsoz_password nsoz2
```

## 4. Luồng `Server.init()`

`Server.init()` là nơi load phần lớn dữ liệu. Thứ tự chính:

1. Kết nối MongoDB.
2. Load NPC: `NpcManager.getInstance().load()`.
3. Load mob: `MobManager.getInstance().load()`.
4. Load map metadata: `MapManager.getInstance().load()`.
5. Load `task` và `task_template` từ DB.
6. Load `others`: part ngoại hình và mảng EXP.
7. Load mount/effect/item/game data/store.
8. Load paint data: `nj_skill`, `nj_part`, `nj_image`, `nj_arrow`, `nj_effect`.
9. Tính `Server.EXP_MAX`.
10. Gửi/set data cache cho client: arrow/effect/image/part/skill/map/version.
11. `Event.init()` tạo event từ `Config.game.event`.
12. Event load điểm event và init store.
13. Init map runtime, ranking, clan, ranked, thiên địa, random item, image map.

Hệ quả:

- Sửa các bảng/template kể trên cần restart server.
- Sửa riêng `players` có thể logout/login lại nhân vật là đủ, nhưng nếu nhân vật đang online thì server có thể save đè lại DB.
- Sửa `config.properties` luôn cần restart.

## 5. Bản đồ package Java

### `com.nsoz.server`

Core server và dữ liệu toàn cục.

| File/Class | Vai trò |
| --- | --- |
| `NinjaSchool` | Main class, UI điều khiển, gọi init/start |
| `Config` | Đọc `config.properties` |
| `Server` | Khởi tạo data, socket server, vòng đời server |
| `GameData` | Load class/skill template và lấy skill theo class |
| `Events` | Hệ event kiểu cũ/static |
| `Ranked`, `Ranking` | Xếp hạng |
| `SpawnBossManager`, `SpawnBoss` | Spawn boss |
| `AutoMaintenance` | Bảo trì tự động |
| `GlobalService` | Broadcast/global message |

Sửa ở đây khi:

- Đổi luồng khởi động.
- Đổi cache/version data gửi client.
- Đổi logic event global.
- Đổi ranking, spawn boss, bảo trì.

### `com.nsoz.db`

Kết nối database.

| Package/Class | Vai trò |
| --- | --- |
| `db.jdbc.DbManager` | Pool MySQL/MariaDB bằng HikariCP |
| `db.mongodb.MongoDbConnection` | Kết nối MongoDB |

Sửa ở đây khi:

- Đổi cách kết nối DB.
- Thêm pool/connection type.
- Debug lỗi mất kết nối hoặc query timeout.

### `com.nsoz.model`

Package lớn nhất, chứa model runtime và rất nhiều gameplay logic.

| Class | Vai trò |
| --- | --- |
| `Char` | Nhân vật chính: load/save DB, combat, exp, inventory, NPC action, task, event hooks |
| `User` | Tài khoản/session user, login/select character |
| `CloneChar` | Phân thân |
| `RandomItem` | Bảng random item/drop theo event |
| `MountDataManager`, `ThanThu` | Thú cưỡi/thần thú |
| `SelectCard*` | Hệ select card/event card |
| `AbsSelectCard` | Base select card |
| `ChatGlobal` | Chat/global event |

Sửa ở đây khi:

- Đổi logic nhân vật, EXP, điểm tiềm năng, skill, trang bị.
- Đổi cách load/save `players`.
- Đổi đánh quái, nhận thưởng, nhiệm vụ, menu NPC.
- Đổi logic item khi người chơi dùng vật phẩm.

Các điểm hay sửa:

| Muốn chỉnh | File/vị trí |
| --- | --- |
| EXP từ quái | `Char.addExp(Mob mob, int dame)` |
| EXP trực tiếp | `Char.addExp(long exp)` |
| Load player từ DB | `Char.load()` quanh vùng query `players` |
| Save player | `Char.save()` quanh vùng `UPDATE players` |
| Dùng item | Tìm theo item id trong `Char` hoặc package `item/event` |
| Menu NPC/player actions | Nhiều logic nằm trong `Char`, `npc`, `task` |

### `com.nsoz.item`

Item runtime và template.

| Class | Vai trò |
| --- | --- |
| `Item` | Item thường trong bag/box/drop |
| `Equip` | Trang bị mặc |
| `ItemTemplate` | Template item từ DB |
| `ItemManager` | Load template, quản lý item data |
| `ItemFactory` | Tạo item theo template, item 9x, item đặc biệt |
| `Mount` | Thú cưỡi dạng item |

Sửa ở đây khi:

- Đổi cách item load option.
- Đổi rule vũ khí theo phái.
- Đổi cách nâng cấp/tinh luyện/khảm.
- Tạo item đặc biệt bằng code.

Ví dụ check vũ khí theo phái nằm trong `ItemTemplate`:

- `isKiem()`
- `isTieu()`
- `isKunai()`
- `isCung()`
- `isDao()`
- `isQuat()`
- `checkSys(int sys)`

### `com.nsoz.store`

Shop/store.

| Class | Vai trò |
| --- | --- |
| `StoreManager` | Load `store_data`, tìm shop, lấy equipment theo level/hệ/giới tính |
| `Store` | Shop cụ thể, mua bán, cộng điểm tiêu xài event |
| `ItemStore` | Item trong shop |

Sửa ở đây khi:

- Đổi shop bán gì.
- Đổi rule lấy trang bị theo level.
- Đổi logic mua bán, giảm giá, điểm tiêu xài.

DB liên quan:

- `stores`
- `store_data`
- `item`

### `com.nsoz.admin`

Lệnh admin/chat admin.

| Class | Vai trò |
| --- | --- |
| `AdminService` | Xử lý lệnh admin như `nsozxmas`, `level`, `skill`, `body` |

Các lệnh quan trọng:

```text
nsozxmas
level 69
skill 60
body lv 60 up 16 he 1 max 1 nv 1 tl 9
```

Sửa ở đây khi:

- Muốn thêm lệnh GM.
- Muốn đổi cách tạo đồ nhanh.
- Muốn tạo command set level/item/skill.

### `com.nsoz.event`

Event mùa vụ.

| Class | Vai trò |
| --- | --- |
| `Event` | Base class event kiểu mới, init theo `game.event` |
| `Halloween` | Event Halloween |
| `Noel` | Event Noel |
| `LunarNewYear` | Event Tết |
| `TrungThu` | Event Trung Thu |
| `KoroKing` | Event Koro King |
| `SumMer` | Event Summer |
| `VietnameseWomensDay` | Event 20/10 |
| `InternationalWomensDay` | Event 8/3 |
| `Ranking` | Ranking event |
| `eventpoint.EventPoint`, `Point` | Điểm event |

Sửa ở đây khi:

- Bật/tắt hoặc thêm event mới.
- Đổi item đổi thưởng event.
- Đổi thời gian kết thúc event.
- Đổi điểm event/ranking.
- Đổi menu Tiên nữ/NPC event.

Chú ý: event bật bằng class name trong `game.event`, không phải chỉ bằng database.

### `com.nsoz.mob`

Mob/quái.

| Class | Vai trò |
| --- | --- |
| `Mob` | Runtime quái, damage, drop, death hook |
| `MobManager` | Load template mob |
| `MobFactory` | Tạo mob thường |
| `WarMobFactory`, `TerritoryMobFactory` | Tạo mob cho war/territory |
| `MobTemplate` | Template quái |

Sửa ở đây khi:

- Đổi damage quái.
- Đổi drop quái.
- Đổi spawn quái/boss.
- Đổi HP theo level.

DB liên quan:

- `monster`
- `map.monster`

### `com.nsoz.map`

Map, zone, world.

| Package/Class | Vai trò |
| --- | --- |
| `MapManager` | Load map metadata |
| `Map` | Runtime map |
| `TileMap` | Tile/map info |
| `War`, `WarClan` | Chiến trường |
| `world.*` | Các world/phụ bản/territory |
| `zones.*` | Zone đặc biệt |
| `map.item.*` | Item rơi trong map |

Sửa ở đây khi:

- Đổi map, zone count, waypoint.
- Đổi logic phụ bản/chiến trường.
- Đổi item rơi trên map.
- Đổi xử lý zone đặc biệt.

DB/resource liên quan:

- `map`
- `Data/Map/*`

### `com.nsoz.network`

Giao thức client-server.

| Class | Vai trò |
| --- | --- |
| `Controller` | Dispatch message từ client |
| `Session` | Kết nối client |
| `Service` | Gửi packet/response tới client |
| `AbsService` | Base service |
| `Message` | Packet message |

Sửa ở đây khi:

- Thêm packet mới.
- Đổi protocol client-server.
- Debug client không nhận data hoặc hiển thị sai.
- Đổi cách gửi item/skill/map/player info.

### `com.nsoz.npc`

NPC.

| Class | Vai trò |
| --- | --- |
| `NpcManager` | Load NPC |
| Các class NPC | Menu/action NPC cụ thể |

Sửa ở đây khi:

- Đổi menu NPC.
- Đổi shop hoặc action khi bấm NPC.
- Thêm NPC mới.

DB liên quan:

- `npc`
- `map.npc`

### `com.nsoz.task`

Nhiệm vụ.

| Class | Vai trò |
| --- | --- |
| `Task` | Runtime task |
| `TaskTemplate` | Template task |
| `TaskFactory` | Tìm mob/item/task phù hợp |

DB liên quan:

- `task`
- `task_template`
- `players.task`
- `players.taskId`

Sửa ở đây khi:

- Đổi nhiệm vụ chính.
- Đổi yêu cầu giết quái/nhặt item.
- Đổi level yêu cầu nhiệm vụ.

### `com.nsoz.skill`

Skill runtime/paint.

| Class | Vai trò |
| --- | --- |
| `Skill` | Skill runtime |
| `SkillTemplate` | Template skill |
| `SkillPaint`, `SkillInfoPaint` | Dữ liệu animation skill |

DB liên quan:

- `skill_template`
- `skill`
- `skill_option`
- `nj_skill`

Sửa ở đây khi:

- Đổi skill template/point/option.
- Đổi animation skill gửi client.
- Đổi cách skill được biểu diễn.

### `com.nsoz.ability`

Tính chỉ số từ trang bị.

| Class | Vai trò |
| --- | --- |
| `AbilityFromEquip` | Tính ability từ trang bị đang mặc |
| `AbilityStrategy` | Interface strategy |

Sửa ở đây khi:

- Đổi cách option item cộng vào chỉ số nhân vật.
- Đổi công thức HP/MP/damage/def/resist từ equip.

### `com.nsoz.fashion`

Ngoại hình nhân vật.

| Class | Vai trò |
| --- | --- |
| `FashionFromEquip` | Set `head/body/leg/weapon` từ trang bị |
| `FashionCustom` | Ngoại hình custom |
| `FashionStrategy` | Interface strategy |

Sửa ở đây khi:

- Đồ mặc đúng nhưng ngoại hình không đúng.
- Muốn thời trang/mặt nạ đè ngoại hình theo rule riêng.
- Muốn đổi part hiển thị từ equip.

### `com.nsoz.convert`

Chuyển đổi object.

| Class | Vai trò |
| --- | --- |
| `Converter` | Convert `ItemStore` sang `Item`, clone skill, clone data |

Sửa ở đây khi:

- Item mua từ shop tạo ra option không đúng.
- Muốn đổi random/max option khi tạo item.

### `com.nsoz.clan`

Gia tộc/clan.

| Class | Vai trò |
| --- | --- |
| `Clan` | Runtime clan |
| `ClanDAO` | Load/save clan |
| `ClanService` | Gửi packet clan |
| `Member`, `MemberDAO` | Thành viên clan |

DB liên quan:

- `clan`
- `clan_member`

### `com.nsoz.party`

Tổ đội.

| Class | Vai trò |
| --- | --- |
| `GroupService` | Packet party |
| `MemberGroup` | Thành viên party |

### `com.nsoz.stall`

Shinwa/chợ.

| Class | Vai trò |
| --- | --- |
| `StallManager` | Load/save chợ |
| `StallItem` | Item bán |

DB liên quan:

- `shinwa`

Config liên quan:

- `game.shinwa.active`
- `game.shinwa.fee`
- `game.shinwa.max`
- `game.shinwa.player.max`

### `com.nsoz.thiendia`

Thiên địa/bảng liên quan PvP/event riêng.

| Class | Vai trò |
| --- | --- |
| `ThienDiaManager` | Load và quản lý dữ liệu thiên địa |
| `ThienDiaData` | Data theo level/class |

### `com.nsoz.socket`

Socket.IO.

| Class | Vai trò |
| --- | --- |
| `SocketIO` | Kết nối socket.io client/server ngoài |

Config liên quan:

- `websocket.host`
- `websocket.port`

### `com.nsoz.constants`

Hằng số.

Các file quan trọng:

| File | Vai trò |
| --- | --- |
| `ItemName` | ID item đặt tên |
| `ItemOptionName` | ID option item |
| `MobName` | ID mob |
| `NpcName` | ID NPC |
| `MapName` | ID map |
| `CMD`, `CMDInputDialog`, `CMDMenu` | Mã packet/menu |
| `SQLStatement` | Query SQL dùng lại |

Sửa ở đây khi:

- Thêm hằng số mới cho item/map/mob/NPC.
- Muốn code dễ đọc thay vì dùng số trực tiếp.

### `com.nsoz.api`

API phụ trợ.

Kiểm tra package này khi cần tích hợp web/API bên ngoài.

### `com.nsoz.lib`

Thư viện nội bộ/helper.

Ví dụ:

- Random collection.
- Profanity filter.
- Các helper collection/algorithm.

### `com.nsoz.util`

Tiện ích.

| Class | Vai trò |
| --- | --- |
| `NinjaUtils` | Helper chung: random, EXP/level, date, network, file |
| `Log` | Logging |
| `StringUtils`, `NumberUtils` | Helper parse/string |

Sửa ở đây khi:

- Đổi công thức level từ EXP.
- Đổi helper dùng chung nhiều nơi.

## 6. Dữ liệu DB và resource

### 6.1. Database seed

File:

```text
database/database.sql
```

Các bảng chính đã có tài liệu riêng trong:

```text
docs/database-guide.md
```

Tóm tắt:

| Bảng | Vai trò |
| --- | --- |
| `users` | Tài khoản |
| `players` | Nhân vật |
| `others` | EXP và part data |
| `item`, `item_option` | Template item/option |
| `store_data`, `stores` | Shop |
| `skill_template`, `skill` | Skill |
| `map`, `monster`, `npc` | Map/quái/NPC |
| `task`, `task_template` | Nhiệm vụ |
| `event_points` | Điểm event |
| `gift_codes` | Giftcode |
| `clan`, `clan_member` | Gia tộc |
| `shinwa` | Chợ |

### 6.2. `Data`

| Đường dẫn | Vai trò |
| --- | --- |
| `Data/Map/*` | File map theo ID |
| `Data/Lang/vi.properties` | Text tiếng Việt |
| `Data/Lang/en.properties` | Text tiếng Anh |
| `Data/Img` | Ảnh/resource nếu có |

Không phải mọi dữ liệu hiển thị đều nằm trong `Data`; nhiều metadata đang nằm trong DB như `nj_image`, `nj_part`, `nj_skill`, `item`.

### 6.3. Client/server-list

| Đường dẫn | Vai trò |
| --- | --- |
| `client/*.jar` | Client jar |
| `docker/server-list/NJVI.txt` | List server tiếng Việt |
| `docker/server-list/NJEN.txt` | List server tiếng Anh |

Nếu đổi IP/port server cho client, kiểm tra các file server-list.

## 7. Muốn sửa tính năng thì vào đâu?

| Mục tiêu | Nơi sửa chính | Ghi chú |
| --- | --- | --- |
| Đổi IP/port DB/server | `config.properties`, `docker-compose.yml`, `docker/server/entrypoint.sh` | Restart server |
| Đổi event đang bật | `config.properties` key `game.event` hoặc Docker `GAME_EVENT` | Restart server |
| Đổi ngày event | Class trong `com.nsoz.event` | Build/restart |
| Đổi item event/drop event | `com.nsoz.event.*`, `model/RandomItem.java`, `mob/Mob.java` | Có thể cần rebuild |
| Đổi tốc độ lên cấp | DB `others.exp` hoặc `Char.addExp(...)` | DB cần restart, code cần rebuild |
| Đổi EXP từ quái | `Char.addExp(Mob mob, int dame)` | Build/restart |
| Tạo/sửa nhân vật | DB `users`, `players` | Logout/login hoặc restart |
| Đổi skill nhân vật | DB `players.skill`, bảng `skill`, `skill_template` | Skill template cần restart |
| Đổi trang bị nhân vật | DB `players.equiped`, `item`, `item_option` | Logout/login |
| Đổi shop | DB `store_data`, code `store` nếu logic mua bán | Restart để reload store |
| Đổi chỉ số item | DB `store_data.options` hoặc `item_option`, code `ability` | Restart nếu template |
| Đổi ngoại hình đồ | DB `item.part`, `nj_part`, code `fashion` | Restart và client đúng data |
| Đổi map/waypoint | DB `map`, `Data/Map/*`, `map` package | Restart |
| Đổi quái map | DB `map.monster`, `monster`, `mob` package | Restart |
| Đổi NPC/menu | DB `npc`, code `npc`/`model.Char` | Restart/build |
| Đổi nhiệm vụ | DB `task`, `task_template`, code `task` | Restart |
| Thêm lệnh admin | `admin/AdminService.java` | Build/restart |
| Đổi packet client | `network/Controller.java`, `network/Service.java` | Phải khớp client |
| Đổi đăng nhập | `model/User.java`, `db` package | Cẩn thận mật khẩu/session |
| Đổi save/load player | `model/Char.java` | Cẩn thận JSON và cache |

## 8. Luồng thường gặp

### 8.1. Người chơi đăng nhập

1. Client kết nối `Session`.
2. `Controller` nhận message login.
3. `User` xử lý tài khoản.
4. User chọn nhân vật.
5. `Char.load()` đọc row `players`.
6. Server set `FashionFromEquip` và `AbilityFromEquip`.
7. `Char.setAbility()` tính chỉ số từ trang bị.
8. `Char.setFashion()` set ngoại hình từ equip/fashion.
9. Server đưa nhân vật vào map/zone.

Nơi hay debug:

- `network/Controller.java`
- `model/User.java`
- `model/Char.java`
- `fashion/FashionFromEquip.java`
- `ability/AbilityFromEquip.java`

### 8.2. Nhân vật đánh quái nhận EXP/drop

1. Combat xử lý trong `Char`/`Mob`.
2. Quái chết gọi logic drop trong `Mob`.
3. EXP từ damage/quái tính ở `Char.addExp(Mob mob, int dame)`.
4. EXP cộng vào `players.data.exp` trong RAM.
5. Khi save, `Char.save()` ghi lại DB.

Nơi hay sửa:

- `model/Char.java`
- `mob/Mob.java`
- `model/RandomItem.java`
- `event/*`

### 8.3. Mua item shop

1. Store load từ `store_data`.
2. `StoreManager` giữ cache.
3. Player mở NPC/shop.
4. `Store` xử lý mua.
5. `Converter` convert `ItemStore` sang `Item`.
6. Item vào bag hoặc equip theo logic.

Nơi hay sửa:

- DB `store_data`
- `store/StoreManager.java`
- `store/Store.java`
- `convert/Converter.java`

### 8.4. Event hoạt động

1. `Config` đọc `game.event`.
2. `Event.init()` tạo instance event.
3. `Server.init()` gọi `event.loadEventPoint()` và `event.initStore()`.
4. Map/zone/mob/player action gọi `Event.getEvent()`.
5. Khi player login, event point được load/tạo.

Nơi hay sửa:

- `config.properties`
- `event/Event.java`
- class event cụ thể
- `event/eventpoint/*`
- `model/RandomItem.java`
- `mob/Mob.java`

## 9. Cache và khi nào cần restart

### Sửa DB cần restart server

Restart nếu sửa:

- `others`
- `item`
- `item_option`
- `store_data`
- `stores`
- `skill_template`
- `skill`
- `skill_option`
- `nj_*`
- `map`
- `monster`
- `npc`
- `task`
- `task_template`
- `servers`

Lý do: các bảng này được load vào memory trong `Server.init()`, `GameData.init()`, `StoreManager.load()`, `ItemManager.load()`, `MapManager.load()`.

### Sửa DB không nhất thiết restart

Có thể logout/login lại nếu sửa:

- `players`
- `users`
- `gift_codes`
- Một số điểm event trong `event_points`

Nhưng nếu player đang online, server có thể save lại dữ liệu cũ đè lên DB. Với `players`, cách an toàn:

1. Cho nhân vật logout.
2. Chạy SQL update.
3. Login lại.

Nếu vẫn sai, restart server.

## 10. Quy ước JSON trong DB

Nhiều cột DB lưu JSON dưới dạng text:

- `players.data`
- `players.skill`
- `players.equiped`
- `players.fashion`
- `players.bijuu`
- `players.bag`
- `players.box`
- `map.npc`
- `map.monster`
- `map.waypoint`
- `task.subnames`
- `task.counts`
- `store_data.options`
- `skill.options`

Trước khi import SQL, đảm bảo JSON hợp lệ.

Ví dụ kiểm tra nhanh bằng Ruby:

```bash
ruby -rjson -e 'JSON.parse(ARGF.read); puts "OK"' < file.json
```

Trong SQL string, có thể thấy hai kiểu:

```sql
'{"id":1}'
'{\"id\":1}'
```

Cả hai có thể tồn tại tùy cách dump/import, nhưng khi tự viết SQL mới nên ưu tiên JSON rõ ràng, ít escape nếu không cần.

## 11. Thêm tính năng mới nên làm thế nào?

### Thêm item mới

1. Thêm template vào `item`.
2. Thêm option mô tả nếu cần vào `item_option`.
3. Nếu bán shop, thêm vào `store_data`.
4. Nếu item dùng logic đặc biệt, thêm hằng số vào `constants/ItemName.java`.
5. Thêm xử lý dùng item trong `model/Char.java` hoặc class event liên quan.
6. Restart server.
7. Kiểm tra client có icon/part/resource tương ứng chưa.

### Thêm skill mới

1. Thêm row `skill_template`.
2. Thêm các cấp point vào `skill`.
3. Thêm animation nếu cần vào `nj_skill`.
4. Kiểm tra `GameData.getSkill(classId, templateId, point)` load được.
5. Nếu skill có logic riêng, tìm chỗ xử lý skill trong `Char`/combat.
6. Restart server.

### Thêm event mới

1. Tạo class mới trong `com.nsoz.event` kế thừa `Event`.
2. Implement menu/action/drop/store/ranking nếu cần.
3. Thêm key event point trong class event.
4. Thêm random item vào `RandomItem` nếu dùng.
5. Set `game.event=com.nsoz.event.TenEventMoi`.
6. Build/restart server.

### Thêm lệnh admin mới

1. Mở `admin/AdminService.java`.
2. Thêm nhánh trong `process(Char p, String text)`.
3. Nếu cần quyền admin, kiểm tra `p.user.isAdmin()` hoặc `p.user.role`.
4. Build/restart.

## 12. Checklist trước khi sửa code

Trước khi sửa:

- Xác định sửa DB, config hay source.
- Tìm package theo bảng “Muốn sửa tính năng thì vào đâu?”.
- Kiểm tra dữ liệu có đang cache lúc `Server.init()` không.
- Backup DB nếu sửa dữ liệu live.

Sau khi sửa:

- Build lại nếu sửa Java.
- Restart server nếu sửa Java/config/cache data.
- Logout/login lại nhân vật nếu sửa `players`.
- Kiểm tra log server.
- Kiểm tra bằng SQL trực tiếp với row liên quan.

Lỗi thường gặp:

| Hiện tượng | Hướng kiểm tra |
| --- | --- |
| Sửa SQL file nhưng game không đổi | Bạn chưa chạy SQL vào DB live |
| Sửa DB live nhưng game không đổi | Player online/cache, logout hoặc restart |
| Client crash sau khi thêm item/part | Thiếu icon/part/nj_image hoặc client version không khớp |
| Skill không học được | `class`, `skill_template`, `skill.point`, level yêu cầu |
| Event không bật | `game.event`, class name sai, event đã ended |
| Shop không đổi | `store_data` đã sửa nhưng server chưa restart |
| Level không đúng | Tính sai EXP; level lấy từ tổng mảng `others.exp` |

