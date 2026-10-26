# Hướng dẫn dùng Telemax QA Harness (từ đầu tới cuối)

*(English version: [TUTORIAL.en.md](TUTORIAL.en.md))*

Tài liệu này dành cho **người mới nhận harness** — QA hoặc dev kiêm QA, chưa từng chạy
lệnh `/qa-*` nào. Nó đi hết một vòng đời của một ticket: từ lúc cài vào repo, tới lúc
bug đã nằm trên ClickUp và bản deploy production đã được verify.

Đọc kèm khi cần: [README.md](../README.md) (tổng quan + ngân sách token) ·
[TESTING.md](TESTING.md) (test chính harness) · [DEAD-ENDS.md](DEAD-ENDS.md) (những
ngõ cụt đã đi, đừng thử lại).

---

## 0. Harness này làm gì cho bạn

Một chuỗi 11 slash command chạy trong **Claude Code**, biến một ticket ClickUp thành
bộ tài liệu QA hoàn chỉnh:

```
ticket ClickUp
   │  /qa-analyze          → checklist phân tích (.md)
   │  ▸ BẠN REVIEW
   │  /qa-apply-feedback   → checklist đã sửa
   │  /qa-write-cases      → test case Excel 8 sheet
   │  ▸ BẠN REVIEW
   │  /qa-run              → kết quả Pass/Fail + sheet Defects
   │  ▸ BẠN REVIEW
   │  /qa-file-bugs        → bug ClickUp + file lên Drive
   │  ▸ BẠN DUYỆT CẢ LÔ
   ▼
 deploy production
   │  /qa-verify-prod      → báo cáo verify sau deploy
```

**Năm điểm dừng cho người.** Harness không tự đi một mạch từ ticket tới bug. Mỗi điểm
dừng là chỗ bạn đọc artifact, sửa, rồi mới chạy lệnh tiếp theo.

**Ticket không có spec** (chỉ tiêu đề, hoặc tính năng cũ không ai tạo ticket) đi một
nhánh khác — `/qa-analyze` dừng lại hỏi bạn thay vì dựng checklist từ chính code. Xem
**bước 1b**.

Ba loại thành phần, để bạn hiểu output ở đâu ra:

| Loại | Là gì | Ví dụ |
|---|---|---|
| **Command** (`.claude/commands/`) | điểm vào, chạy trong session chính — **hỏi bạn được** | `/qa-run` |
| **Agent** (`.claude/agents/`) | subagent làm một chặng rồi kết thúc — **không dừng chờ bạn** | `test-runner` |
| **Skill** (`.claude/skills/`) | tri thức tĩnh, nạp theo nhu cầu | `common-validate` |

Mọi câu hỏi đều do **command** hỏi, và luôn gộp vào **một lượt** trước khi agent chạy.
Ba mức: **Chặn** (không có mặc định an toàn → phải trả lời) · **Xác nhận** (có mặc
định, nhưng mặc định vẫn là phán đoán) · **Tự quyết** (agent làm, nhưng phải liệt kê
trong tổng kết).

---

## 1. Chuẩn bị

### 1.1 Cần có trên máy

| Cần | Để làm gì | Kiểm |
|---|---|---|
| Claude Code | chạy command + agent | `claude --version` |
| Python 3 | `build.py`, `write_defects.py` (sinh/ghi Excel) | `python3 --version` |
| Node 20+ | project Playwright, MCP server | `node --version` |
| LibreOffice | `recalc.py` tính lại công thức Excel | `which soffice` |
| Connector ClickUp | đọc ticket, tạo bug | `/mcp` trong Claude Code |
| Connector Figma | đọc design (nếu ticket có link) | `/mcp` |
| Connector Google Drive | upload file test case (tuỳ chọn) | `/mcp` |

**LibreOffice thiếu không chặn** — file Excel vẫn đúng, chỉ là ô Summary trống cho tới
khi bạn mở bằng Excel một lần.

### 1.2 Cần biết trước

- **Mã ticket** dạng `TLM-XXXX`. Không có ticket thì `/qa-analyze` **dừng** và bảo bạn
  tạo trước (hoặc tạo giúp, sau khi bạn duyệt nội dung).
- **Môi trường ↔ nhánh** — chỗ hay nhầm nhất:

  | Môi trường | Build từ nhánh | Dùng ở chặng |
  |---|---|---|
  | **dashboard-stage** | `stage` | `/qa-run` — test chính |
  | **production** | `master` | `/qa-verify-prod` — verify sau deploy |

  Không phải `dev`. Test trên bản chưa merge lên `stage` vẫn ra số Pass, nên sai này
  **không tự lộ ra** — vì thế `/qa-run` bắt bạn xác nhận trước.

---

## 2. Cài vào repo của bạn (một lần)

### Bước 2.1 — chạy `install.sh`

```bash
git clone https://github.com/dungvv-hblab-hbg/telemax-qa-skill.git
cd telemax-qa-skill
./install.sh /đường/dẫn/repo-cua-ban --dry-run   # xem trước sẽ làm gì
./install.sh /đường/dẫn/repo-cua-ban             # làm thật
```

| Tham số | Khi nào dùng |
|---|---|
| `--dry-run` | in ra sẽ copy gì, không đụng file nào |
| `--force` | repo đích **đã có** `.claude/` và bạn chắc chắn muốn ghi đè |
| `--with-e2e` | repo đích là **app Telemax khác, cùng form đăng nhập** → copy luôn project Playwright có sẵn |

