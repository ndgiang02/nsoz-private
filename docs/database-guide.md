# Tài liệu cơ sở dữ liệu Nsoz

Tài liệu này mô tả cách đọc và chỉnh cơ sở dữ liệu trong `database/database.sql`, cách cấu hình sự kiện, chỉnh tốc độ lên cấp, và tự tạo hoặc chỉnh nhân vật theo ý muốn.

Các ghi chú bên dưới được đối chiếu với source hiện tại:

- `src/main/java/com/nsoz/server/Config.java`
- `src/main/java/com/nsoz/server/Server.java`
- `src/main/java/com/nsoz/util/NinjaUtils.java`
- `src/main/java/com/nsoz/model/Char.java`
- `src/main/java/com/nsoz/model/User.java`
- `src/main/java/com/nsoz/admin/AdminService.java`
- `src/main/java/com/nsoz/store/StoreManager.java`
- `src/main/java/com/nsoz/event/Event.java`

## 1. Lưu ý quan trọng trước khi sửa DB

`database/database.sql` chỉ là file seed/import ban đầu. Nếu server đã import DB trước khi bạn sửa file này, thay đổi trong file SQL sẽ không tự chạy vào database đang hoạt động.

Khi bạn thấy trong file đã đúng nhưng trong game vẫn sai, thường là do một trong các lý do sau:

- Database live đã import bản cũ.
- Nhân vật đang online, server đang giữ dữ liệu trong RAM.
- Sau khi sửa trực tiếp DB, chưa logout/login lại nhân vật hoặc chưa restart server.
- Có đồ thời trang trong cột `fashion` hoặc mặt nạ trong `mask_box` đang đè ngoại hình trang bị.

Cách kiểm tra DB live nhanh:

```sql
SELECT
  id, user_id, name, gender, class,
  JSON_EXTRACT(data, '$.exp') AS exp,
  head, head2, weapon, body, leg,
  skill,
  equiped,
  fashion
FROM players
WHERE name = 'giang';
```

Nếu dùng Docker Compose trong repo này:

```bash
docker compose exec db mariadb -unsoz -pnsoz_password nsoz2
```

Chạy file SQL vào DB live:

```bash
docker compose exec -T db mariadb -unsoz -pnsoz_password nsoz2 < database/update_giang_level69_tieu.sql
```

Sau khi update nhân vật đang online, nên cho nhân vật logout/login lại. Nếu vẫn chưa đổi, restart server để xóa cache nhân vật.

## 2. Các bảng chính

### `users`

Bảng tài khoản đăng nhập.

Cột thường dùng:

| Cột | Ý nghĩa |
| --- | --- |
| `id` | ID tài khoản, được `players.user_id` tham chiếu |
| `username` | Tên đăng nhập |
| `password` | Mật khẩu đăng nhập |
| `activated` | Kích hoạt tài khoản, thường để `1` |
| `status` | Trạng thái tài khoản, thường để `1` |
| `role` | Quyền đặc biệt; source dùng `role == 9999` để mở UI admin/chat admin |
| `luong` | Lượng tài khoản |
| `balance`, `vnd`, `tongnap` | Thông tin nạp/web |
| `kh` | Trạng thái kích hoạt theo logic web/server, thường để `1` |

Trong source hiện tại, đăng nhập so sánh mật khẩu dạng text thường. Đoạn bcrypt đang bị comment, vì vậy seed đang dùng mật khẩu plain text như `giang123`.

Ví dụ tạo tài khoản:

```sql
INSERT INTO users
  (id, username, password, status, activated, balance, luong, online, role, group_id, ip_address, level_reward, created_at, kh)
VALUES
  (2, 'giang', 'giang123', 1, 1, 0, 999999, 0, 9999, 1, '["127.0.0.1"]', '[0,0,0,0,0]', NOW(), 1);
```

### `players`

Bảng nhân vật ingame.

Cột thường dùng:

