---
description: Chẩn đoán harness — soát môi trường và cấu hình, KHÔNG cài gì. Chạy bất cứ lúc nào thấy lạ
argument-hint: (không cần tham số)
---

Chẩn đoán harness QA trong repo này. **Đọc-only: không cài gì, không sửa file nào.**

Khác `/qa-setup`: setup là chặng **cài đặt**, chạy một lần cho repo mới, có bước xin
duyệt rồi chạy lệnh. Doctor là chặng **soi bệnh**, chạy nhiều lần trong đời repo —
mỗi khi thấy triệu chứng lạ. Trước đây `/qa-run` bảo "chạy `/qa-setup` để dọn" khi
phát hiện xung đột MCP, tức là mở nguyên một command cài đặt chỉ để chẩn một lỗi.

Cuối cùng, **đề xuất lệnh sửa nhưng KHÔNG tự chạy** — nêu ra để tôi quyết.

## 1. Soát — gộp thành ÍT lệnh nhất có thể

Các kiểm này độc lập nhau, nên phát trong cùng một message, đừng chạy tuần tự 10 lượt.

| Kiểm | Cách kiểm |
|---|---|
| Python + openpyxl | `bash .claude/scripts/qa-py.sh -c "import openpyxl, sys; print(sys.executable)"` |
| LibreOffice (cho `recalc.py`) | `which soffice \|\| ls /Applications/LibreOffice.app 2>/dev/null` |
| Chromium cho Playwright | `ls ~/.cache/ms-playwright 2>/dev/null \|\| ls ~/Library/Caches/ms-playwright 2>/dev/null` |
| `qa-config.md` còn `CHƯA ĐIỀN` | `grep -n "CHƯA ĐIỀN" .claude/qa-config.md` |
| Trạng thái project e2e | `bash .claude/scripts/qa-config.sh playwright \| head -5` |
| Project e2e tồn tại thật | `ls <thư mục khai trong qa-config>/playwright.config.ts` |
| `.env` của e2e | `ls <thư mục e2e>/.env` |
| **Secret của e2e đã ignore chưa** | `git check-ignore -q <e2e>/.env <e2e>/playwright/.auth/user.json && echo OK \|\| echo "CHƯA IGNORE — DỪNG"` — `user.json` chứa `authToken_*`/`refreshToken` sống, và `git status` gộp cả cây thành một dòng `?? <e2e>/` nên nhìn mắt không thấy. Không qua → sửa `.gitignore` **trước mọi bước khác** |
| Postman collection | `bash .claude/scripts/qa-config.sh postman` rồi `ls` đường dẫn khai báo |
| Profile MCP có bị chiếm | `test -L .playwright-mcp-profile/SingletonLock && echo LOCKED \|\| echo FREE` |
| MCP Playwright trong danh sách tool | có `Playwright:browser_*` không |
| Trùng scope MCP | `claude mcp list` |
| `.mcp.json` khớp qa-config | `cat .mcp.json` — so từng tham số |
| Connector OAuth | có `ClickUp:*` và `Figma:*` trong danh sách tool không |
| Connector Drive | có tool Drive nào không — không có thì `/qa-file-bugs` chỉ bỏ bước upload, không phải lỗi |

## 2. Ba bệnh hay gặp — chẩn cho đúng, đừng đoán

**a. Trùng scope MCP.** Nhiều hơn một entry `playwright` (`local`/`user` + `project`)
→ chỉ một bản thắng, và bản thắng thường **không mang** args trong `.mcp.json`.
Hỏng **im lặng**, không có thông báo lỗi nào. Bảng triệu chứng ↔ chẩn nhầm:
[docs/DEAD-ENDS.md](../../docs/DEAD-ENDS.md) §3.

Đề xuất: `claude mcp remove playwright -s local` (hoặc `-s user`), **rồi thoát Claude
Code và mở lại**. Không tự chạy — lệnh này sửa cấu hình máy tôi, không chỉ repo.

**b. `.mcp.json` lệch bảng Playwright trong `qa-config`.** Phải có đủ, đúng giá trị:
`--user-data-dir` · `--output-dir` · `--timeout-action 30000` ·
`--timeout-navigation 120000` · `--timeout-settle 1000` · `--viewport-size`.
Và phải **KHÔNG có** `--isolated` / `--storage-state` (xem DEAD-ENDS §1).

Hậu quả gặp thật khi thiếu: `--timeout-action` mặc định **5s**, `browser_wait_for`
chết với `TimeoutError: Timeout 5000ms exceeded` trên SPA này.

**Sửa `.mcp.json` xong là phải thoát Claude Code và mở lại** — MCP đọc args lúc khởi
động, sửa giữa session không có tác dụng và không có tín hiệu nào báo.

**c. Rơi về `/login` mãi không thoát.** Đừng lặp đăng nhập. Nếu profile `FREE` thì
`node .claude/scripts/seed-mcp-profile.mjs` xử được (idempotent). Nếu `LOCKED` mà
vẫn `/login` → probe `localStorage` trên `/favicon.ico`; chỉ có `app-version` nghĩa
là profile không được nạp — đó là bệnh (a) hoặc (b), seed lại vô ích.

## 3. Báo cáo

Bảng ba cột: **Mục · Trạng thái · Việc cần làm**. Chia rõ:

- **Chặn** — không có thì harness không chạy được (Python+openpyxl, project e2e khi
  Trạng thái là `CÓ`, `.env`, connector ClickUp).
- **Không chặn nhưng phải biết** — LibreOffice thiếu (Excel vẫn đúng, chỉ ô Summary
  trống tới khi mở bằng Excel một lần) · Postman `CHƯA CÓ` (nhánh API skip) ·
  Playwright `KHÔNG DÙNG` (nhánh UI skip).
- **Việc tôi phải tự làm** — điền `.env`, điền `qa-config.md`, bật connector OAuth.
  Liệt kê đúng dòng, **đừng làm thay**.

Sạch hết thì nói một câu và nêu lệnh tiếp theo nên chạy.

## Ranh giới

- **KHÔNG cài gì, KHÔNG sửa file nào** — đó là `/qa-setup`.
- KHÔNG tự chạy `claude mcp remove` hay sửa `.mcp.json`.
- KHÔNG hỏi mật khẩu/token qua chat; KHÔNG tự điền `.env`.
