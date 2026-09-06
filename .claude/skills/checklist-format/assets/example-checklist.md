# Ví dụ checklist (rút gọn) — TLM-2899 · Vehicle Detail Page

Bản rút gọn để thấy *hình dạng*: đánh số liên tục, nhãn nguồn ở mọi dòng, bảng D
gom toàn tính năng. Checklist thật dài hơn nhiều vì C phải phủ đủ hành vi.

---

## A. Nguồn đã đọc

- Ticket ClickUp `TLM-2899`: mở được, đọc mô tả + 7 AC + 4 comment.
- Figma: đã xem frame `Vehicle Detail / Default`, `Vehicle Detail / No data`.
  Frame `Vehicle Detail / Mobile` có link nhưng không mở được.
- Code hiện tại: `VehiclesController.cs`, `VehicleDetailMapper.cs`.
- Git diff: có (nhánh `feature/TLM-2899-vehicle-detail`).
- **Không đọc được:** frame Mobile → phần responsive ghi `[Cần hỏi]`.

## B. Overview

Trang chi tiết xe mở từ danh sách Devices, hiển thị thông tin xe, trạng thái thiết
bị và vị trí cuối cùng. Dành cho Fleet Manager và Viewer. Kết quả: người dùng xem
được tình trạng một xe mà không phải rời khỏi dashboard.

## C. Detail từng phần

### C1. Điều hướng & tải trang
1. `[AC-01]` Bấm một dòng trong danh sách Devices thì mở trang chi tiết của đúng xe đó.
2. `[AC-01]` Tải lại trang (F5) vẫn ở đúng trang chi tiết xe đó.
3. `[Suy luận]` Mở trang của một xe không tồn tại → hiện thông báo không tìm thấy, không để trắng trang.

### C2. Khối thông tin xe
4. `[AC-02]` Tiêu đề hiển thị tên xe. Không có tên → hiển thị biển số.
5. `[Figma]` Field thiếu dữ liệu hiển thị `—`, không để trống.
6. `[Cần hỏi]` Hành vi ở màn hình hẹp (chưa xem được frame Mobile).

### C3. Khối trạng thái thiết bị
7. `[AC-04]` Thiết bị offline > 24h hiển thị "Last seen <thời điểm>".
8. `[Suy luận]` Thiết bị chưa từng gửi tin → hiển thị "No data yet".

## D. Các bảng tổng hợp

**D1. Bảng field**

| # | Thuộc phần | Tên field | Kiểu | Bắt buộc | Ràng buộc | Nguồn |
|---|---|---|---|---|---|---|
| 9 | C2 | Vehicle Name | text | có | maxlength 100 | `[AC-02]` |
| 10 | C2 | Odometer | number | không | ≥ 0, 1 chữ số thập phân | `[AC-05]` |

**D2. Danh sách message**

| # | Thuộc phần | Tình huống | Nội dung message | Nguồn |
|---|---|---|---|---|
| 11 | C2 | Bỏ trống tên xe khi lưu | "Vehicle name is required." | `[Figma]` |
| 12 | C3 | Thiết bị chưa gửi tin | "No data yet" | `[AC-04]` |

**D3. Business rule**

| # | Thuộc phần | Diễn giải | Nguồn |
|---|---|---|---|
| 13 | C3 | Ngưỡng "offline" tính từ lần nhận tin cuối, mốc 24 giờ | `[AC-04]` |

**D4. Out of scope**

| # | Hạng mục | Lý do | Nguồn |
|---|---|---|---|
| 14 | Sửa thông tin xe | Ticket chỉ làm phần xem | `[AC-01]` |

**D5. Mâu thuẫn trong spec**

| # | Nội dung | Chỗ A | Chỗ B | Tạm theo |
|---|---|---|---|---|
| 15 | Đơn vị odometer | AC-05 ghi km | Figma frame Default ghi "mi" | km (theo AC) |

## E. Bảng có điều kiện

**Role × quyền** (có 2 vai trò)

| # | Vai trò | Xem được gì | Làm được gì | Nguồn |
|---|---|---|---|---|
| 16 | Fleet Manager | toàn bộ khối | mở trang | `[AC-06]` |
| 17 | Viewer | ẩn khối chi phí | mở trang | `[AC-06]` |

## E2. Bảng AC

| Mã AC | Nội dung | Thuộc phần | Nguồn |
|---|---|---|---|
| AC-01 | Mở trang chi tiết từ danh sách Devices | C1 | mục "Yêu cầu" gạch đầu dòng 1 |
| AC-02 | Tiêu đề hiển thị tên xe | C2 | mục "Yêu cầu" gạch đầu dòng 2 |
| AC-04 | Trạng thái offline hiển thị last seen | C3 | mục "Yêu cầu" gạch đầu dòng 4 |

## F. Giả định & câu hỏi cho BA/Dev

| # | Spec chưa nói | Giả định tạm dùng | Đề xuất (lý do) | Độ tự tin | Câu hỏi cho khách |
|---|---|---|---|---|---|
| 18 | maxlength tên xe | 100 | Theo ràng buộc cột DB hiện tại | Cao | (dùng luôn được) |
| 19 | Viewer có thấy odometer? | có | Không phải data nhạy cảm | Vừa | Viewer có được xem odometer không? |
| 20 | Ngưỡng offline có cấu hình theo khách? | cố định 24h | Nghiệp vụ riêng, không suy đoán được | Thấp | Ngưỡng offline cố định hay theo hợp đồng từng khách? |

## G. Impact / vùng ảnh hưởng từ code

| # | Vùng bị đụng | Vì sao | Rủi ro hồi quy | Nguồn |
|---|---|---|---|---|
| 21 | Hiển thị số km (`VehicleDetailMapper`) | Thay đổi cách tính số km hiển thị | Báo cáo quãng đường dùng chung phần này — cần test lại | diff |

## H. Kế hoạch test

*(ticket này ước lượng ≤15 case nên bỏ mục H)*

---
## Phản hồi review
<!-- Viết phản hồi vào đây. VD:
  #4 sai — maxlength thật là 100, không phải 255
  #11 bỏ, không thuộc scope ticket
  Còn lại OK.
Lưu file lại rồi chạy /qa-apply-feedback TLM-XXXX. -->

(để trống cho người review)
