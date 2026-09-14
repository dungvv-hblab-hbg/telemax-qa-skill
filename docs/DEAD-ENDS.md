# Ngõ cụt đã đi — đừng thử lại

Biên bản điều tra cho các thứ trong `.claude/qa-config.md` được đánh dấu "ĐÃ THỬ".
Ở đó chỉ còn một câu mệnh lệnh; toàn bộ lý do và bằng chứng nằm ở đây.

Vì sao tách: `qa-config.md` được đọc ở mọi chặng. Câu *"đừng làm X"* là thứ agent
cần mỗi lần; còn *biên bản vì sao* thì chỉ cần khi có người định thử lại X — tức là
gần như không bao giờ, nhưng khi cần thì cần đầy đủ.

---

## 1. Gộp hai session làm một — KHÔNG DÙNG ĐƯỢC

**Ý tưởng:** cho MCP Playwright dùng chung `storageState` với project e2e, để chỉ
phải đăng nhập một lần thay vì hai.

**Đã thử:** `--isolated --storage-state telemax-e2e/playwright/.auth/user.json`
trong args của `.mcp.json`.

**Kết quả:** mọi lệnh MCP vẫn rơi về `/login`, ngay sau khi `npm run auth` báo lưu
session thành công. Thử cả đường dẫn tương đối lẫn tuyệt đối — như nhau.

**Nguyên nhân gốc:** session Telemax nằm **100% trong localStorage, 0 cookie**.
`user.json` có `cookies: []` và 12 key trong `origins[0].localStorage`. MCP nạp
phần cookie, không nạp phần localStorage.

**Kết luận:** hai session tách biệt — profile MCP (`.playwright-mcp-profile/`) và
`user.json` của code — là **thiết kế**, không phải thiếu sót chờ tối ưu.

## 2. Bơm storage state vào context MCP bằng JS — KHÔNG DÙNG ĐƯỢC

**Ý tưởng:** dùng `browser_run_code_unsafe` đọc `user.json` rồi `localStorage.setItem`
từng key, coi như tự nạp session.

**Đã thử, cả hai đều chết ở tầng filesystem:**

```
require('fs')                          → ReferenceError
await import('node:fs/promises')       → ERR_VM_DYNAMIC_IMPORT_CALLBACK_MISSING
```

**Nguyên nhân gốc:** `browser_run_code_unsafe` chạy trong sandbox không có
filesystem. Không đọc được file thì không có gì để bơm.

**Kết luận:** mọi biến thể của "đọc `user.json` rồi `localStorage.setItem`" đều chết
ở đúng chỗ này. Cách duy nhất nạp session vào profile MCP là seed bằng một tiến
trình Node riêng — `.claude/scripts/seed-mcp-profile.mjs`.

## 3. Xung đột scope MCP — triệu chứng nhận biết

Không phải ngõ cụt, mà là một chế độ hỏng **im lặng** dễ chẩn đoán nhầm thành hai
lỗi khác.

Có nhiều hơn một entry `playwright` (VD một ở scope `local`/`user`, một ở `project`)
thì chỉ một bản thắng, và bản thắng thường là bản cài trước ở scope hẹp hơn — tức
bản **không mang** args trong `.mcp.json` của harness.

Hậu quả, không có thông báo lỗi nào:

| Triệu chứng | Bị chẩn nhầm thành |
|---|---|
| `browser_wait_for` chết với `TimeoutError: Timeout 5000ms exceeded` | SPA chậm / mạng lỗi |
| Seed profile xong **vẫn** rơi về `/login`, seed lại bao nhiêu lần cũng vậy | session hết hạn / sai mật khẩu |

Nguyên nhân: thiếu `--timeout-action 30000` (mặc định 5s) và thiếu `--user-data-dir`
(browser dùng thư mục tạm, không phải `.playwright-mcp-profile/`).

Kiểm: `claude mcp list`. Gỡ: `claude mcp remove playwright -s local` (hoặc `-s user`),
rồi **thoát Claude Code và mở lại**.

