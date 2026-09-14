---
description: Cài harness cho repo mới — kiểm và chạy hai lệnh setup, rồi soát các thứ còn thiếu
argument-hint: (không cần tham số)
---

Cài harness QA cho repo này. Chạy một lần khi mới copy `.claude/` vào một repo mới.

## 1. Soát trước, đừng cài lại thứ đã có

Kiểm từng cái rồi báo tôi trạng thái **trước khi chạy bất cứ lệnh nào**:

| Kiểm | Cách kiểm |
|---|---|
| Chromium cho Playwright | `ls ~/.cache/ms-playwright 2>/dev/null \|\| ls ~/Library/Caches/ms-playwright 2>/dev/null` |
| MCP Playwright | có `.mcp.json` ở gốc repo với entry `playwright` không, và `Playwright:browser_*` có trong danh sách tool không |
| **`.mcp.json` khớp `qa-config.md` chưa** | so từng tham số, xem mục riêng bên dưới |
| **Có server `playwright` trùng ở scope khác không** | `claude mcp list` — xem mục 2c |
| **Project e2e** | xem mục 2d — dò trước, hỏi, rồi mới dựng. Đừng giả định `telemax-e2e/` tồn tại |
| `.env` của e2e | `<project e2e>/.env` tồn tại không (biết đường dẫn sau mục 2d) |
| `qa-config.md` | còn dòng nào `CHƯA ĐIỀN` không |
| **Python + openpyxl** | `bash .claude/scripts/qa-py.sh -c "import openpyxl, sys; print(sys.executable)"` |
| **LibreOffice** (cho `recalc.py`) | `which soffice \|\| ls /Applications/LibreOffice.app 2>/dev/null` |
| **Secret của e2e đã ignore chưa** | `for f in <e2e>/.env <e2e>/playwright/.auth/user.json; do git check-ignore -q "$f" \|\| echo "CHƯA IGNORE: $f"; done` — không in gì = đạt. `user.json` chứa `authToken_*`/`refreshToken` sống, và `git status` gộp cả cây thành một dòng `?? <e2e>/` nên nhìn mắt không thấy. Có dòng nào in ra → sửa `.gitignore` **trước mọi bước khác**. **Phải lặp từng file**: `check-ignore -q` chỉ nhận MỘT đường dẫn, truyền hai cái là `fatal:` và nhánh `||` báo "chưa ignore" kể cả khi đã ignore đúng |
| **Session code e2e** | `ls <project e2e>/playwright/.auth/user.json` |
| **Postman collection** | `ls tests/postman/telemax.postman_collection.json` — đường dẫn khai ở `qa-config.md` |

Cái nào đã có thì bỏ qua, đừng cài đè.

## 2. Xin duyệt rồi chạy — MỘT LƯỢT cho cả lô

Trình bày đúng những lệnh sẽ chạy, nói rõ mỗi lệnh làm gì, rồi **chờ tôi đồng ý**.
Tôi gật cả lô là được, đừng hỏi từng lệnh.

**a0. Python + openpyxl** — chỉ chạy khi lệnh kiểm ở trên thất bại:

```bash
python3 -m venv .claude/.venv && .claude/.venv/bin/python -m pip install openpyxl
```

Đã có `.qa/.venv` từ trước thì **vẫn chạy được** — wrapper nhận nó. Nhưng nêu với tôi
rằng nên chuyển sang `.claude/.venv`: `.qa/` là thư mục kết quả theo ticket, dọn `.qa/`
là mất venv.

**Đừng chạy `pip install openpyxl` trần** — thất bại với `externally-managed-environment`
(PEP 668) trên macOS Homebrew và Ubuntu 23+. Cũng **đừng dựng venv ở chỗ khác**
(`.qa/.venv`, `~/.qa-venv`…): `.qa/` là thư mục kết quả theo ticket, và venv lạc thì
session sau không biết đường tìm. Đã có venv riêng thì đặt `QA_PYTHON` trỏ tới nó thay
vì tạo thêm cái mới.

**a. Tải trình duyệt cho Playwright** (~115MB, chỉ ghi vào cache của Playwright):

```bash
cd <project e2e> && npm install && npx playwright install chromium
```

Đường dẫn project biết được sau mục 2d. Chạy trong container/CI thì cần thêm
`npx playwright install-deps chromium`.

**b. Đăng ký MCP Playwright** — chỉ chạy khi `.mcp.json` **chưa có** entry `playwright`:

```bash
claude mcp add playwright -- npx -y @playwright/mcp@latest
```

Harness đã kèm sẵn `.mcp.json` ở gốc repo, nên thường **không cần lệnh này**. Chỉ
dùng khi repo đã có `.mcp.json` riêng và bạn phải merge thêm entry vào đó.

Lệnh này **sửa cấu hình repo**, nên không được chạy khi tôi chưa đồng ý.