| Cột | Ý nghĩa |
| --- | --- |
| `id` | ID nhân vật |
| `user_id` | ID tài khoản trong `users` |
| `server_id` | ID server, khớp `config.properties` key `server.id` |
| `name` | Tên nhân vật |
| `gender` | `0` nữ, `1` nam |
| `class` | Phái nhân vật |
| `data` | JSON chứa EXP, giới hạn ngày, trạng thái phụ |
| `point` | Điểm tiềm năng đã cộng |
| `potential` | JSON array 4 chỉ số tiềm năng |
| `spoint` | Điểm kỹ năng còn lại |
| `skill` | JSON skill đã học |
| `equiped` | JSON trang bị đang mặc |
| `fashion` | JSON thời trang đang mặc, có thể đè ngoại hình |
| `bijuu` | JSON vĩ thú/pet đặc biệt |
| `map`, `saveCoordinate` | Map và tọa độ lưu |
| `head`, `head2`, `weapon`, `body`, `leg` | Part ngoại hình hiển thị |
| `xu`, `xuInBox`, `yen` | Tiền nhân vật |
| `bag`, `box` | JSON hành trang/rương |
| `onCSkill`, `onOSkill`, `onKSkill` | Phím tắt skill |
| `taskId`, `task` | Nhiệm vụ |
| `event_point`, `spending_point` | Điểm event kiểu cũ |
| `activated` | Nhân vật hoạt động |

Level không có cột riêng. Level được tính từ `players.data.exp`.

### `others`

Bảng cấu hình JSON hệ thống. Các row quan trọng:

| `name` | Ý nghĩa |
| --- | --- |
| `exp` | Mảng EXP từng cấp, dùng để tính level |
| `head_normal`, `head_jump`, `head_boc_dau` | Dữ liệu part đầu |
| `body_normal`, `body_jump`, `body_boc_dau` | Dữ liệu part thân |
| `leg` | Dữ liệu part chân |

`Server.java` load toàn bộ bảng `others` khi server khởi động. Nếu sửa `others`, restart server để nhận cấu hình mới.

### `item`

Bảng template item.

Cột thường dùng:

| Cột | Ý nghĩa |
| --- | --- |
| `id` | ID item template |
| `name` | Tên item |
| `type` | Loại item |
| `gender` | `0` nữ, `1` nam, `2` dùng chung |
| `level` | Level yêu cầu hoặc level item |
| `icon` | Icon client |
| `part` | Part ngoại hình khi mặc/cầm |
| `fashion` | Nhóm thời trang |
| `isUpToUp` | Có liên quan nâng cấp/stack theo logic item |

Một số `type` trang bị hay dùng:

| Type | Nghĩa |
| --- | --- |
| `0` | Nón/tóc |
| `1` | Vũ khí |
| `2` | Áo |
| `3` | Dây chuyền |
| `4` | Găng |
| `5` | Nhẫn |
| `6` | Quần |
| `7` | Ngọc bội |
| `8` | Giày |
| `9` | Bùa |
| `10` | Thú cưỡi/vĩ thú tùy item |
| `11` | Mặt nạ |
| `27` | Sách/vật phẩm đặc biệt |

### `item_option`

Bảng mô tả option item. Cột `id` là mã option trong JSON item.

Option quan trọng khi tinh luyện:

| Option | Ý nghĩa |
| --- | --- |
| `85` | Độ tinh luyện: `param` là cấp tinh luyện |

Ví dụ tinh luyện 9:

```json
["options": [[85,9]]]
```

Trong item JSON thật, option là array dạng:

```json
{"options":[[47,12],[6,60],[85,9]]}
```

### `store_data`

Bảng item bán trong shop hoặc nguồn mẫu để tạo trang bị.

Cột thường dùng:

| Cột | Ý nghĩa |
| --- | --- |
| `item_id` | ID template trong bảng `item` |
| `sys` | Hệ item |
| `store` | Loại shop |
| `coin`, `gold`, `yen` | Giá |
| `expire` | Hạn dùng, `-1` là vĩnh viễn |
| `options` | JSON option gốc dạng object `{id,param}` |

`AdminService.addEquipment` dùng `StoreManager.getEquipment(level, sys, gender)` để lấy item theo level, hệ, giới tính rồi convert thành item thật.

### `skill_template` và `skill`

`skill_template` là template chiêu theo class. `skill` là từng cấp point của chiêu đó.

Trong `players.skill`, mỗi phần tử lưu:

```json
{"id":10,"point":12}
```

Trong đó:

- `id` là `skill_template.id`
- `point` là cấp skill trong bảng `skill.point`

Khi load nhân vật, source gọi:

```java
GameData.getSkill(this.classId, skillId, point)
```

Nếu `class` không khớp `skill_template.class`, skill có thể không load.

### `event_points`