**Output:** repo đích có `.claude/`, `.mcp.json`, và `.gitignore` được append thêm
`gitignore.snippet`.

**Project e2e KHÔNG được copy mặc định.** Nó phụ thuộc app thật (URL, form login, biến
môi trường). Bê nguyên sang repo khác thì mọi selector sai mà người mới không hiểu vì
sao — `/qa-setup` sẽ dựng bản hợp với repo đích.

### Bước 2.2 — `/qa-setup` trong repo đích

Mở Claude Code **trong repo đích** rồi gõ:

```
/qa-setup
```

**Đầu vào:** không cần tham số.
**Nó làm gì:** soát trước (Python + openpyxl, chromium, MCP Playwright, LibreOffice,
Postman collection), **dò repo rồi hỏi bạn** để dựng project e2e, **xin duyệt một lượt
cho cả lô** rồi mới cài.

Ba nhánh cho project e2e:

| Dò thấy | Làm gì |
|---|---|
| Đã có `playwright.config.*` | **vá** config sẵn có cho đủ hàng rào harness |
| Chưa có, là app web | scaffold theo app thật của repo đó |
| Không phải app web / framework khác | bỏ nhánh UI — `qa-config` ghi `KHÔNG DÙNG`, `/qa-run` vẫn chạy nhánh API + manual |

**Đầu ra:** môi trường đã cài + danh sách rõ ràng **việc bạn phải tự làm**.

### Bước 2.3 — điền credential

```bash
cp <project e2e>/.env.example <project e2e>/.env
```

Rồi điền: `TELEMAX_USER` / `TELEMAX_PASS`, base URL, và (nếu verify prod)
`PROD_BASE_URL` + `TELEMAX_PROD_USER` / `TELEMAX_PROD_PASS`.

> **Mật khẩu chỉ nằm trong `.env`.** Harness không bao giờ hỏi mật khẩu qua chat, và
> không điền form login bằng MCP — `browser_type` để lộ mật khẩu nguyên văn trong
> transcript. Đăng nhập luôn đi qua script Node riêng.

### Bước 2.4 — điền `.claude/qa-config.md`

Đây là **điểm khai báo duy nhất** của harness. Mục còn `CHƯA ĐIỀN` sẽ chặn chặng dùng
nó — đáng kể nhất: **List/Space ClickUp chứa bug**, `/qa-file-bugs` dừng ở đó.

Đọc **theo mục**, đừng `cat` cả file:

```bash
bash .claude/scripts/qa-config.sh ticket       # tiền tố ticket, môi trường ↔ nhánh
bash .claude/scripts/qa-config.sh clickup      # list bug, tag, map priority, Drive
bash .claude/scripts/qa-config.sh playwright   # trạng thái, path spec, session, MCP args
bash .claude/scripts/qa-config.sh production   # URL prod, account, tag @prod-safe
bash .claude/scripts/qa-config.sh postman      # collection, environment, report
```

### Bước 2.5 — kiểm nhanh

```bash
bash .claude/scripts/smoke-scripts.sh
```

~30 giây, không cần MCP. Xanh hết là cài xong.

### Ba cái bẫy lúc cài

1. **Sửa `.mcp.json` xong phải thoát Claude Code và mở lại.** MCP đọc args lúc khởi
   động; sửa giữa session **không có tác dụng và không có tín hiệu nào báo**.
2. **Chỉ giữ MỘT bản Playwright MCP, ở scope project.** `claude mcp list` — có bản
   `local`/`user` thì `claude mcp remove playwright -s local`. Hai bản cùng tồn tại thì
   chỉ một thắng, và bản thắng có thể thiếu `--user-data-dir` → seed xong vẫn rơi về
   `/login` mà không lỗi nào báo.
3. **Đừng `pip install openpyxl` trần** (PEP 668 trên macOS Homebrew / Ubuntu 23+).
   Dùng venv — `/qa-setup` tự tạo:
   ```bash
   python3 -m venv .claude/.venv && .claude/.venv/bin/python -m pip install openpyxl
   ```

---

## 3. Chạy một ticket — từng bước

Ví dụ xuyên suốt: ticket **TLM-2901**.

Mẹo chung: mở **terminal thứ hai** để theo dõi tiến trình tới từng case:

```bash
tail -f .qa/TLM-2901/progress.log
```

---

### Bước 0 — `/qa-login` (khi cần)

| | |
|---|---|
| **Mục đích** | đăng nhập dashboard một lần, lưu session cho các lần `/qa-run` sau |
| **Khi nào** | lần đầu cài harness, hoặc `/qa-run` báo đang ở trang login |
| **Đầu vào** | không tham số · thêm `prod` nếu đăng nhập production. Credential lấy từ `.env` |
| **Đầu ra** | session lưu ở `.playwright-mcp-profile/` (đã gitignore) |

```
/qa-login
/qa-login prod
```

Cách chạy: command gọi `node .claude/scripts/seed-mcp-profile.mjs` — script đọc `.env`
trong **tiến trình riêng**, mật khẩu không đi qua context. Script **idempotent**: còn
session thì in `ALREADY_LOGGED_IN` rồi thoát.

