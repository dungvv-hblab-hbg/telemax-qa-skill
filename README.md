# Telemax QA Harness

Bộ agentic workflow cho quy trình QA của Telemax, chạy trên **Claude Code**:

```
ticket → checklist → test case Excel → chạy test (UI/API) → bug ClickUp → verify production
```

Tám slash command, năm subagent, bảy skill. Ba điểm dừng để người review — harness
không tự đi từ ticket tới bug mà không có ai duyệt.

---

## Cài đặt

### Yêu cầu

| Cần | Để làm gì | Kiểm |
|---|---|---|
| Claude Code | chạy command + agent | `claude --version` |
| Python 3 | `build.py`, `write_defects.py` | `python3 --version` |
| Node 20+ | project Playwright, MCP server | `node --version` |
| LibreOffice | `recalc.py` tính lại công thức Excel | `which soffice` |
| Connector ClickUp + Figma | đọc ticket, đọc design | `/mcp` trong Claude Code |

LibreOffice thiếu **không chặn** — file Excel vẫn đúng, chỉ là ô Summary trống tới khi
mở bằng Excel một lần.

### Cài vào repo của bạn

```bash
git clone https://github.com/<bạn>/telemax-qa-harness.git
cd telemax-qa-harness
./install.sh /đường/dẫn/repo-cua-ban            # thêm --dry-run để xem trước
```

Script copy `.claude/`, `.mcp.json`, `telemax-e2e/` và append `gitignore.snippet` vào
`.gitignore` của repo đích. Repo đích đã có `.claude/` thì nó **dừng** thay vì ghi đè —
merge tay, hoặc `--force` nếu chắc chắn.

### Bốn việc sau khi install

```bash
cd /đường/dẫn/repo-cua-ban
cp telemax-e2e/.env.example telemax-e2e/.env    # rồi điền BASE_URL / TELEMAX_USER / TELEMAX_PASS
```

Mở Claude Code trong repo đó rồi:

```
/qa-setup
```

`/qa-setup` soát những gì đã có (Python + openpyxl, chromium, MCP Playwright,
LibreOffice, session e2e, Postman collection), **xin duyệt một lượt** rồi mới cài, và
liệt kê rõ phần bạn phải tự làm.

Rồi điền **`.claude/qa-config.md`** — list/space ClickUp chứa bug đang là `CHƯA ĐIỀN`;
`/qa-file-bugs` sẽ dừng ở đó. Cuối cùng kiểm nhanh:

```bash
bash .claude/scripts/smoke-scripts.sh
```

### Ba cái bẫy lúc cài

**Sửa `.mcp.json` xong phải thoát Claude Code và mở lại.** MCP server đọc args lúc khởi
động; sửa giữa session **không có tác dụng và không có tín hiệu nào báo** — tool vẫn
chạy, vẫn trả kết quả, chỉ là bằng cấu hình cũ.

**Chỉ giữ MỘT bản Playwright MCP, ở scope project.** Máy đã cài ở scope `local`/`user`
thì gỡ (`claude mcp list` rồi `claude mcp remove playwright -s local`). Hai bản cùng tồn
tại thì chỉ một thắng, và bản thắng có thể không mang `--user-data-dir` lẫn timeout — khi
đó seed profile xong vẫn rơi về `/login` mà không có lỗi nào báo.

**Đừng chạy `pip install openpyxl` trần.** Trên macOS (Homebrew) và Ubuntu 23+ nó thất
bại với `externally-managed-environment` (PEP 668). Dùng venv chuẩn — `/qa-setup` tự tạo:

```bash
python3 -m venv .claude/.venv && .claude/.venv/bin/python -m pip install openpyxl
```

Mọi script Python trong harness gọi qua `.claude/scripts/qa-py.sh`, wrapper tự chọn
interpreter có openpyxl (`.claude/.venv` → `$QA_PYTHON` → `.qa/.venv` → `python3`).

---

## Dùng