Bảng điểm sự kiện kiểu mới.

Cột thường dùng:

| Cột | Ý nghĩa |
| --- | --- |
| `server_id` | Server |
| `event_id` | ID sự kiện |
| `player_id` | ID nhân vật |
| `point` | JSON array các điểm event |

Khi event bật, `Char.loadEventPoint()` sẽ tạo row nếu nhân vật chưa có.

### `gift_codes`

Bảng giftcode.

Cột thường dùng:

| Cột | Ý nghĩa |
| --- | --- |
| `server_id` | Server áp dụng |
| `type` | Kiểu giftcode theo logic xử lý |
| `code` | Mã gift |
| `coin`, `gold`, `yen` | Phần thưởng tiền |
| `items` | JSON item thưởng |
| `status` | Trạng thái |
| `expires_at` | Hết hạn |
| `used` | Số lượt đã dùng hoặc JSON lịch sử tùy logic |

## 3. Class/phái nhân vật

Bảng `clazz` hiện có:

| Class | Phái |
| --- | --- |
| `1` | Ninja kiếm |
| `2` | Ninja phi tiêu |
| `3` | Ninja kunai |
| `4` | Ninja cung |
| `5` | Ninja đao |
| `6` | Ninja quạt |

`class = 0` thường là nhân vật chưa nhập phái.

## 4. Cấu hình sự kiện

### 4.1. Cấu hình event đang chạy

Event chính được bật bằng `config.properties`:

```properties
game.event=com.nsoz.event.Halloween
```

`Config.java` đọc key `game.event`, sau đó `Event.init()` tạo instance bằng reflection:

```java
instance = (Event) Class.forName(Config.getInstance().getEvent()).newInstance();
```

Các class event hiện có:

| Class cấu hình | Ghi chú |
| --- | --- |
| `com.nsoz.event.Halloween` | Halloween |
| `com.nsoz.event.Noel` | Noel |
| `com.nsoz.event.LunarNewYear` | Tết |
| `com.nsoz.event.TrungThu` | Trung Thu |
| `com.nsoz.event.KoroKing` | Koro King |
| `com.nsoz.event.SumMer` | Summer |
| `com.nsoz.event.VietnameseWomensDay` | 20/10 |
| `com.nsoz.event.InternationalWomensDay` | 8/3 |

Tắt event:

```properties
# Xóa hẳn key game.event hoặc để rỗng nếu code deploy của bạn xử lý rỗng an toàn.
# Khuyến nghị: comment dòng này và restart server.
# game.event=com.nsoz.event.Halloween
```

Nếu dùng Docker, `docker/server/entrypoint.sh` tạo config từ biến môi trường:

```properties
game.event=${GAME_EVENT:-com.nsoz.event.Halloween}
```

Vì vậy nếu không truyền `GAME_EVENT`, Docker mặc định bật Halloween.

Ví dụ đổi Docker sang Noel:

```yaml
services:
  server:
    environment:
      GAME_EVENT: com.nsoz.event.Noel
```

Sau khi đổi event, restart service server:

```bash
docker compose restart server
```

### 4.2. Thời gian kết thúc event

Nhiều event có `startTime`/`endTime` nằm trong class Java event, không nằm trong database. Ví dụ các file:

- `src/main/java/com/nsoz/event/Halloween.java`
- `src/main/java/com/nsoz/event/Noel.java`
- `src/main/java/com/nsoz/event/LunarNewYear.java`
- `src/main/java/com/nsoz/event/TrungThu.java`

Muốn đổi ngày kết thúc thật sự, mở class event tương ứng, tìm `endTime.set(...)` hoặc logic `isEnded()`, sửa code rồi build/restart server.

### 4.3. Điểm event

Source mới dùng `event_points`. Mỗi event tự định nghĩa các key điểm, ví dụ:

```java
public static final String DIEM_TIEU_XAI = "spending_point";
```

Khi player login trong lúc event bật:

- Server tìm `event_points` theo `event_id` và `player_id`.
- Nếu chưa có, server tạo row mới.
- Nếu event có key mới, `addIfMissing` thêm key còn thiếu.

Ví dụ reset điểm event cho một nhân vật:

```sql
DELETE FROM event_points
WHERE player_id = 2
  AND event_id = 4;
```

Ví dụ xóa toàn bộ điểm của một event để chạy mùa mới:

```sql
DELETE FROM event_points
WHERE event_id = 4;
```