Bạn phải làm gì:

- **`2FA_REQUIRED`** → tự nhập mã trong cửa sổ trình duyệt, xong gõ **`ok`**. Harness
  không nhận mã qua chat. (Tài khoản QA hiện tại đã tắt 2FA.)
- **Để nguyên cửa sổ trình duyệt mở** — `/qa-run` dùng lại chính cửa sổ đó.

> Thứ tự quan trọng: **seed TRƯỚC khi gọi bất kỳ tool MCP nào**. MCP mở browser là nó
> giữ lock trên thư mục profile, script không mở được nữa. Lỡ rồi thì thoát Claude Code
> và mở lại.

---

### Bước 1 — `/qa-analyze TLM-2901`

| | |
|---|---|
| **Mục đích** | biến ticket thành **checklist phân tích** để bạn review, và lộ ra chỗ **spec lệch code** |
| **Đầu vào** | mã ticket · (tuỳ chọn) link Figma · nhánh base để so diff |
| **Đầu ra** | `.qa/TLM-2901/checklist_TLM-2901.md` (kèm `analysis-spec.md` + `analysis-code.md`) |
| **Cần có** | connector ClickUp bật; repo có commit/nhánh của ticket (nếu muốn mục G) |

Harness sẽ hỏi (một lượt):

1. **Ticket ID** — suy từ tên nhánh thì vẫn hỏi xác nhận. **Dán thẳng spec vào chat →
   DỪNG**, bảo bạn tạo ticket trước (hoặc tạo giúp sau khi bạn duyệt nội dung).
2. **Nhánh base để so diff** — mặc định `stage`.
3. **Không tìm thấy commit/nhánh của ticket** — code chưa xong, hay ticket không đụng
   code? Câu trả lời quyết định checklist có mục G hay không.

Nó chạy ba agent:

```
spec-analyst  (CHỈ spec, cấm đọc code)  ─┐
                                         ├─►  test-analyst  ─►  checklist
code-analyst  (CHỈ code + git diff)     ─┘     (tổng hợp)
```

Tách đôi là **chủ ý**: một agent đọc cả hai sẽ mô tả *code đang làm gì* thay vì *spec
đòi gì*, và bug loại "code khác spec" trở nên vô hình. Chỗ hai bên lệch nhau thành mục
**D6** — sản phẩm giá trị nhất của chặng này.

Cấu trúc checklist (A → H):

| Mục | Nội dung |
|---|---|
| A | Nguồn đã đọc (ticket, Figma, commit) |
| B | Overview tính năng |
| C | Detail từng phần, chia theo màn hình |
| D | Bảng tổng hợp — D1 ràng buộc field, D2 message, **D6 spec ≠ code** |
| E / E2 | Bảng có điều kiện · **bảng AC** (nguồn của sheet Traceability) |
| F | Giả định & câu hỏi cho BA/Dev, kèm **độ tin** Cao/Trung/Thấp |
| G | Impact từ git diff *(chỉ khi có diff)* |
| H | Kế hoạch test *(chỉ khi dự kiến trên 15 case)* |

**Bạn phải làm gì sau đó:** mở file, đọc.

- Có chỗ cần sửa → ghi vào section **"Phản hồi review"** ở cuối file, tham chiếu **bằng
  số**: `#4 sai — maxlength thật là 100`. Lưu, rồi sang bước 2.
- Đọc thấy ổn → **bỏ qua bước 2**, chạy thẳng `/qa-write-cases`.

---

### Bước 1b — khi ticket **không có spec**

Không phải ticket nào cũng có mô tả và AC. Ba trạng thái hay gặp:

1. Ticket chỉ có tiêu đề — `"Test Order Module"`, 0 AC, không Figma
2. Tính năng làm từ lâu, không ai tạo ticket, không commit nào gắn mã
3. Ticket dev quên điền mô tả

`spec-analyst` đếm được (0 AC · mô tả dưới 30 từ · không Figma) thì **`/qa-analyze`
dừng lại và hỏi bạn**, thay vì dựng một checklist trông như thật.

> **Vì sao không để nó nặn spec từ code?** Test sinh từ code chỉ chứng minh *"code làm
> đúng cái code đang làm"*. Code chặn 50 ký tự → test "nhập 51 ký tự phải báo lỗi" →
> **Pass**. Nhưng nếu khách muốn 100, hoặc dev gõ nhầm 50 thay vì 500, test vẫn xanh và
> bug vẫn nằm nguyên. Cả bộ test xanh và không nói lên điều gì.

Câu hỏi bạn sẽ thấy — **một lượt duy nhất**, gộp cả phạm vi lẫn lựa chọn:

```
TLM-3210 "Test Order Module": 0 AC, mô tả 3 từ, không Figma, không commit gắn mã.
Không dựng được checklist test — mọi dòng sẽ phải suy từ chính code.

Phạm vi tôi thấy trong code:
[x] Màn tạo order   [x] Danh sách + filter   [x] Chi tiết   [ ] Job đồng bộ (không UI)

a) Săn bug ngay, không cần spec — mặc định
b) a + dựng spec ngược để bạn ký
c) Bạn bổ sung AC vào ticket, tôi chạy lại
```

Trả lời một dòng: `a`, hoặc `a, bỏ màn chi tiết` nếu muốn sửa phạm vi.

#### Hai tốc độ

