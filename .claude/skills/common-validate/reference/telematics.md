# Check chuẩn — dữ liệu telematics (đặc thù Telemax)

Nhóm này không có trong bộ validate web thông thường, nhưng là chỗ Telemax thật sự
vỡ, và cũng là nhóm hay bị sót nhất. Áp cho **mọi màn hình/endpoint hiển thị dữ
liệu đến từ thiết bị**.

## Mục lục
- Độ tươi của dữ liệu
- Timezone
- Đơn vị đo & chuyển đổi
- Toạ độ & bản đồ
- Realtime & kết nối

---

## Độ tươi của dữ liệu

Thiết bị chưa từng gửi tin (chưa có bản ghi nào) · thiết bị offline lâu (hiển thị
"last seen" thay vì số cũ như thể đang sống) · dữ liệu đến muộn hoặc ra khỏi thứ tự
(timestamp cũ hơn bản ghi mới nhất) · trùng bản ghi cùng timestamp.

## Timezone

Giờ thiết bị vs giờ server vs giờ người xem · mốc nửa đêm (bản ghi 23:59 và 00:01
rơi đúng ngày nào trên báo cáo) · đổi giờ mùa (DST) ở fleet đa vùng · lưu UTC hiển
thị local, không lệch một ngày.

## Đơn vị đo & chuyển đổi

km ↔ mile, L/100km ↔ mpg, °C ↔ °F · odometer nhảy lùi (thay thiết bị / reset ECU) ·
odometer nhảy vọt phi lý (lọc outlier) · giá trị 0 vs null vs "chưa có" hiển thị
khác nhau · làm tròn khi cộng dồn quãng đường.

## Toạ độ & bản đồ

lat/lng biên (±90 / ±180) · toạ độ 0,0 (null island — phải coi là không có fix) ·
GPS drift khi xe đứng yên · thiết bị ngoài vùng phủ bản đồ · geofence: vào/ra/nằm
đúng trên biên · khoảng cách tính qua đường đổi ngày (±180°).

## Realtime & kết nối

Mất kết nối rồi reconnect (không mất tin, không nhân đôi tin) · backlog sau khi
thiết bị online lại · nhiều tab cùng mở một màn hình realtime · dữ liệu đang stream
thì người dùng đổi filter.