Chỉ chạy khi bạn chắc chắn muốn reset ranking event.

### 4.4. Drop item event

Quái chết có gọi:

```java
Event.getEvent().randomItemID()
```

Drop item event nằm trong code event và `RandomItem`, không nằm hoàn toàn trong DB. Muốn đổi tỉ lệ/item event rơi ra, kiểm tra:

- `src/main/java/com/nsoz/model/RandomItem.java`
- Class event đang bật, ví dụ `Halloween.java`, `Noel.java`
- `src/main/java/com/nsoz/mob/Mob.java`

## 5. Tốc độ tăng EXP và level

### 5.1. Level được tính như thế nào

Nhân vật không lưu level trong cột riêng. Server load EXP từ:

```sql
players.data -> $.exp
```

Mảng EXP từng cấp nằm ở:

```sql
SELECT value
FROM others
WHERE name = 'exp';
```

Source tính level trong `NinjaUtils.getLevel(long num)` theo kiểu trừ dần:

```java
for (int i = 0; i < Server.exps.length; i++) {
    if (num < Server.exps[i]) {
        return i;
    }
    num -= Server.exps[i];
}
```

Nghĩa là:

- `others.exp[0]` là EXP cần từ level 0 lên 1 theo cách index của server.
- EXP tối thiểu để đạt level `L` là tổng các phần tử `others.exp[0]` đến `others.exp[L-1]`.
- Muốn set level 69, dùng tổng `exp[0...69]`.

Với database hiện tại:

| Level | EXP tối thiểu |
| --- | --- |
| `69` | `45645593313` |
| `70` | `52676205701` |

Ví dụ set nhân vật `giang` về level 69:

```sql
UPDATE players
SET data = JSON_SET(data, '$.exp', 45645593313)
WHERE name = 'giang';
```

Nếu MySQL/MariaDB không xử lý JSON do cột là text hoặc dữ liệu escape cũ, bạn có thể replace toàn bộ `data` bằng JSON string hợp lệ.

### 5.2. Chỉnh nhanh/chậm lên cấp

Có 2 cách chỉnh:

1. Chỉnh mốc EXP cần để lên cấp trong `others.name='exp'`.
2. Chỉnh lượng EXP nhận được từ quái/vật phẩm trong code.

Chỉnh mốc EXP trong DB là cách dễ nhất:

- Muốn lên cấp chậm hơn: tăng các số trong mảng `others.exp`.
- Muốn lên cấp nhanh hơn: giảm các số trong mảng `others.exp`.
- Sửa xong phải restart server vì `Server.java` load `others.exp` lúc khởi động.

Ví dụ xem mảng EXP:

```sql
SELECT value
FROM others
WHERE name = 'exp';
```

Ví dụ cập nhật toàn bộ mảng:

```sql
UPDATE others
SET value = '[200,500,1000,2000]'
WHERE name = 'exp';
```

Không nên dùng ví dụ trên trực tiếp cho server thật vì nó chỉ có 4 mốc. Mảng phải đủ dài cho level tối đa bạn muốn server hỗ trợ.

### 5.3. EXP từ quái

EXP khi đánh quái nằm ở `Char.addExp(Mob mob, int dame)`:

```java
int dLevel = Math.abs(mob.level - this.level);
if (mob.template.id != MobName.BU_NHIN && (dLevel <= 10)) {
    int a = this.level / 20;
    a = a == 0 ? 1 : a;
    int b = dame * a;
    int c = (mob.level - this.level) * a;
    exp = (b / 2) + (b * c / 100);
    ...
}
```

Các hệ số tăng thêm:

- Boss thường nhân `6`.
- Quái tinh anh cấp `levelBoss == 1` nhân `2`.
- Quái thủ lĩnh cấp `levelBoss == 2` nhân `5`.
- Phụ bản nhân `2`.
- Các option `100`, `169`, support skill `29`, hiệu ứng EXP cộng thêm theo phần trăm.
- `incrExp` nhân trực tiếp nếu đang có hiệu ứng tăng EXP.

Nếu muốn server x2/x5 EXP toàn cục từ quái, cách sạch là thêm hệ số trong `Char.addExp(Mob mob, int dame)` sau khi tính `exp`:

```java
exp *= 2; // x2 EXP toàn server
```

Nếu chỉ muốn chỉnh tốc độ lên cấp mà không rebuild code, chỉnh `others.exp`.