| | Bạn tốn | Được |
|---|---|---|
| **a — săn bug** | 1 lượt duyệt bug | bug ngay. **Không có test case Excel, không có docs** |
| **b — + spec ngược** | thêm một lượt ký file | bug + spec cho module, dùng cho mọi lần sau |

Đường `a` gần như miễn phí về công của bạn. Chạy nó trước, thấy đáng thì bỏ công ký
spec sau — hai đường dùng chung artifact, không chạy lại từ đầu.

#### Nó chạy gì

```
ui-explorer   (dò staging qua trình duyệt, VẪN cấm đọc code)  ─┐
                                                               ├─►  test-analyst
code-analyst  (đã chạy xong ở trên, dùng lại)                 ─┘
```

Cần session còn sống → chạy `/qa-login` trước nếu chưa.

Vẫn là **hai vế độc lập** như luồng thường, chỉ đổi nguồn của vế thứ nhất: từ *ticket*
sang *hệ thống đang chạy*. Nên chỗ hai bên lệch nhau vẫn có nghĩa — chỉ đọc thành
"UI làm A, code làm B" (FE chặn 200 ký tự mà API nhận 5000, nút hiện ra mà API trả 403).

#### `findings_TLM-3210.md` — chỉ thứ sai **bất kể yêu cầu là gì**

Mỗi finding bắt buộc dẫn được **chuẩn nào bị vi phạm**. Không dẫn được thì nó không
phải bug, nó là câu hỏi. Năm nguồn chuẩn hợp lệ:

| Chuẩn | Bắt được gì |
|---|---|
| UI ≠ code | FE chặn 200 ký tự, BE không validate |
| `common-validate` | field bắt buộc không báo lỗi khi bỏ trống |
| Nhất quán trong phạm vi | màn A hiện giờ theo timezone user, màn B theo UTC |
| Nghiệp vụ telematics | thiết bị offline vẫn hiện toạ độ realtime |
| Nhánh lỗi / rỗng | API 500 → spinner quay mãi |

**Bạn phải làm gì:** đọc file, xoá dòng không đồng ý, rồi `/qa-file-bugs TLM-3210`.
Chặng này **không sinh test case Excel** — đúng thiết kế.

#### `spec-draft_TLM-3210.md` — chỉ khi chọn `b`

Mô tả mọi hành vi quan sát được, **điền sẵn phán đoán** để bạn chỉ phải sửa chỗ sai:

```
✅ 12. Danh sách order mặc định sắp theo ngày tạo giảm dần. [U1]
❌ 13. Ô Ghi chú chặn 200 ký tự ở FE, BE không validate. → F-01
❓ 14. Order ở trạng thái Shipped vẫn huỷ được, không cảnh báo. [U4]
      Hỏi: nghiệp vụ có cho huỷ sau khi đã giao không?
```

- `✅` / `❌` agent tự tin → bạn lướt
- `❓` **chỉ bạn biết** (con số nghiệp vụ, quy tắc miền, ý định) → chỗ phải nghĩ

Thường `❓` chiếm 15–20%. File 50 dòng thì bạn thật sự cân nhắc chừng 8–10 dòng.

**Bạn phải làm gì:** sửa dấu đầu dòng, điền câu trả lời cho `❓`, lưu, rồi
`/qa-apply-feedback TLM-3210`.

> **Lần đầu chạy: chọn MỘT màn hình thôi.** Nút cổ chai là lúc bạn ngồi ký, không phải
> lúc agent chạy. Một màn hình ra 30–60 dòng; cả module có thể 300 dòng, đọc tới dòng 80
> là mắt trôi. Module to thì chạy nhiều lượt, mỗi lượt một màn, artifact gom chung một
> thư mục.

---

### Bước 2 — `/qa-apply-feedback TLM-2901` *(chỉ khi có ghi phản hồi)*

| | |
|---|---|
| **Mục đích** | áp phản hồi của bạn vào checklist mà không làm hỏng tham chiếu |
| **Đầu vào** | section "Phản hồi review" trong checklist |
| **Đầu ra** | checklist đã cập nhật + section `## Đã xử lý (YYYY-MM-DD)` |

Chặng này chạy **thẳng trong session chính, không gọi subagent** — vì phản hồi mơ hồ là
đúng lúc cần hỏi lại, mà subagent thì không dừng chờ người được.

**Lệnh này có hai nhánh**, nó tự chọn theo file có trong `.qa/TLM-2901/`:

| File | Nhánh |
|---|---|
| `checklist_*.md` | áp phản hồi review — phần dưới đây |
| `spec-draft_*.md` | **ký duyệt spec ngược** (từ bước 1b): `✅` → mô tả ticket ClickUp · `❌` → finding chờ tạo bug · `❓` → comment hỏi BA. Ghi bản local trước, **xin bạn duyệt cả lô** rồi mới chạm ClickUp. Xong thì chạy lại `/qa-analyze` — lần này ticket đã có spec nên ra checklist bình thường |

Quy tắc nó tuân thủ:

- **Giữ nguyên số đã gán.** Mục mới append số tiếp theo ở **cuối**, không chèn vào giữa
  (cột Note của Excel trỏ theo số này). Mục bỏ thì `~~#11 (đã bỏ)~~`, không tái dùng số.
