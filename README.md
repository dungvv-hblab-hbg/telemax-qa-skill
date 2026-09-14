# Telemax QA Harness

Bộ agentic workflow cho quy trình QA của Telemax, chạy trên **Claude Code**:

```
ticket → checklist → test case Excel → chạy test (UI/API) → bug ClickUp → verify production
```

Mười một slash command, chín subagent, tám skill.

Người mới: đọc **[docs/TUTORIAL.md](docs/TUTORIAL.md)** — hướng dẫn từng bước, đầu vào
và đầu ra của mỗi chặng. Bản tiếng Anh: [docs/TUTORIAL.en.md](docs/TUTORIAL.en.md).

**Năm điểm dừng cho người**, không phải ba: sau checklist · sau khi áp phản hồi ·
sau file test case · sau sheet Defects · và duyệt cả lô bug trước khi tạo. Harness
không tự đi từ ticket tới bug mà không có ai gật.

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

Script copy `.claude/`, `.mcp.json` và append `gitignore.snippet` vào `.gitignore` của
repo đích. Repo đích đã có `.claude/` thì nó **dừng** thay vì ghi đè — merge tay, hoặc
`--force` nếu chắc chắn.

**Project e2e KHÔNG được copy.** Nó phụ thuộc app thật — URL, form đăng nhập, tên biến
môi trường, dữ liệu mẫu. Bê nguyên project của app khác sang thì mọi selector đều sai và
`npm run check` đỏ ngay từ phút đầu, mà người mới cài không biết vì sao. `/qa-setup` dò
repo đích, hỏi bạn, rồi đi một trong ba nhánh (skill `e2e-scaffold`):

| Dò thấy | Làm gì |
|---|---|
| Đã có `playwright.config.*` | **vá** config sẵn có cho đủ hàng rào của harness, không dựng thêm |
| Chưa có, là app web | scaffold theo app thật của repo đó |
| Không phải app web / dùng framework khác | bỏ nhánh UI — `qa-config` ghi `KHÔNG DÙNG`, `/qa-run` vẫn chạy nhánh API + manual |

Repo đích là **app Telemax khác, cùng form đăng nhập** thì `--with-e2e` copy nguyên bản
có sẵn cho nhanh.

### Bốn việc sau khi install

Mở Claude Code trong repo đó rồi:

```
/qa-setup
```

`/qa-setup` soát những gì đã có (Python + openpyxl, chromium, MCP Playwright,
LibreOffice, session e2e, Postman collection), **dựng project e2e hợp với repo này**
(dò trước, hỏi bạn, rồi mới làm), **xin duyệt một lượt** rồi mới cài, và liệt kê rõ
phần bạn phải tự làm.

Xong bước đó mới điền credential:

```bash
cd /đường/dẫn/repo-cua-ban
cp <project e2e>/.env.example <project e2e>/.env    # rồi điền URL + tài khoản test
```

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
/qa-setup                       một lần cho repo mới (cài + dựng project e2e)
/qa-doctor                      chẩn môi trường & cấu hình, ĐỌC-ONLY — chạy khi thấy lạ
/qa-status                      đang ở đâu, ticket nào dở dang, nên chạy gì tiếp
/qa-login                       đăng nhập vào profile MCP (chạy lại khi session hết hạn)

/qa-analyze TLM-2901
    spec-analyst (chỉ spec) ∥ code-analyst (chỉ code+diff) -> test-analyst tổng hợp
    -> .qa/TLM-2901/checklist_TLM-2901.md, kèm mục D6 "spec ≠ code"
    ▸ DỪNG — bạn review, ghi phản hồi vào section "Phản hồi review"

/qa-apply-feedback TLM-2901          (chỉ khi có ghi phản hồi — không sửa gì thì bỏ qua)
    áp phản hồi, giữ nguyên số thứ tự cũ
    ▸ DỪNG — review lại

/qa-write-cases TLM-2901
    checklist -> Excel 8 sheet + Traceability (AC -> TC)
    ▸ DỪNG — review file test case

/qa-run TLM-2901
    phân case UI/API/Manual -> chạy -> ghi kết quả + sheet Defects

/qa-file-bugs TLM-2901
    bug-proposer (đọc + chống trùng)
    ▸ DỪNG — bạn duyệt cả lô bug + assignee
    bug-filer (tạo bug -> ghi Bug ID về Excel -> upload Drive)

/qa-retro TLM-2901                   (tuỳ chọn — soi HARNESS, không soi sản phẩm)
    retro-analyst ×2 SONG SONG, hai model, không đọc bài của nhau
    -> command đối chiếu + chạy lại "Lệnh kiểm" của TỪNG phát hiện
    -> .qa/TLM-2901/retro-<ngày>.md

--- sau khi dev fix và deploy lên production ---

/qa-verify-prod TLM-2901
    chạy lại spec trên production bằng CODE, chỉ case gắn @prod-safe