```
/qa-setup                       một lần cho repo mới
/qa-login                       đăng nhập vào profile MCP (chạy lại khi session hết hạn)

/qa-analyze TLM-2901
    ticket + Figma + git diff -> .qa/TLM-2901/checklist_TLM-2901.md
    ▸ DỪNG — bạn review, ghi phản hồi vào section "Phản hồi review"

/qa-apply-feedback TLM-2901
    áp phản hồi, giữ nguyên số thứ tự cũ
    ▸ DỪNG — review lại

/qa-write-cases TLM-2901
    checklist -> Excel 8 sheet + Traceability (AC -> TC)
    ▸ DỪNG — review file test case

/qa-run TLM-2901
    phân case UI/API/Manual -> chạy -> ghi kết quả + sheet Defects

/qa-file-bugs TLM-2901
    chống trùng -> xin duyệt cả lô -> tạo bug -> ghi Bug ID về Excel

--- sau khi dev fix và deploy lên production ---

/qa-verify-prod TLM-2901
    chạy lại spec trên production bằng CODE, chỉ case gắn @prod-safe
```

Theo dõi tiến trình bằng terminal thứ hai:

```bash
tail -f .qa/TLM-2901/progress.log
```

Log xuống tới từng case (`case 12/45 · TC-B-003 · đang chạy (11 xong: 9P 2F)`), và phần
chạy bằng `npx playwright test` cũng đổ vào cùng file.

---

## Cấu trúc repo

```
.claude/                          thứ được copy sang repo đích
├─ qa-config.md                   ĐIỂM KHAI BÁO DUY NHẤT — nhánh, path, ClickUp list
├─ commands/                      8 slash command — điểm vào, chờ người dùng được
├─ agents/                        5 subagent — chạy một chặng rồi kết thúc
├─ skills/                        7 skill — tri thức tĩnh, nạp theo nhu cầu
└─ scripts/
   ├─ qa-log.sh                   in tiến trình + ghi progress.log
   ├─ qa-py.sh                    chọn interpreter Python có openpyxl
   ├─ seed-mcp-profile.mjs        đăng nhập, mật khẩu không qua transcript
   └─ smoke-scripts.sh            18 assertion tầng script, không cần MCP

.mcp.json                         đăng ký Playwright MCP (copy sang repo đích)
gitignore.snippet                 install.sh append vào .gitignore repo đích
telemax-e2e/                      project Playwright (copy sang repo đích)
install.sh                        cài vào repo đích
docs/TESTING.md                   hướng dẫn test 4 tầng + bảng chẩn đoán lỗi
evals/                            5 kịch bản đo từng chặng (tài liệu, không copy)
scripts/                          CI: lint-harness.py, check-gitignore.sh
CHANGELOG.md
```

### Vì sao chia command / agent / skill

- **Command** chạy trong session chính nên **chờ người dùng được** — cổng đầu vào, xin
  duyệt, chờ nhập 2FA đều nằm ở đây.
- **Agent** là subagent: chạy một chặng rồi kết thúc, **không dừng chờ giữa chừng**.
  Agent mà "hỏi rồi đợi" thì thực chất là đứng im. Nên agent chỉ phát hiện và báo.
- **Skill** là tri thức tĩnh, không quyết định luồng. Nạp theo nhu cầu nên không tốn
  context ở những chặng không cần.

Không có `.claude/rules/`: rule không có `paths:` frontmatter được nạp vào **mọi
session** trong repo. Tri thức chỉ dùng cho một tác vụ thì để ở `skills/`.

---

## Nguyên tắc đã cài xuyên suốt

- **Ba điểm dừng review**: sau checklist, sau khi áp phản hồi, sau file test case.
  Harness không tự đi từ ticket tới bug.
- **Thiếu đầu vào thì hỏi, không đoán.** Mỗi command mở đầu bằng cổng đầu vào, gộp mọi
  câu hỏi vào một lượt. Ba mức: *chặn* (không có mặc định an toàn), *xác nhận* (có mặc
  định nhưng mặc định vẫn là phán đoán), *tự quyết* (chuyên môn agent, phải liệt kê
  trong tổng kết).
- **Đo đúng bản đang chạy.** feature → `stage` (dashboard-stage, test ở đây) → `master`
  (production, verify ở đây). `/qa-run` và `/qa-verify-prod` đều kiểm `git log` xem code
  đã lên đúng nhánh chưa — test trên bản cũ vẫn ra số Pass nên sai này không tự lộ ra.
- **Production chỉ đọc.** Chặng verify chạy bằng code đã review, không dùng MCP, và chỉ
  chạy case gắn `@prod-safe`. Hàng rào nghiêng về phía bỏ sót: bỏ sót một case còn sửa
  được, sửa nhầm dữ liệu khách hàng thì không.