- Phản hồi trỏ số không tồn tại, hoặc mơ hồ (`#4 sai` mà không nói sai chỗ nào) →
  **hỏi bạn ngay**, không tự đoán.
- Nội dung phản hồi đã xử lý được **chuyển xuống** "Đã xử lý", **không xoá**.
- Section rỗng → nó nói thẳng là checklist giữ nguyên rồi kết thúc, không giả vờ đã cập
  nhật.

**Bạn phải làm gì:** review lại. Còn câu hỏi độ tin **Thấp** chưa trả lời thì **chưa nên**
viết test case — đó là những câu cần hỏi BA/khách.

---

### Bước 3 — `/qa-write-cases TLM-2901`

| | |
|---|---|
| **Mục đích** | biến checklist thành **bộ test case Excel** theo template Telemax |
| **Đầu vào** | `.qa/TLM-2901/checklist_TLM-2901.md` đã review |
| **Đầu ra** | `.qa/TLM-2901/TCs_<Module>_v<ver>.xlsx` — 8 sheet |
| **Cần có** | Python + openpyxl (qua `.claude/scripts/qa-py.sh`) |

Nó **chặn và hỏi** khi:

1. Checklist còn phản hồi chưa xử lý, hoặc mục F còn câu hỏi độ tin **Thấp**.
2. Có field cần ràng buộc thật (maxlength, min/max, định dạng) mà D1 không có, và F
   cũng không có giả định độ tin Cao **kèm căn cứ đọc được**. Nhãn "Cao" trơn không
   tính. **Không bao giờ lấy 255 hay số "chuẩn" nào làm thật.**
3. Có Expected Result cần message mà D2 không có.

Nó **xin xác nhận** (có mặc định): `cover.module` · `cover.version` · `cover.source` ·
`cover.create_date` · tên file output.

Cấu trúc file Excel:

```
Cover · Summary · Test Cases · Test Cases_VN · Common Validate ·
Defects & Follow-ups · Traceability · Assumptions & Questions
```

- Sheet **"Test Cases" (EN) là nguồn chân lý**; `Test Cases_VN` là bản dịch. Mọi công
  thức Summary đếm trên sheet EN.
- **Header chiếm row 1–5, data bắt đầu từ row 6.** 14 cột A→N: ID · Section · Type ·
  Priority · Title · Precondition · Steps · Data · Expected · Round 1 (Result, Bug ID) ·
  Round 2 (Result, Bug ID) · Note.
- ID **reset theo section**: `TC-A-001`, `TC-B-001`… (khác quy ước đánh số của checklist).
- Hai nhãn máy đọc được, đặt ở **đầu** cột Note: `[MANUAL] <lý do>` (phải chạy tay) và
  `[DATA-REQ] <điều kiện>` (tự động được nhưng cần dữ liệu môi trường).
- Sheet **Traceability** map AC → TC. Còn dòng `MISSING` nghĩa là **có AC chưa được phủ**
  — lỗ hổng thật, không phải cảnh báo cho vui.

**Bạn phải làm gì:** mở file, sửa/thêm/bớt case. Sửa checklist rồi muốn sinh lại thì
chạy lại chính lệnh này. Ổn rồi thì sang bước 4.

---

### Bước 4 — `/qa-run TLM-2901`

| | |
|---|---|
| **Mục đích** | chạy test UI (Playwright) + API (newman), ghi kết quả vào Excel, điền sheet Defects |
| **Đầu vào** | file `.xlsx` đã review · session đăng nhập · MCP Playwright |
| **Đầu ra** | Excel đã điền Result + Bug ID trống, sheet **Defects & Follow-ups**, file `.ts` export, `result.json` của newman, ảnh Phase 1 ở `.qa/TLM-2901/phase1/` |

Đây là chặng có nhiều cổng nhất. Nó **chặn** ở:

| # | Cổng | Vì sao |
|---|---|---|
| 1 | **Code đã lên `stage` chưa** (`git log origin/stage --grep=TLM-2901`) | chạy khi code chưa lên là đo bản cũ rồi ghi kết quả cho ticket mới — vẫn ra số Pass nên sai không tự lộ |
| 2 | **File `.xlsx` nào** | không tự lấy file mới nhất |
| 3 | **Ghi Round 1 hay Round 2** | ghi nhầm round làm `% Executed` sai |
| 4 | **Test data đặc biệt** (`[DATA-REQ]`) | không bịa dữ liệu, không tự cho là có |
| 5 | **MCP Playwright có và đúng một bản** | nhiều bản → hỏng im lặng |
| 6 | **Session đăng nhập** — seed trước, không probe bằng MCP | gọi MCP trước là tự khoá lock |
| 7 | **`.env` của project e2e** | thiếu thì dừng, không hỏi mật khẩu qua chat |
| 8 | **Postman** | `CHƯA CÓ` → skip nhánh API và nói rõ skip bao nhiêu case, không dừng cả chặng |

Về **Round** — nó phân ba trạng thái, không phải hai:

| Round 1 đang là | Đề xuất |
|---|---|
| trống hoàn toàn | ghi Round 1 |
| chỉ toàn `Blocked` / `Not Run`, Defects rỗng | **ghi đè Round 1** |
| đã có `Pass`/`Fail` thật | ghi Round 2 |