## 6. Tạo và tùy chỉnh nhân vật

### 6.1. Quy trình tạo nhân vật thủ công

Một nhân vật cần tối thiểu:

1. Row trong `users`.
2. Row trong `players` với `user_id` trỏ tới `users.id`.
3. `players.data.exp` đúng level mong muốn.
4. `players.class` đúng phái.
5. `players.skill` đúng skill của phái.
6. `players.equiped` là JSON item hợp lệ.
7. `head/head2/weapon/body/leg` đúng part ngoại hình.
8. `AUTO_INCREMENT` của `users` và `players` lớn hơn ID bạn vừa thêm.

Ví dụ sửa AUTO_INCREMENT:

```sql
ALTER TABLE users AUTO_INCREMENT = 3;
ALTER TABLE players AUTO_INCREMENT = 3;
```

### 6.2. Các trường JSON hay dùng trong `players.data`

Ví dụ data tối giản:

```json
{
  "limitKyNangSo": 0,
  "countPB": 1,
  "countLoosBoss": 2,
  "countFinishDay": 20,
  "hieuChien": 0,
  "expDown": 0,
  "exp": 45645593313,
  "limitTiemNangSo": 0,
  "limitBangHoa": 0,
  "limitPhongLoi": 0,
  "tayTiemNang": 0,
  "tayKyNang": 0,
  "levelUpTime": 1781139600000,
  "coinMax": 2000000000
}
```

Ý nghĩa:

| Key | Ý nghĩa |
| --- | --- |
| `exp` | EXP hiện tại, quyết định level |
| `expDown` | EXP âm do chết/mất EXP |
| `hieuChien` | Điểm hiếu chiến |
| `countPB` | Lượt phụ bản |
| `countFinishDay` | Lượt nhiệm vụ hằng ngày |
| `tayTiemNang` | Trạng thái/lượt tẩy tiềm năng |
| `tayKyNang` | Trạng thái/lượt tẩy kỹ năng |
| `coinMax` | Giới hạn xu |
| `levelUpTime` | Thời điểm lên level gần nhất, milliseconds |

### 6.3. Tiềm năng

`potential` là array 4 số:

```json
[3015,3005,3005,3005]
```

Thứ tự chính xác phụ thuộc client/game logic, nhưng thường là 4 chỉ số cơ bản. `point` là tổng điểm đã cộng hoặc điểm đang dùng theo source hiện tại.

Ví dụ set tiềm năng mạnh:

```sql
UPDATE players
SET point = 2600,
    potential = '[3015,3005,3005,3005]'
WHERE name = 'giang';
```

### 6.4. Skill

Skill phải khớp class.

Ví dụ phái Tiêu class `2`, level 69:

```json
[
  {"id":10,"point":12},
  {"id":11,"point":6},
  {"id":12,"point":12},
  {"id":13,"point":6},
  {"id":14,"point":12},
  {"id":15,"point":6},
  {"id":16,"point":12},
  {"id":17,"point":6},
  {"id":18,"point":12},
  {"id":56,"point":10}
]
```

Phái Tiêu level 69 chưa nên dùng skill level 70. Skill 6x là `skill_template.id = 56` (`Totogai`), point phù hợp level 69 là `10`.

Muốn tra skill theo phái:

```sql
SELECT id, class, name, max_point
FROM skill_template
WHERE class = 2
ORDER BY id;
```

Muốn tra cấp point của một skill:

```sql
SELECT template_id, level, point, mana_use, cooldown, options
FROM skill
WHERE template_id = 56
ORDER BY point;
```

### 6.5. Trang bị đang mặc

`players.equiped` là JSON array item. Mỗi item thường có dạng:

```json
{
  "new": true,
  "yen": 60000,
  "updated_at": 1781139600000,
  "upgrade": 16,
  "gems": [],
  "expire": -1,
  "options": [[47,12],[6,60],[85,9]],
  "created_at": 1781139600000,
  "id": 317,
  "sys": 1
}
```

Trường quan trọng:

| Field | Ý nghĩa |
| --- | --- |
| `id` | ID item trong bảng `item` |
| `sys` | Hệ item |
| `upgrade` | Cấp nâng cấp, ví dụ `16` |
| `options` | Chỉ số item |
| `expire` | `-1` là vĩnh viễn |
| `gems` | Ngọc khảm |
| `yen` | Giá trị item |

