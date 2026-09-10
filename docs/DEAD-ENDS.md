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