**Resume:** lần chạy trước đứt giữa chừng (hết session, bạn bấm dừng, máy sập) thì nó
nêu số liệu — *"Round 1 đã có kết quả cho 30/45 case. Tiếp tục từ case 31, hay chạy lại
cả 45?"* — mặc định **tiếp tục**.

Case được phân ba nhánh: **UI** (Playwright), **API** (newman/Postman), **Manual** (ghi
`Blocked` + `[MANUAL]`). Case UI chưa có spec thì đi qua **Phase 1** — agent dò element
bằng MCP (cửa sổ hiện lên, bạn nhìn thấy nó thao tác), rồi export thành
`telemax-e2e/tests/TLM-2901.spec.ts` để lần sau chạy bằng code.

**Bạn phải làm gì sau đó:** mở **file LOCAL** (không phải bản trên Drive), vào sheet
**Defects & Follow-ups**:

- Sửa **Actual** nếu agent mô tả chưa đúng.
- Case không muốn tạo bug → đặt **Fix Status = `Won't fix`**. **ĐỪNG XOÁ DÒNG** — xoá
  không giữ được ý định, case vẫn Fail và chưa có Bug ID nên lần sau nó quay lại.

---

### Bước 5 — `/qa-file-bugs TLM-2901`

| | |
|---|---|
| **Mục đích** | tạo bug ClickUp từ sheet Defects đã review, ghi Bug ID ngược về Excel, upload file lên Drive |
| **Đầu vào** | file `.xlsx` bản LOCAL đã review · list/space ClickUp · folder Drive |
| **Đầu ra** | bug trên ClickUp · Bug ID trong Excel · file trên Drive · `.qa/TLM-2901/bugs-proposed.json` |

Chặng này chạy **hai nửa, có điểm dừng duyệt ở giữa**:

```
bug-proposer  ->  BẠN DUYỆT CẢ LÔ  ->  bug-filer
(đọc, dựng, chống trùng)              (tạo, writeback, upload)
```

Điểm duyệt nằm ở **command** chứ không trong agent — subagent không dừng chờ người
được, nên hàng rào đặt trong agent là hàng rào hỏng.

Nó hỏi (một lượt):

1. Bạn review sheet Defects trên bản **LOCAL hay Drive**? Là Drive thì dừng — script
   chỉ đọc bản local.
2. File nào, nếu `.qa/TLM-2901/` có nhiều hơn một.
3. **List/Space ClickUp đích** (`qa-config.sh clickup`). Còn `CHƯA ĐIỀN` → hỏi bạn,
   không đoán list.
4. **Folder Google Drive đích** — hỏi luôn ở lượt này. Đưa folder = đồng ý upload.

Điểm dừng: nó trình một bảng

| TC ID | Tiêu đề bug | Priority | Assignee đề xuất | Trùng? |
|---|---|---|---|---|

kèm số dòng bị loại và lý do (`Won't fix`, đã có Bug ID, `[MANUAL]`), và **mọi bug nghi
trùng** với bug đang mở — với mỗi cái hỏi bạn muốn **dùng ID cũ** hay **tạo mới**.

**Bạn phải làm gì:** duyệt **một lần cho cả lô**. Trong cùng lượt trả lời có thể bỏ bớt
dòng, đổi assignee, đổi priority.

Danh sách rỗng (ticket sạch) → vẫn chạy bước **upload**. Ticket chạy sạch mà không
upload là mất đúng cái đáng chia sẻ nhất.

> Writeback **khoá theo TC ID, không theo số dòng**, và **append sau dòng cuối cùng có
> TC ID** chứ không lấp ô trống. Nhờ vậy tạo bug hỏng thì chạy lại an toàn.

---

### Bước 6 — `/qa-verify-prod TLM-2901` *(sau khi dev fix và deploy)*

| | |
|---|---|
| **Mục đích** | chạy lại spec của ticket trên production, phát hiện regression |
| **Đầu vào** | `telemax-e2e/tests/TLM-2901.spec.ts` · `.env` có `PROD_BASE_URL` + account prod |
| **Đầu ra** | `.qa/TLM-2901/prod-verify-<ngày>.md` |

Chạy bằng **code đã review, KHÔNG dùng MCP**, và **chỉ case gắn tag `@prod-safe`** (case
chỉ xem, không ghi dữ liệu). Hàng rào nghiêng về phía bỏ sót: bỏ sót một case còn sửa
được, sửa nhầm dữ liệu khách hàng thì không.

Nó **chặn** khi:

1. Không thấy commit của ticket trên `master` — và thấy rồi thì **vẫn hỏi** đã build/
   deploy xong chưa (merge và deploy là hai việc khác nhau).
2. `qa-config` ghi Playwright `KHÔNG DÙNG` → không có spec để verify, phải verify tay.
3. Chưa có file spec → bảo bạn chạy `/qa-run` trên staging trước.
4. **Không có case nào gắn `@prod-safe`** → dừng, bảo bạn gắn tag rồi quay lại. Không
   chạy suông rồi báo xanh.
5. `.env` thiếu `PROD_BASE_URL` hoặc account prod.

Trước khi chạy nó cho bạn biết **sẽ chạy bao nhiêu / tổng bao nhiêu case** và case nào bị
loại vì không gắn tag — để bạn không tưởng đã verify toàn bộ.