- **Con người bấm nút cuối.** Tạo bug, upload Drive, cấp quyền MCP đều chờ duyệt — xin
  duyệt một lần cho cả lô, không hỏi từng cái.
- **Truy vết hai chiều**: AC → TC (sheet Traceability) và TC ID → test tự động → kết quả
  → bug.
- **Artifact viết cho tester đọc**, không phải cho dev: câu ngắn, thao tác nhìn thấy
  được, không `H1`/`endpoint`/tên class trong phần UI.
- **Có ticket rồi hãy chạy.** Dán spec thẳng vào chat thì `/qa-analyze` dừng và bảo tạo
  ticket trước, hoặc tạo giúp trên ClickUp rồi chạy tiếp luôn.

---

## Ba cạm bẫy đã trả giá — đừng gỡ hàng rào

**Append, không lấp lỗ trống.** Dòng Defects mới ghi sau dòng *cuối cùng* có TC ID. Lấp
ô trống đầu tiên thì một dòng bị xoá ở giữa sẽ khiến lần fill sau đè mất các dòng bên
dưới, kèm Actual người dùng đã review.

**Khoá theo TC ID, không theo số dòng.** Người dùng chèn/xoá một dòng giữa `read` và
`writeback` là index lệch và Ticket ID gắn nhầm case.

**Đừng dùng "xoá dòng" làm tín hiệu từ chối.** Muốn nói "case này không tạo bug", đặt
Fix Status = `Won't fix`. Xoá dòng không giữ được ý định: case vẫn Fail và chưa có Bug
ID nên lần fill sau nó quay lại.

---

## Ngân sách token

Tiếng Việt ~3.5 ký tự/token. Đây là chi phí *trước khi* đọc ticket, code hay file Excel.

| | Tokens |
|---|---|
| Luôn nạp mọi session (description của skill + agent + command) | ~1.400 |
| `/qa-analyze` | ~10.100 |
| `/qa-write-cases` | ~9.000 |
| `/qa-run` | ~11.100 |
| `/qa-file-bugs` | ~5.100 |
| `/qa-verify-prod` | ~3.400 |

Bốn quy tắc giữ nó ở mức này:

1. **Trùng lặp giữa các file không bao giờ cùng nạp là MIỄN PHÍ.** Mỗi chặng chỉ nạp một
   command và một agent. Đừng gom thứ đã miễn phí vào file dùng chung — đó là cách file
   dùng chung phình lên rồi bị nạp ở mọi chặng.
2. **Chi tiết vào `reference/`, SKILL.md làm mục lục.**
3. **`description` chỉ để discovery** — nó nạp vào mọi session.
4. **Tài liệu cho người ở ngoài `.claude/`.** README, CHANGELOG, docs/, evals/ không
   được agent nạp; mọi dòng thêm vào `.claude/` đều có giá ở mỗi lần chạy.

---

## Test

Xem [docs/TESTING.md](docs/TESTING.md) — 4 tầng, phép thử phá hoại, bảng chẩn đoán ~25
triệu chứng thường gặp.

```bash
bash .claude/scripts/smoke-scripts.sh     # tầng 0, không cần MCP, ~30 giây
python3 scripts/lint-harness.py           # frontmatter, link, JSON, cú pháp script
bash scripts/check-gitignore.sh           # gitignore.snippet thật sự ignore
```

CI chạy cả ba trên mỗi push, cộng typecheck project Playwright.

Tầng 2 là 5 kịch bản trong `evals/`, chạy tay trong Claude Code. **Chạy baseline trước**
(cùng câu hỏi trong thư mục không có `.claude/`) — không có baseline thì mọi cải thiện
chỉ là cảm giác.

---

## Trạng thái

Đã verify: `build.py` (validate, style, Traceability, overflow section),
`write_defects.py` (fill/read/writeback, `Won't fix`, `[MANUAL]`, lệch số dòng), template
8 sheet với 12 slot RESULT BY SECTION, và `npm run check` chạy thật trên dashboard-stage.

Chưa chạy trên dữ liệu thật của team: `postman-api-test` (chưa có collection — nhánh API
đang skip theo thiết kế) và một phần `playwright-export` (convention `.ts` sẽ cần tinh
sau vài lần chạy Phase 1 thật).

Chưa có kết quả baseline nào của tầng 2 được ghi lại.
