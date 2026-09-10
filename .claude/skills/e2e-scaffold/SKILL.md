---
name: e2e-scaffold
description: >-
  Quyết định và dựng project Playwright e2e cho một repo mới cài harness: dò xem repo
  đã có sẵn e2e chưa, hỏi người dùng, rồi hoặc nối harness vào project sẵn có, hoặc
  scaffold project mới theo app thật của repo đó, hoặc bỏ hẳn nhánh UI. Dùng khi chạy
  /qa-setup trên repo mới, khi qa-config ghi Playwright Trạng thái `CHƯA CÓ`, hoặc khi
  người dùng nói "cài e2e", "dựng project test UI", "repo này chưa có Playwright".
---

# e2e-scaffold

Harness **không** copy sẵn một project Playwright vào repo đích nữa. Lý do: project
e2e phụ thuộc vào **app thật** — URL, form đăng nhập, tên biến môi trường, dữ liệu
mẫu. Bê nguyên project của app khác sang thì mọi selector đều sai, và `npm run check`
đỏ ngay từ phút đầu mà người mới cài không biết vì sao.

Skill này lo **phần quyết định và phần khuôn**. Việc hỏi người dùng do `/qa-setup`
làm (command chờ người được, agent thì không).

## Ranh giới — đọc trước, tránh kỳ vọng sai

**Harness này chỉ chạy được với Playwright.** Không phải vì lười, mà vì bốn chỗ gắn
chặt vào nó:

| Chỗ | Gắn thế nào |
|---|---|
| `playwright-export` | sinh spec `.ts` bằng API Playwright |
| `test-runner`, `prod-verifier` | chạy `npx playwright test --project=...` |
| `.mcp.json` | `@playwright/mcp` cho Phase 1 dò element |
| Hàng rào `@prod-safe` | `grep: /@prod-safe/` trong `playwright.config.ts` |

Repo đích dùng Cypress / Selenium / pytest thì **không scaffold sang framework đó**
— đó là viết lại ba skill, không phải đổi scaffold. Khi ấy chọn nhánh **C** bên dưới
(bỏ nhánh UI, giữ nguyên nhánh API + manual), hoặc dựng thêm Playwright song song với
bộ test sẵn có.

**Ngôn ngữ backend của repo KHÔNG quyết định gì.** Playwright lái trình duyệt; app
đằng sau là .NET, Go hay Rails đều như nhau. Thứ thật sự khác giữa các repo là: đã có
e2e chưa · form login trông thế nào · có phải app web không.

## Bước 1 — Dò hiện trạng (chạy trước khi hỏi)

```bash
# Đã có project Playwright nào chưa?
find . -maxdepth 3 -name 'playwright.config.*' -not -path '*/node_modules/*'
# Framework e2e khác?
find . -maxdepth 3 \( -name 'cypress.config.*' -o -name 'wdio.conf.*' -o -name 'conftest.py' \) -not -path '*/node_modules/*'
# Có phải app web không, và Node có sẵn không?
ls package.json 2>/dev/null && node --version
# URL app đang khai ở đâu (gợi ý BASE_URL, đừng tự đặt)
grep -rEn 'BASE_URL|baseUrl|VITE_API|REACT_APP.*URL' --include='*.env*' --include='*.json' --include='*.config.*' . 2>/dev/null | grep -v node_modules | head
```

Tóm tắt cho `/qa-setup` đúng bốn điều: **có Playwright chưa** · **có framework e2e
khác không** · **có phải app web không** · **URL đoán được là gì** (chỉ đề xuất,
không tự chốt).

## Bước 2 — Ba nhánh

### A. Repo ĐÃ CÓ project Playwright → nối vào, đừng dựng thêm

Đây là nhánh hay gặp nhất ở repo đã trưởng thành, và cũng là nhánh trước đây bị bỏ
lửng: bản cũ của `install.sh` thấy thư mục đã tồn tại thì bỏ qua, để lại một repo có
Playwright nhưng **không có hàng rào nào của harness**.

Không copy gì. Thay vào đó **vá config sẵn có** cho đủ bốn thứ, rồi ghi đường dẫn
thật vào mục Playwright của `qa-config.md`:

1. **Project `prod` có `grep: /@prod-safe/`** — hàng rào cứng. Thiếu nó thì
   `/qa-verify-prod` chạy mọi case lên dữ liệu khách hàng thật.