Báo cáo nêu rõ **regression** (staging Pass, prod Fail) — đó là sự cố production. Nó
**không tự tạo bug**, chỉ đề xuất.

---

## 4. Hai lệnh phụ trợ — dùng thường xuyên

### `/qa-status` — đang ở đâu

```
/qa-status              # mọi ticket, mới nhất lên đầu
/qa-status TLM-2901     # chi tiết sáu chặng của một ticket
```

Đọc-only. Mỗi chặng xong ghi một dòng vào `.qa/<ticket>/state.json`. Đó là **nhật ký,
không phải nguồn chân lý** — artifact trên đĩa mới là sự thật, nên `/qa-status` đối
chiếu cả hai và báo khi lệch (VD nhật ký nói đã sinh test case nhưng `.xlsx` đã bị xoá).

Bản đồ chặng → lệnh tiếp theo:

| Trạng thái | Chạy gì tiếp |
|---|---|
| chưa có gì | `/qa-analyze TLM-2901` |
| `analyze: done` | review checklist → `/qa-apply-feedback` (có sửa) hoặc `/qa-write-cases` (không sửa) |
| `apply-feedback: done` | `/qa-write-cases TLM-2901` |
| `write-cases: done` | review Excel → `/qa-run TLM-2901` |
| `run: in_progress` | `/qa-run TLM-2901` — cổng sẽ đề xuất `RESUME: có` |
| `run: done` | review sheet Defects (bản LOCAL) → `/qa-file-bugs TLM-2901` |
| `file-bugs: done` | xong chặng staging; sau deploy → `/qa-verify-prod TLM-2901` |
| bất kỳ chặng nào `failed` | chạy lại đúng chặng đó |

`.qa/` đã gitignore nên trạng thái này **cục bộ theo máy**, không chia sẻ được.

### `/qa-doctor` — thấy lạ thì chạy

Đọc-only: **không cài gì, không sửa file nào** (đó là việc của `/qa-setup`). Báo cáo ba
cột **Mục · Trạng thái · Việc cần làm**, chia rõ *chặn* / *không chặn nhưng phải biết* /
*việc bạn phải tự làm*.

Ba bệnh nó chẩn:

| Bệnh | Triệu chứng | Xử |
|---|---|---|
| **a. Trùng scope MCP** | cấu hình `.mcp.json` như không tồn tại, **không lỗi nào báo** | `claude mcp remove playwright -s local` (hoặc `-s user`), rồi **thoát Claude Code và mở lại** |
| **b. `.mcp.json` lệch `qa-config`** | `browser_wait_for` chết với `TimeoutError: Timeout 5000ms exceeded` (mặc định chỉ 5s) | bổ sung `--timeout-action 30000`, `--timeout-navigation 120000`, `--user-data-dir`, `--output-dir`; **không** có `--isolated` / `--storage-state`. Rồi mở lại session |
| **c. Rơi về `/login` mãi** | seed xong vẫn ở trang login | đừng lặp đăng nhập — nếu profile `LOCKED` mà `localStorage` chỉ có `app-version` thì đó là bệnh (a) hoặc (b), seed lại vô ích |

---

## 5. Artifact sinh ra ở đâu

```
.qa/TLM-2901/
├─ analysis-spec.md            phân tích chỉ từ spec (spec-analyst)
├─ analysis-code.md            phân tích chỉ từ code + diff (code-analyst)
├─ checklist_TLM-2901.md       ★ bạn review ở điểm dừng 1 và 2
│
│  — chỉ ở nhánh không-có-spec (bước 1b) —
├─ analysis-ui.md              quan sát UI đang chạy (ui-explorer)
├─ findings_TLM-2901.md        ★ thứ sai bất kể yêu cầu — bạn xoá dòng không đồng ý
├─ spec-draft_TLM-2901.md      ★ bạn ký ✅/❌/❓ từng dòng
├─ spec-signed_TLM-2901.md     bản ✅ đã ký, trước khi đăng lên ClickUp
├─ explore/                    ảnh chụp lúc dò UI
│
├─ TCs_<Module>_v1.0.xlsx      ★ bạn review ở điểm dừng 3 và 4
├─ bugs-proposed.json          danh sách bug ĐỀ XUẤT, chờ bạn duyệt
├─ prod-verify-<ngày>.md       báo cáo verify production
├─ result.json                 report của newman (nhánh API)
├─ phase1/                     ảnh bằng chứng lúc dò bằng MCP
├─ progress.log                tiến trình tới từng case — `tail -f` được
└─ state.json                  nhật ký chặng, cho /qa-status và resume

telemax-e2e/tests/TLM-2901.spec.ts    spec export từ Phase 1, một file / một ticket
.playwright-mcp-profile/              session của MCP (Phase 1)
telemax-e2e/playwright/.auth/         session của code (chạy spec) — TÁCH BIỆT
```

**Hai session là thiết kế, không phải lỗi.** Gộp còn một đã thử và không dùng được —
biên bản ở [DEAD-ENDS.md](DEAD-ENDS.md) §1. Đừng thử lại.

---

## 6. Ba cạm bẫy đã trả giá — đừng gỡ hàng rào

**Append, không lấp lỗ trống.** Dòng Defects mới ghi sau dòng *cuối cùng* có TC ID. Lấp
ô trống đầu tiên thì một dòng bị xoá ở giữa sẽ khiến lần fill sau đè mất các dòng bên
dưới, kèm Actual bạn đã review.