```

Quên đang làm dở ticket nào?

```
/qa-status              # mọi ticket, mới nhất lên đầu
/qa-status TLM-2901     # chi tiết bảy chặng của một ticket
```

Mỗi chặng xong ghi một dòng vào `.qa/<ticket>/state.json`. Đó là **nhật ký, không
phải nguồn chân lý** — artifact trên đĩa mới là sự thật, nên `/qa-status` đối chiếu
cả hai và báo khi lệch (VD nhật ký nói đã sinh test case nhưng file `.xlsx` đã bị
xoá). `.qa/` đã gitignore nên trạng thái này **cục bộ theo máy**, không chia sẻ.

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
├─ commands/                      11 slash command — điểm vào, chờ người dùng được
├─ agents/                        9 subagent — chạy một chặng rồi kết thúc
│  └─ reference/                  tri thức chỉ một nhánh cần (Phase 1 browser)
├─ skills/                        8 skill — tri thức tĩnh, nạp theo nhu cầu
└─ scripts/
   ├─ qa-log.sh                   in tiến trình + ghi progress.log
   ├─ qa-py.sh                    chọn interpreter Python có openpyxl
   ├─ qa-config.sh                in ĐÚNG MỘT mục của qa-config.md
   ├─ qa-state.sh                 nhật ký trạng thái từng chặng, để resume
   ├─ seed-mcp-profile.mjs        đăng nhập, mật khẩu không qua transcript
   └─ smoke-scripts.sh            12 nhóm assertion tầng script, không cần MCP

.mcp.json                         đăng ký Playwright MCP (copy sang repo đích)
gitignore.snippet                 install.sh append vào .gitignore repo đích
telemax-e2e/                      project Playwright của CHÍNH repo này (dogfood).
                                  install.sh KHÔNG copy — /qa-setup dựng bản hợp
                                  với repo đích (skill e2e-scaffold)
install.sh                        cài vào repo đích
docs/TUTORIAL.md                  hướng dẫn dùng từng bước cho người mới
docs/TUTORIAL.en.md               bản tiếng Anh của TUTORIAL.md
docs/TESTING.md                   hướng dẫn test 4 tầng + bảng chẩn đoán lỗi
docs/DEAD-ENDS.md                 biên bản các ngõ cụt đã đi — đừng thử lại
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

- **Năm điểm dừng cho người**: sau checklist · sau khi áp phản hồi · sau file test
  case · sau sheet Defects · duyệt cả lô bug. Harness không tự đi từ ticket tới bug.
  Điểm duyệt lô bug nằm ở **command** chứ không trong agent — subagent không dừng
  chờ người được, nên hàng rào đặt trong agent là hàng rào hỏng.
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

Số dưới đây **đếm bằng tokenizer thật**, không ước theo ký tự. Đây là chi phí *trước
khi* đọc ticket, code, ảnh hay file Excel.

| | Tokens |
|---|---|
| Luôn nạp mọi session (frontmatter của skill + agent + command) | ~2.000 |
| `/qa-analyze` | ~11.000 |
| `/qa-apply-feedback` | ~8.500 |
| `/qa-write-cases` | ~10.500 |
| `/qa-run` — spec đã có (round 2 trở đi) | ~13.800 |
| `/qa-run` — còn case phải dò Phase 1 | ~19.100 |
| `/qa-file-bugs` | ~4.700 |
| `/qa-verify-prod` | ~3.600 |
| `/qa-retro` — hai bản review song song | ~7.700 |

Mỗi dòng = command body + agent body + skill được gọi + reference bắt buộc + **đúng
mục `qa-config` mà chặng đó cần**. Đọc lại bằng:

```bash
bash .claude/scripts/qa-config.sh <mục>     # đừng cat cả qa-config.md
```

> **Đừng ước bằng "ký tự ÷ 3,5".** Đo thật trên `.claude/*.md` ra **3,22 ký tự/token**,
> và `wc -c` còn phồng thêm ~20% nữa vì tiếng Việt có dấu là 2 byte/ký tự. Muốn con số
> đúng thì `wc -m` rồi chia 3,22 — hoặc chạy tokenizer.
>
> **Dịch harness sang tiếng Anh không đáng.** Đo trên các cặp câu dịch đối chiếu: chỉ
> rẻ hơn **~11%**, và có câu còn đắt hơn. Tokenizer đời mới cover tốt dấu tiếng Việt,
> còn tiếng Việt lại diễn đạt cùng ý bằng ít ký tự hơn — hai thứ gần triệt tiêu nhau.
> 11% đó không bù được rủi ro trôi nghĩa ở các hàng rào đã trả giá, và artifact đầu ra
> (checklist, sheet `Test Cases_VN`) vẫn phải là tiếng Việt.

Bốn quy tắc giữ nó ở mức này:

1. **Trùng lặp giữa các file không bao giờ cùng nạp là MIỄN PHÍ.** Sáu command không
   bao giờ cùng nạp; năm agent cũng vậy. Đừng gom thứ đã miễn phí vào file dùng chung —
   đó là cách file dùng chung phình lên rồi bị nạp ở mọi chặng.

   **Nhưng một command và agent nó gọi thì CÙNG một chặng**, và `qa-config.md` thì ở
   mọi chặng. Trùng lặp trong ba chỗ đó phải trả tiền hai, ba lần — đó là chỗ rò thật.
2. **Chi tiết chỉ dùng ở MỘT SỐ lần chạy thì vào `reference/`. Chi tiết dùng ở MỌI lần
   chạy thì để nguyên trong SKILL.md** — tách ra chỉ thêm một lượt Read mà không bớt
   token nào.

   Tách đúng: `common-validate` (mỗi lần chỉ đọc 1 trong 3 file) · `openpyxl-traps`
   (chỉ khi sửa script) · `agents/reference/phase1-browser.md` (chỉ khi còn case chưa
   có spec). Tách sai sẽ là mục A–H của `checklist-format` — nó luôn cần cả cụm.

   Quy tắc này áp cho **cả agent**, không riêng skill.
3. **`description` chỉ để discovery** — nó nạp vào mọi session.
4. **Tài liệu cho người ở ngoài `.claude/`.** README, CHANGELOG, docs/, evals/ không
   được agent nạp; mọi dòng thêm vào `.claude/` đều có giá ở mỗi lần chạy. Kể cả
   trong `qa-config.md`: câu mệnh lệnh *"đừng làm X"* ở lại, còn biên bản điều tra
   *vì sao* thì sang [docs/DEAD-ENDS.md](docs/DEAD-ENDS.md).

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