Vòng lặp cần tránh khi gặp `/login`: đăng nhập → vẫn `/login` → xoá `user.json` →
ép `npm run auth` → vẫn `/login`. Probe `localStorage` trên `/favicon.ico` trước —
chỉ có `app-version` nghĩa là profile trống, seed lại vô ích cho tới khi sửa cấu hình.

## 4. Spec .ts fail 30/32 ngay lần chạy đầu — không lỗi nào là lỗi sản phẩm

Biên bản của bộ bẫy locator ghi trong `skills/playwright-export/SKILL.md`. Đo trên
TLM-3088 (`[Bug][Reports] Report Period displays 24-hour time…`), dashboard Blazor WASM.

Diễn biến số fail qua từng lần sửa:

| Lần | Fail | Pass | Sửa gì |
|---|---|---|---|
| 1 | 30 | 2 | (spec vừa export) |
| 2 | 24 | 8 | selector: span trigger, visible filter, regex neo |
| 3 | 17 | 15 | `fullyParallel: false` |
| 4 | **16** | **16** | thêm ô Geofence bắt buộc |

16 fail cuối = `TC-A-002`, `TC-A-003`, `TC-A-009` + `TC-B-005` × 13 report type — **đúng
bằng** số assertion date-first cố ý phải đỏ cho tới khi dev sửa. Tức là sau 4 vòng, 0 lỗi
còn lại thuộc về spec.

**Bốn nguyên nhân, không cái nào tự lộ ra:**

1. **Dropdown tự chế giữ option trong DOM kể cả khi đóng.** 31 thẻ
   `div.field-searchable-select__select-item` của cả hai select luôn có mặt. Nên
   `div:text-is("Idle Report")` khớp đúng thẻ đang ẩn, `.last()` chọn nó, click chờ hết
   60s. Một mình nguyên nhân này là **21/30** fail.
2. **`selectOption('Last 7 days')` so theo VALUE, không phải label.** Value thật:
   `Today` / `LastDay` / `Last3Days` / `LastWeek` / `Last30Days` / `Custom` — 4/6 option
   có label khác value.
3. **`hasText` là so chuỗi con** → `'Idle Report'` khớp luôn `'Fleet Idle Report'`.
4. **Field bắt buộc theo biến thể màn hình.** Geofence Report không dùng ô Vehicle mà có
   ô Geofence riêng, bắt chọn tường minh — validation `"Please select a geofence."` hiện
   **dù** option đầu đã `[selected]`. Spec bỏ qua → report không chạy → trang đứng ở
   "Nothing run yet" → case đỏ như thể mất block Report Period.

**Vì sao nguy hiểm hơn "chỉ là spec sai":** `playwright-export` quy định *"Phase 1 Pass
mà spec Fail → spec sai, sửa selector rồi chạy lại"*. Luật đó đúng **cho từng case**.
Khi 30/32 cùng đỏ, nguyên nhân mang tính hệ thống, và áp luật per-case vào đó là đi sửa
30 chỗ vốn không hỏng — một vòng lặp không có lối ra.

## 5. `fullyParallel: true` trên SPA nặng — fail GIẢ trông y hệt selector hỏng

Đo cùng lượt TLM-3088, cùng một bộ test, chỉ đổi cấu hình chạy:

| Cấu hình | Kết quả |
|---|---|
| `fullyParallel: true` (5 worker) | 24 fail / 8 pass, 4,1 phút |
| cùng bộ test, `--workers=1` | các case đó **pass hết** |
| `fullyParallel: false` | 16 fail / 16 pass, 9,0 phút — 16 fail là assertion cố ý phải đỏ |

Cơ chế: nhiều browser cùng boot Blazor WASM làm một số tab đứng ở trang trắng, mọi test
trong worker đó chết ở `beforeEach` với
`expect(locator).toBeVisible() failed — getByText('Report Type')`, snapshot chỉ có
`- img`. **Nhìn y hệt selector hỏng.**

Kết luận đã áp vào template: `fullyParallel: false` + `workers: 2`. Các FILE vẫn chạy
song song với nhau; chỉ test trong cùng một file bị tuần tự hoá — mà harness dùng một
file cho một ticket, nên đây đúng là thứ cần. `workers: undefined` = số core / 2
(5 worker trên Mac 8 nhân), quá nhiều cho một SPA nặng.