**Khoá theo TC ID, không theo số dòng.** Bạn chèn/xoá một dòng giữa `read` và
`writeback` là index lệch và Bug ID gắn nhầm case.

**Đừng dùng "xoá dòng" làm tín hiệu từ chối.** Muốn nói "case này không tạo bug", đặt
Fix Status = `Won't fix`.

---

## 7. Sự cố thường gặp

| Triệu chứng | Nguyên nhân hay gặp | Xử |
|---|---|---|
| `/qa-analyze` dừng, bảo tạo ticket | bạn dán spec vào chat thay vì đưa mã | tạo ticket ClickUp, hoặc để harness tạo giúp sau khi bạn duyệt nội dung |
| `/qa-analyze` dừng, hỏi a/b/c | ticket không có AC/mô tả/Figma | đây là **bước 1b**, không phải lỗi. Chọn `a` nếu chỉ cần bug, `b` nếu muốn có spec |
| Không có `checklist_*.md` mà `/qa-status` vẫn nói analyze xong | ticket đi nhánh không-có-spec | đúng thiết kế — nhánh đó ra `findings_*.md`, không ra checklist |
| `ui-explorer` dừng ngay, báo rơi về `/login` | session hết hạn | `/qa-login` rồi chạy lại |
| Còn bản ghi `QA-EXPLORE-*` trên staging | màn hình không cho xoá | `ui-explorer` báo ở mục A của `analysis-ui.md` — dọn tay |
| `/qa-run` dừng ở cổng 1 | chưa thấy commit của ticket trên `stage` | merge + build lên dashboard-stage rồi chạy lại |
| `browser_wait_for` timeout 5000ms | `.mcp.json` thiếu `--timeout-action` hoặc bị bản MCP scope khác thắng | `/qa-doctor` → bệnh (a)/(b), sửa rồi **mở lại Claude Code** |
| Seed xong vẫn ở `/login` | profile không được nạp (trùng scope MCP), không phải hết session | `/qa-doctor`, đừng lặp đăng nhập |
| Script seed báo profile bị chiếm | session này đã gọi tool MCP trước → giữ lock | thoát Claude Code, mở lại, chạy `/qa-login` **ngay từ đầu** |
| Ô Summary trong Excel trống | thiếu LibreOffice nên chưa recalc | mở file bằng Excel một lần, hoặc cài LibreOffice |
| `pip install openpyxl` fail `externally-managed-environment` | PEP 668 | dùng venv `.claude/.venv` |
| `/qa-file-bugs` dừng vì list ClickUp | `qa-config.md` còn `CHƯA ĐIỀN` | điền mục `clickup` trong `.claude/qa-config.md` |
| Nhánh API bị skip | `qa-config` mục `postman` là `CHƯA CÓ` | đúng thiết kế — thêm collection khi team có |
| Sheet Traceability còn `MISSING` | có AC chưa được phủ test case | bổ sung case, hoặc ghi rõ lý do không phủ |
| Sửa `.mcp.json` mà không thấy đổi gì | MCP đọc args lúc khởi động | thoát Claude Code và mở lại |

Bảng chẩn đoán đầy đủ (~25 triệu chứng): [TESTING.md](TESTING.md).

---

## 8. Tóm tắt một trang

```bash
# Cài (một lần cho repo mới)
./install.sh /repo-cua-ban
# trong repo đích:
/qa-setup
cp <project e2e>/.env.example <project e2e>/.env   # điền URL + account test
#   điền .claude/qa-config.md (list ClickUp)
bash .claude/scripts/smoke-scripts.sh
```

```
# Một vòng ticket
/qa-login                      # khi cần session
/qa-analyze TLM-2901           ▸ review checklist
/qa-apply-feedback TLM-2901    ▸ review lại (bỏ qua nếu không sửa gì)
/qa-write-cases TLM-2901       ▸ review file Excel
/qa-run TLM-2901               ▸ review sheet Defects (bản LOCAL, dùng Won't fix, đừng xoá dòng)
/qa-file-bugs TLM-2901         ▸ duyệt cả lô bug
# --- sau deploy production ---
/qa-verify-prod TLM-2901

# Bất cứ lúc nào
/qa-status [TLM-2901]          # đang ở đâu
/qa-doctor                     # thấy lạ thì chẩn
tail -f .qa/TLM-2901/progress.log
```

```
# Ticket KHÔNG có spec (bước 1b) — /qa-analyze sẽ tự hỏi a/b/c
/qa-login                      # cần session để dò UI
/qa-analyze TLM-3210           ▸ trả lời a hoặc b + chốt phạm vi

# chọn a — săn bug
                               ▸ xoá dòng không đồng ý trong findings_TLM-3210.md
/qa-file-bugs TLM-3210         ▸ duyệt cả lô bug.  HẾT (không có test case Excel)

# chọn b — + spec ngược
                               ▸ ký ✅/❌/❓ trong spec-draft_TLM-3210.md
/qa-apply-feedback TLM-3210    ▸ duyệt lô: spec lên ticket · ❌ thành bug · ❓ thành comment
/qa-file-bugs TLM-3210         ▸ duyệt cả lô bug
/qa-analyze TLM-3210           # chạy lại — giờ ticket đã có spec, ra checklist bình thường
```