Sau khi đăng ký, kiểm bằng `/mcp`. Tool `Playwright:browser_*` chưa xuất hiện ngay
thì khởi động lại session Claude Code — server MCP mới thường chỉ được nạp lúc khởi
động.

## 2d. Project e2e — dò, HỎI, rồi mới dựng

`install.sh` **không copy project e2e nữa** (mặc định). Project e2e phụ thuộc app
thật — URL, form đăng nhập, tên biến môi trường, dữ liệu mẫu. Bê nguyên project của
app khác sang thì mọi selector đều sai và `npm run check` đỏ ngay từ phút đầu.

Áp `skill: e2e-scaffold`. Nó lo phần dò và phần khuôn; **phần hỏi là của tôi và bạn**
— bạn là command, chờ người dùng được, agent thì không.

**Bước 1 — dò trước, đừng hỏi thứ đọc được từ repo.** Chạy khối lệnh dò trong skill,
rồi báo tôi đúng bốn điều: đã có Playwright chưa · có framework e2e khác không · có
phải app web không · URL đoán được là gì.

**Bước 2 — hỏi tôi MỘT lượt**, kèm nhánh bạn đề xuất và lý do:

| Dò thấy | Đề xuất | Làm gì |
|---|---|---|
| Đã có `playwright.config.*` | **A** | **Vá** config sẵn có cho đủ 4 hàng rào (`grep: /@prod-safe/`, storageState tách staging↔prod, project staging có tên, artifact bật). Đưa tôi duyệt diff. **Không ghi đè** — config đó có thể đang chạy CI |
| Chưa có, và là app web | **B** | Scaffold từ `assets/playwright.config.template.ts`, điền phần app-specific. Hỏi tôi thư mục đích (đề xuất `e2e/`), URL staging + prod, tiền tố biến môi trường |
| Không phải app web, hoặc tôi chưa muốn dựng | **C** | Ghi `qa-config.md` mục Playwright `Trạng thái | KHÔNG DÙNG`. Nhánh UI sẽ bị skip như nhánh API khi chưa có Postman — **không chặn** `/qa-run` |
| Có Cypress/Selenium/pytest, chưa có Playwright | **hỏi rõ** | Harness chỉ chạy được với Playwright (xem mục "Ranh giới" của skill). Hai lựa chọn: dựng Playwright song song bộ sẵn có (**B**), hay bỏ nhánh UI (**C**). **Đừng tự chọn thay tôi** |

**Không đoán `PROD_BASE_URL`.** Không hỏi mật khẩu qua chat — credential chỉ vào
`.env`, và `.env` phải nằm trong `.gitignore` trước khi tôi điền.

**Bước 3 — chốt vào `qa-config.md`** mục Playwright: `Trạng thái` + `Thư mục project`
đúng đường dẫn thật. Mọi chặng sau đọc từ đó, nên sai ở đây là sai suốt.

**Bước 4 — nêu lệnh cài, chờ tôi duyệt**, đừng tự chạy:

```bash
cd <project e2e> && npm install && npx playwright install chromium
```

Nhánh **A** thì bỏ qua bước này nếu repo đã cài rồi.

## 1b. Ba thứ thiếu thì KHÔNG chặn, nhưng phải báo trước

Đừng để tôi phát hiện ở phút thứ 11 của một chặng.

- **LibreOffice thiếu** → file Excel vẫn sinh đúng, chỉ là ô Summary trống tới khi mở
  bằng Excel một lần. Báo cách cài: `brew install --cask libreoffice` ·
  `sudo apt install libreoffice-calc`. Không có thì `/qa-write-cases` chạy xong mới
  báo, sau khoảng 11 phút.
- **Session code e2e** — 2FA đang TẮT thì **không phải làm gì**: project `chromium`
  khai `dependencies: ['setup']` nên Playwright tự đăng nhập trước mỗi lần chạy,
  miễn `.env` có credential. 2FA BẬT thì bảo tôi chạy
  `cd <project e2e> && npm run auth:headed` một lần.
- **Postman collection chưa có** ở đường dẫn khai trong `qa-config.md` → đúng như
  Trạng thái `CHƯA CÓ`, nhánh API sẽ được skip. Xác nhận lại với tôi để tôi biết bộ
  case sắp tới không phủ API, thay vì phát hiện giữa `/qa-run`.

> Phần chẩn đoán chi tiết (2b, 2c) cũng chạy được riêng bằng **`/qa-doctor`** —
> đọc-only, không cài gì. Dùng nó khi repo đã cài xong mà thấy triệu chứng lạ,
> thay vì mở lại cả command cài đặt này.

## 2c. Chỉ giữ MCP Playwright ở scope project

```bash
claude mcp list
```