2. **`storageState` tách hẳn giữa staging và production** — hai file, hai đường dẫn.
   Dùng chung một file là đường ngắn nhất tới chạy nhầm môi trường.
3. **Project staging có tên rõ ràng** (`chromium`) để mọi lệnh truyền `--project` được.
4. **Artifact bật**: `trace: 'on-first-retry'`, `screenshot: 'only-on-failure'`,
   `video: 'retain-on-failure'` — bug cần Actual Result thật, lấy từ `test-results/`.

**Vá, không ghi đè.** Config của họ có thể đang chạy CI. Trình bày diff đề xuất cho
người dùng duyệt; đụng vào project đang có tên khác thì hỏi, đừng đổi tên.

### B. Repo CHƯA CÓ, và là app web → scaffold theo app thật

Dùng [assets/playwright.config.template.ts](assets/playwright.config.template.ts) làm
khung. Nó đã mang sẵn cả bốn hàng rào trên; phần phải điền là phần **app-specific**:

| Điền gì | Lấy từ đâu | Thiếu thì |
|---|---|---|
| Thư mục project | người dùng chọn (đề xuất `e2e/`) | Hỏi |
| `BASE_URL` / `PROD_BASE_URL` | dò được ở bước 1, hoặc người dùng đưa | **Hỏi. Đừng đoán URL production** |
| Tiền tố biến môi trường | tên repo/app (VD `ACME_USER`) | Hỏi |
| Selector form đăng nhập | xem `reference/auth-setup.md` | Để `TODO` + `npm run check` đỏ có chủ đích |

Sinh: `playwright.config.ts` · `auth.setup.ts` · `auth.prod.setup.ts` ·
`checks/setup-check.spec.ts` · `fixtures/test-data.ts` · `tsconfig.json` ·
`package.json` (script `test`/`check`/`auth`/`test:prod`, **mọi script phải có
`--project`**) · `.env.example`.

Cách viết hai file `auth.*.setup.ts` — phần dễ sai nhất — ở
[reference/auth-setup.md](reference/auth-setup.md). Đọc nó trước khi viết.

**Không tự chạy `npm install`.** Nêu lệnh, chờ người dùng duyệt ở `/qa-setup`.

### C. Không phải app web, hoặc người dùng chưa muốn dựng → BỎ nhánh UI, không chặn

Ghi mục Playwright của `qa-config.md`: **`Trạng thái | KHÔNG DÙNG`**.

Từ đó `test-runner` xử nhánh UI **đúng như nhánh API khi chưa có Postman collection**:
case UI ghi `Blocked` + Note `[MANUAL] chưa dựng project e2e — chạy tay`, chặng vẫn
chạy tiếp, và tổng kết phải nêu rõ bao nhiêu case bị bỏ. Marker `[MANUAL]` khiến
`write_defects.py` không đẻ bug rác cho chúng.

Đây là trạng thái **hợp lệ**, không phải lỗi. Nhiều ticket không đụng UI, và một repo
chỉ có API thì nhánh UI vốn không có việc gì làm.

## Bước 3 — Chốt lại vào qa-config

Dù đi nhánh nào, mục Playwright phải phản ánh sự thật:

```
| Trạng thái | CÓ / CHƯA CÓ / KHÔNG DÙNG |
| Thư mục project | <đường dẫn thật, VD e2e/ hoặc telemax-e2e/> |
```

`Trạng thái` là `CÓ` mà thư mục không tồn tại → đó là **sai cấu hình**, không phải
"chưa có": DỪNG và báo. Không tự tạo, không đoán vị trí khác. Cùng quy ước với mục
Postman.

## Tự kiểm

- [ ] Đã dò trước khi hỏi — không hỏi thứ đọc được từ repo
- [ ] Nhánh A: đã **vá** config sẵn có, không ghi đè; diff đã đưa người dùng duyệt
- [ ] Config kết quả có `grep: /@prod-safe/` ở project prod
- [ ] `storageState` staging và production là **hai file khác nhau**
- [ ] Mọi script trong `package.json` có `--project`
- [ ] `PROD_BASE_URL` do người dùng đưa, không đoán
- [ ] Không hỏi mật khẩu qua chat; credential chỉ vào `.env`, `.env` đã gitignore
- [ ] `qa-config.md` mục Playwright đã ghi `Trạng thái` + đường dẫn thật
- [ ] Nhánh C: đã nêu rõ nhánh UI sẽ bị skip và bao nhiêu case ảnh hưởng
