---
name: git-diff-scope
description: >-
  Cô lập git diff của đúng một ticket Telemax (TLM-XXXX) và lọc bỏ file nhiễu, để
  biết thay đổi code lan tới đâu và vùng nào cần test hồi quy. Dùng khi phân tích một
  ticket có commit/nhánh liên quan, hoặc khi người dùng hỏi "thay đổi này ảnh hưởng
  gì", "cần test hồi quy chỗ nào". Kết quả nuôi mục G (Impact) của checklist.
---

# git-diff-scope

**Khi nào áp dụng skill này:** chỉ khi ticket **có git diff liên quan** để phân
tích. Git diff là nguồn *bổ sung* (cho biết cái gì vừa đổi), KHÔNG bắt buộc. Bỏ
qua tầng diff trong hai trường hợp:
- **Code chưa xong** (test viết trước/song song code) → chưa có commit của ticket.
- **Ticket không đụng code** (config, nghiệp vụ thuần, data, đổi setting).

Khi không có diff, KHÔNG coi là lỗi. Chuyển sang phân tích từ: mô tả ticket + AC +
comment, và **đọc code hiện tại trong repo** để hiểu ngữ cảnh (đặc biệt cho case
integration — luồng thật, service/endpoint liên quan). Phân biệt rõ:
- *Git diff* = cái **vừa đổi** (có thể vắng).
- *Code hiện tại* = cái **đang có** (luôn đọc được, dùng để hiểu ngữ cảnh).

**Vai trò của diff:** git diff dùng để **đánh giá impact** (thay đổi lan tới đâu,
vùng nào cần test hồi quy) → đưa vào mục G (Impact) của checklist. Nguồn chính để
dựng checklist "cần test gì" vẫn là **spec ClickUp** + code hiện tại. Diff KHÔNG
đẻ ra checklist chính, kể cả khi có.

## Đầu vào skill cần

| Cần | Thiếu thì |
|---|---|
| Ticket ID | Hỏi. Suy từ tên nhánh phải được xác nhận trước khi dùng |
| Nhánh base để so sánh | Mặc định **`stage`** — nhánh build ra dashboard-stage (xem `qa-config.md`). KHÔNG phải `dev`, KHÔNG phải `master`. Vẫn nêu ra cho người dùng xác nhận |
| Repo git hợp lệ | Không phải repo git → báo, không đoán |

Không tìm thấy commit/nhánh của ticket **không phải lỗi**, nhưng cũng không tự kết
luận. Hỏi người dùng: code chưa xong, hay ticket không đụng code? Câu trả lời quyết
định checklist có mục G hay không.

Phần dưới đây chỉ áp dụng KHI có diff.

---

Khi phân tích git diff để xác định **cần test gì**, làm theo HAI tầng lọc, đúng thứ tự:
1. **Lọc theo ticket** — chỉ lấy thay đổi của đúng ticket đang xử lý.
2. **Lọc theo loại file** — trong đám đó, bỏ nhiễu, giữ file đổi hành vi.

## Tầng 1 — Cô lập diff theo ticket

Quy ước team: ticket ID dạng `TLM-XXX` (VD `TLM-2689`) xuất hiện ở **cả tên
branch lẫn commit message**. Ưu tiên theo thứ tự:

**Cách A (ưu tiên) — branch chứa ID, so với nhánh base:**
Nếu đang làm trên nhánh feature theo ticket (`feature/TLM-2689-...`), lấy diff so với
điểm rẽ nhánh chung với base (mặc định `stage`):
```
git diff stage...<branch> --name-only         # dùng BA chấm: so với merge-base,
                                               # không dính commit mới của stage
```

So với `master` thay vì `stage` sẽ lôi vào cả thay đổi chưa lên staging — mục G
(Impact) khi đó nói về vùng ảnh hưởng của một bản mà tester không hề đang test.
Lấy ticket ID tự động từ tên nhánh khi cần:
```
git rev-parse --abbrev-ref HEAD | grep -oE 'TLM-[0-9]+'
```

**Cách B (fallback) — grep commit message:**
Khi không ở nhánh riêng (VD nhiều ticket chung nhánh, hoặc đã merge), gom commit
theo ID trong message:
```
git log --grep="TLM-XXX" --name-only --pretty=format: | sort -u | grep -v '^$'
```

Nguyên tắc chọn: có nhánh riêng theo ticket → dùng A (chính xác & gọn nhất). Không
có → dùng B. Nếu cả hai áp dụng được, A cho kết quả sạch hơn.

Chỉ phân tích các file mà tầng này trả về — KHÔNG đọc toàn bộ repo, KHÔNG dính
thay đổi của ticket khác.

## Tầng 2 — Lọc theo loại file

Trong danh sách file mà tầng 1 trả về, tập trung thay đổi **hành vi thật**, bỏ nhiễu.

### Bỏ qua (nhiễu — không phản ánh thay đổi hành vi cần test)

- Migration EF Core tự sinh: `Migrations/*.cs`, `*.Designer.cs`
  (ngoại lệ: khi chính migration/schema là trọng tâm ticket thì phải xem).
- File generated / scaffolded: `*.g.cs`, DTO/client tự sinh.
- Lock & version thuần: `packages.lock.json`, thay đổi `*.csproj` chỉ bump version
  package (không đổi code).
- Tài liệu & comment thuần: `*.md`, đổi comment không đổi logic.
- Asset tĩnh: ảnh, css, font, icon.

### Luôn xem (tín hiệu thay đổi hành vi)

- Code nghiệp vụ: service, handler, controller, validator, mapper.
- **Config môi trường** (`appsettings*.json`): KHÔNG bỏ qua — đổi config có thể
  đổi hành vi (ngưỡng, feature flag, endpoint) và cần test.
- **File test có sẵn** (`*.Tests.cs`, `*.spec.ts`): KHÔNG bỏ qua — dev sửa test
  thường là dấu hiệu hành vi đã đổi; đọc để hiểu ý định thay đổi.
- Hợp đồng API: thay đổi route, request/response model, status code.
- Migration khi nó thay đổi ràng buộc dữ liệu ảnh hưởng hành vi (not-null, unique,
  default) — dù tự sinh, loại này cần cân nhắc.

### Nguyên tắc khi phân vân

Nếu không chắc một thay đổi có đổi hành vi người dùng hay không, **nghiêng về
XEM còn hơn bỏ sót**. Bỏ sót một thay đổi hành vi nguy hiểm hơn xem thừa một file
vô hại.

> Bộ quy ước này bổ sung khi gặp loại file đặc thù Telemax chưa liệt kê.