Tinh luyện 9:

```json
[85,9]
```

Nếu muốn item +16 tinh luyện 9, cần:

```json
"upgrade": 16,
"options": [...,[85,9]]
```

### 6.6. Ngoại hình trang bị

Server set ngoại hình từ trang bị qua `FashionFromEquip` khi player login:

- Vũ khí type `1` dùng `item.part` vào `players.weapon`.
- Áo type `2` dùng `item.part` vào `players.body`.
- Quần type `6` dùng `item.part` vào `players.leg`.
- Mặt nạ type `11` dùng `item.part` vào `players.head`.

Vì vậy nếu item đúng nhưng ngoài game vẫn sai, kiểm tra:

```sql
SELECT name, head, head2, weapon, body, leg, equiped, fashion, mask_box
FROM players
WHERE name = 'ten_nhan_vat';
```

Nếu muốn tắt thời trang đè trang bị:

```sql
UPDATE players
SET fashion = '[]',
    mask_box = '[]',
    head2 = -1
WHERE name = 'ten_nhan_vat';
```

## 7. Ví dụ: nhân vật `giang` level 69 phái Tiêu

Tài khoản:

| Field | Giá trị |
| --- | --- |
| Username | `giang` |
| Password | `giang123` |
| Ingame | `giang` |
| Class | `2` - Ninja phi tiêu |
| Level | `69` |

Trang bị 6x tương ứng:

| Item ID | Tên | Ghi chú |
| --- | --- | --- |
| `317` | Huyền Thiết Ngoa | Giày nam level 61 |
| `318` | Bùa Huyền Kỹ | Bùa level 62 |
| `319` | Huyền Thiết Hạ Giáp | Quần nam level 63, part `30` |
| `320` | Huyền Kỹ Bội | Ngọc bội level 64 |
| `321` | Huyền Thiết Thủ | Găng nam level 65 |
| `322` | Nhẫn Huyền Kỹ | Nhẫn level 66 |
| `323` | Huyền Thiết Thượng Giáp | Áo nam level 67, part `29` |
| `324` | Dây Chuyền Huyền Kỹ | Dây chuyền level 68 |
| `325` | Huyền Thiết Tuyến | Nón nam level 69 |
| `332` | Thái dương tiêu | Vũ khí phi tiêu level 60, part `15` |

Skill phái Tiêu level 69:

```json
[
  {"id":10,"point":12},
  {"id":11,"point":6},
  {"id":12,"point":12},
  {"id":13,"point":6},
  {"id":14,"point":12},
  {"id":15,"point":6},
  {"id":16,"point":12},
  {"id":17,"point":6},
  {"id":18,"point":12},
  {"id":56,"point":10}
]
```

Nếu database live đã có `giang` bản cũ, chạy file:

```bash
docker compose exec -T db mariadb -unsoz -pnsoz_password nsoz2 < database/update_giang_level69_tieu.sql
```

Hoặc trong SQL client:

```sql
SOURCE database/update_giang_level69_tieu.sql;
```

## 8. Dùng admin mode để tạo đồ/level trong game

Nếu tài khoản có `users.role = 9999`, chat:

```text
nsozxmas
```

để bật chế độ sáng tạo.

Lệnh set level:

```text
level 69
```

Lệnh học skill theo level yêu cầu:

```text
skill 60
```

Lệnh tạo trang bị:

```text
body lv 60 up 16 he 1 max 1 nv 1 tl 9
```

Ý nghĩa:

| Tham số | Ý nghĩa |
| --- | --- |
| `lv` | Level item cần tạo |
| `up` | Cấp nâng cấp |
| `he` | Hệ item, thường `1..3` với trang bị thường |
| `max` | `1` lấy option max, `0` random |
| `nv` | Giới tính: `0` nữ, `1` nam |
| `tl` | Tinh luyện, `0..9` |

Lưu ý:

- Với item level chia hết cho 10, ví dụ `60`, code dùng `classId` để lấy đúng vũ khí theo phái.
- Với item level 90-99, code dùng nhánh item 9x riêng.
- Lệnh `body` thêm item vào hành trang, không nhất thiết tự mặc ngay.

## 9. Tùy chỉnh item/shop

### 9.1. Thêm item vào shop

Item shop nằm ở `store_data`.

Ví dụ thêm item template `332` vào shop type `2`:

```sql
INSERT INTO store_data
  (item_id, sys, store, `lock`, coin, gold, yen, expire, options)
VALUES
  (332, 1, 2, 0, 1200000, 0, 0, -1,
   '[{"param":200,"id":0},{"param":200,"id":1},{"param":60,"id":9}]');
```

Sau khi sửa `store_data`, restart server để `StoreManager` load lại.

### 9.2. Tìm đồ theo level/phái

Tìm item level 60-69:

```sql
SELECT id, name, type, gender, level, part
FROM item
WHERE level BETWEEN 60 AND 69
ORDER BY level, type, id;
```

Tìm item có chữ `Thái dương`:

```sql
SELECT id, name, type, gender, level, part
FROM item
WHERE name LIKE '%Thái dương%';
```

Tìm store option của item:

```sql
SELECT id, item_id, sys, store, yen, options
FROM store_data
WHERE item_id = 332;
```

## 10. Giftcode cơ bản

Ví dụ giftcode thưởng lượng/xu/yên và item:

```sql
INSERT INTO gift_codes
  (server_id, type, code, coin, gold, yen, items, status, expires_at, created_at, updated_at, used)
VALUES
  (1, 0, 'TESTGIANG', 1000000, 1000, 1000000,
   '[{"id":332,"quantity":1,"expire":-1}]',
   1, '2026-12-31 23:59:59', NOW(), NOW(), '[]');
```

Tùy logic xử lý giftcode trong source/web, format `items` có thể cần đầy đủ option item. Nếu giftcode không phát item như mong muốn, kiểm tra code xử lý giftcode trước khi chỉnh tiếp.

## 11. Công thức kiểm tra nhanh sau khi sửa nhân vật

Kiểm tra level, class, ngoại hình:

```sql
SELECT
  p.name,
  p.class,
  JSON_EXTRACT(p.data, '$.exp') AS exp,
  p.head,
  p.head2,
  p.weapon,
  p.body,
  p.leg,
  p.skill,
  p.equiped
FROM players p
WHERE p.name = 'giang';
```

Kiểm tra có đang mặc đồ 9x không:

```sql
SELECT name
FROM players
WHERE name = 'giang'
  AND (
    equiped LIKE '%"id":618%'
    OR equiped LIKE '%"id":620%'
    OR equiped LIKE '%"id":633%'
  );
```

Nếu query trên trả về row, nhân vật vẫn còn đồ 9x.

Kiểm tra đã có bộ 6x phái Tiêu:

```sql
SELECT name
FROM players
WHERE name = 'giang'
  AND equiped LIKE '%"id":317%'
  AND equiped LIKE '%"id":318%'
  AND equiped LIKE '%"id":319%'
  AND equiped LIKE '%"id":320%'
  AND equiped LIKE '%"id":321%'
  AND equiped LIKE '%"id":322%'
  AND equiped LIKE '%"id":323%'
  AND equiped LIKE '%"id":324%'
  AND equiped LIKE '%"id":325%'
  AND equiped LIKE '%"id":332%';
```

## 12. Checklist khi chỉnh database

Trước khi sửa:

- Backup database live.
- Kiểm tra nhân vật có online không.
- Xác định sửa seed `database.sql` hay sửa DB live.

Sau khi sửa:

- Nếu sửa `database.sql`, import lại hoặc chạy script update vào DB live.
- Nếu sửa `others`, `item`, `store_data`, `skill`, restart server.
- Nếu sửa `players` khi nhân vật online, logout/login lại hoặc restart server.
- Kiểm tra `fashion`, `mask_box`, `head2` nếu ngoại hình không đúng.
- Kiểm tra JSON hợp lệ trước khi import.

Các lỗi thường gặp:

| Lỗi | Nguyên nhân |
| --- | --- |
| File SQL đúng nhưng game sai | DB live chưa update hoặc server cache |
| Skill không hiện | `players.class` không khớp `skill_template.class` |
| Đồ mặc đúng nhưng ngoại hình sai | `head/body/leg` cũ, `fashion` hoặc mặt nạ đang đè |
| Level sai | Tính EXP theo mốc tích lũy sai; phải dùng tổng mảng `others.exp` |
| Item không load | JSON `equiped` sai format hoặc `item.id` không tồn tại |
| Tinh luyện không hiện | Thiếu option `[85,n]` trong `options` |