Có **nhiều hơn một** entry `playwright` (VD một ở `local`/`user`, một ở `project`) →
**xung đột**. Chỉ một bản thắng, và bản thắng thường là bản cài trước ở scope hẹp hơn —
tức là bản **không mang** các tham số trong `.mcp.json` của harness.

Hậu quả im lặng, không có thông báo lỗi nào:

- `--timeout-action` vẫn là mặc định 5s → `browser_wait_for` chết với
  `TimeoutError: Timeout 5000ms exceeded`.
- Không có `--user-data-dir` → browser dùng thư mục tạm, nên **seed profile xong vẫn rơi
  về `/login`**, seed lại bao nhiêu lần cũng vô ích.

Đề xuất tôi gỡ bản ngoài project, nêu đúng lệnh rồi **chờ tôi duyệt** (lệnh này sửa cấu
hình máy tôi, không phải chỉ repo này):

```bash
claude mcp remove playwright -s local     # hoặc -s user, tuỳ scope thấy ở list
```

Chạy `claude mcp list` lại để xác nhận chỉ còn bản `project`. **Rồi bảo tôi thoát Claude
Code và mở lại** — thay đổi MCP chỉ có tác dụng sau khi khởi động lại.

Tôi muốn giữ bản local vì lý do riêng → tôn trọng, nhưng nói rõ hai hậu quả trên và
rằng harness sẽ chạy bằng cấu hình mà nó không kiểm soát được.

## 2b. Đối chiếu `.mcp.json` với bảng trong `qa-config.md`

Kiểm **từng tham số**, không chỉ kiểm file có tồn tại:

```bash
cat .mcp.json
```

Phải có đủ, đúng giá trị như bảng Playwright trong `.claude/qa-config.md`:
`--user-data-dir` · `--output-dir` · `--timeout-action 30000` ·
`--timeout-navigation 120000` · `--timeout-settle 1000` · `--viewport-size`.

Và phải **KHÔNG có** `--isolated` / `--storage-state`: cặp này không nạp được session
của Telemax (xem dòng "Gộp còn MỘT session" trong `qa-config.md`).

Thiếu hoặc lệch → báo tôi đúng dòng nào sai, đề xuất nội dung đúng, chờ tôi duyệt rồi
sửa. Hậu quả gặp thật khi thiếu: `--timeout-action` mặc định **5s**, `browser_wait_for`
chết với `TimeoutError: Timeout 5000ms exceeded` trên SPA này.

Kiểm luôn `.gitignore` có `.playwright-mcp-profile/` và `.playwright-mcp-output/` chưa.

**Sửa `.mcp.json` xong là phải thoát Claude Code và mở lại** — MCP server đọc args lúc
khởi động, sửa giữa session không có tác dụng và không có tín hiệu nào báo.

## 3. Việc tôi phải tự làm — liệt kê ra, đừng làm thay

- `cp <project e2e>/.env.example <project e2e>/.env` rồi điền `<PFX>_USER` / `<PFX>_PASS`
  (thư mục và tiền tố là thứ đã chốt ở mục 2d).
  **Đừng hỏi mật khẩu qua chat và đừng tự ghi vào file.**
- Sau khi điền `.env`: chạy `node .claude/scripts/seed-mcp-profile.mjs` để đăng nhập
  vào profile MCP. **Chạy trước khi gọi bất kỳ tool MCP nào** — MCP giữ lock trên thư
  mục profile một khi đã mở browser.
- Xác nhận mục **Ticket** của `.claude/qa-config.md`: tiền tố ticket (`TLM-`) và hai
  tên nhánh (`stage` / `master`) đúng với repo này. Không có ô `CHƯA ĐIỀN` nào canh
  chúng, nên sai thì `/qa-run` dừng ở cổng 1 với lý do sai hoàn toàn.
- Điền `.claude/qa-config.md`: list/space ClickUp chứa bug, tag, đường dẫn Postman.
  Liệt kê đúng những dòng còn `CHƯA ĐIỀN`.
- Bật connector ClickUp và Figma (`/mcp` → chọn server → Authenticate). Đây là
  connector OAuth, khác Playwright MCP.

## 4. Kiểm lại

Sau khi tôi điền `.env`, chạy:

```bash
cd <project e2e> && npm run check
```

Xanh = tới được staging và form login đúng selector. Đỏ thì sửa ở đây trước, đừng đi
tiếp — mọi test khác đều dựa vào hai điều đó.

Rồi chạy `bash .claude/scripts/smoke-scripts.sh` để chắc tầng script không vỡ.

## 5. Tổng kết

Báo bằng tiếng Việt: cái gì đã có sẵn, cái gì vừa cài, cái gì còn chờ tôi làm, và lệnh
tiếp theo nên chạy (`/qa-analyze TLM-XXXX`).

Đừng tự điền `.env`, đừng tự sửa `qa-config.md`, đừng tự bật connector OAuth.
