# Changelog — Telemax QA Harness

## v3.0 — 2026-09-02

Tái cấu trúc thành **repo GitHub độc lập**. Không đổi hành vi harness; đổi cách phân phối.

### Bố cục
Trước đây bộ này là một thư mục để copy tay vào repo đích, và bản thân nó không phải repo
chạy được. Nay:

- `.claude/`, `.mcp.json`, `telemax-e2e/` ở **gốc repo** — vừa là thứ được phân phối, vừa
  khiến chính repo harness là một môi trường chạy được (dogfood).
- `gitignore.snippet` — bản `.gitignore` dành cho **repo đích**, tách khỏi `.gitignore`
  của chính repo harness. Trước đây một file phải gánh hai vai.
- `docs/TESTING.md`, `evals/`, `CHANGELOG.md` — tài liệu, **không** copy sang repo đích.
- `scripts/` — công cụ CI, không phải phần của harness.

### `install.sh`
Copy `.claude/`, `.mcp.json`, `telemax-e2e/`, append `gitignore.snippet`. Có `--dry-run`
và `--force`. **Không ghi đè `.claude/` đang có** — dừng và hướng dẫn merge tay, vì repo
đích có thể đã dùng Claude Code cho việc khác. Kết thúc bằng bốn việc tiếp theo theo đúng
thứ tự, kèm nhắc phải thoát Claude Code sau khi sửa `.mcp.json`.

Đã test: cài vào repo git trống → smoke test xanh trong repo đích, `git check-ignore`
đúng, cài lần hai bị chặn.

### CI — ba job, đều chạy thật trước khi commit
- **smoke**: dựng `.claude/.venv`, cài openpyxl, LibreOffice, chạy 18 assertion.
- **e2e-typecheck**: `tsc --noEmit` + `playwright test --list` (bắt được đúng loại lỗi
  `testDir` ở v2.31 — chỉ nhìn tổng số test thì không thấy project nào vắng mặt).
- **lint**: `scripts/lint-harness.py` + `scripts/check-gitignore.sh`.

### `lint-harness.py` — mỗi phép kiểm ứng với một lỗi đã xảy ra thật
Frontmatter parse được và `name` khớp tên thư mục · `description` ≤ 1024 ký tự và
SKILL.md ≤ 500 dòng · link tương đối không gãy · JSON parse được · `bash -n` /
`node --check` / `py_compile` · và `.mcp.json` **không được có** `--isolated`
/`--storage-state`, phải có `--user-data-dir` + `--timeout-action`.

Chạy lần đầu nó bắt ngay một link gãy do việc chuyển `TESTING.md` sang `docs/` — đúng
loại lỗi mà tái cấu trúc thư mục hay sinh ra.

### `check-gitignore.sh`
Dựng repo git tạm, `touch` 7 file mẫu, xác nhận `git check-ignore` khớp cả 7 **và**
negation `!*.example.postman_environment.json` vẫn hoạt động. Đây là hàng rào cho đúng
lỗi comment-cuối-dòng đã làm cả `.gitignore` vô hiệu ở v2.31.

### README
Viết lại cho người đọc trên GitHub: yêu cầu môi trường dạng bảng · cài đặt bằng
`install.sh` · bốn việc sau khi cài · **ba cái bẫy lúc cài** (restart sau khi sửa
`.mcp.json`, xung đột scope MCP, PEP 668) · 8 command · cấu trúc repo · vì sao chia
command/agent/skill · nguyên tắc xuyên suốt · ba cạm bẫy đừng gỡ hàng rào · ngân sách
token · cách test · trạng thái thật (cái gì đã verify, cái gì chưa).

Mọi số liệu trong README được kiểm lại bằng script: 8 command, 5 agent, 7 skill, và mọi
đường dẫn được nhắc tới đều tồn tại.

## v2.33 — 2026-09-02

Đối chiếu 9 issue của báo cáo TLM-3099. Bảy cái đã có trong v2.31–v2.32; hai cái xử lý ở
bản này.

| # | Trạng thái trong bản này |
|---|---|
| 1 `fill()` ở `seed-mcp-profile.mjs` | đã fix v2.31; bản này thêm: bỏ luôn 20s chờ vô ích khi profile đã có session |
| 2 `fill()` ở `auth.setup.ts` | đã fix v2.31 (cả `auth.prod.setup.ts`) |
| 3 `testDir` project `setup` | đã fix v2.31 — **và cả `setup-prod`**, báo cáo chỉ nêu `setup` |
| 4 `.gitignore` comment inline | đã fix v2.31, kiểm bằng `git check-ignore` 7/7 |
| 5 `openpyxl` chỉ có trong venv | đã fix v2.32 bằng `qa-py.sh`; bản này nhận thêm `.qa/.venv` |
| 6 `auth:headed` | đã có từ v2.19, kèm `auth:prod`, `auth:prod:headed` |
| 7 `evals/smoke-scripts.sh` | đã fix v2.31 — chuyển vào `.claude/scripts/` |
| 8 cổng kiểm `/qa-setup` | đã fix v2.31–v2.32, đủ 4 |
| 9 `RESULT BY SECTION` 4 slot | **fix thật ở bản này: 4 → 12 slot** |

### #9 — nới template từ 4 lên 12 slot
Sửa được `assets/template.xlsx`, không chỉ ghi doc. Hai lần đầu hỏng, đáng ghi lại:

- **`openpyxl.insert_rows` để lại lỗ** — mất slot ở hai dòng, và hai dòng của
  RESULT BY PRIORITY mất công thức cột G.
- **Merged cell chặn ghi đè** — LEGEND có `B33:J33`…, ghi vào đó ném
  `MergedCell object attribute 'value' is read-only`, và đó cũng là nguyên nhân lần đầu
  mất nội dung.

Cách chạy được: chụp công thức mọi dòng phía dưới ở dạng **template hoá theo số dòng**,
gỡ hết merge trong vùng bị dịch, dựng lại toàn vùng từ dòng 21, rồi merge lại ở vị trí đã
dịch. Ghi vào `reference/openpyxl-traps.md` cho lần sau.

Kiểm bằng dữ liệu thật: ticket **6 section / 12 case** → `sections_written: 6`,
`section_slots_in_template: 12`, không còn overflow; sau recalc RESULT BY SECTION cộng
đúng Total = 12, RESULT BY PRIORITY không vỡ sau khi dịch dòng, 12 merge và 3 dropdown còn
nguyên. Hồi quy bộ 2 section cũ vẫn đúng, smoke 18/18 xanh.

`SKILL.md` và `testcase-writer` đổi từ "tối đa 4" sang "tối đa 12", kèm câu: 12 là thoải
mái cho gần như mọi ticket nên **chia theo cấu trúc thật, đừng nghĩ tới giới hạn**.

### #5 — nhận `.qa/.venv` đang có
Repo của bạn đã dựng venv ở `.qa/.venv`; resolver nhận nó (ưu tiên sau `.claude/.venv` và
`$QA_PYTHON`) để không phải dựng lại. Nhưng `/qa-setup` sẽ nêu rằng nên chuyển sang
`.claude/.venv`: `.qa/` là thư mục **kết quả theo ticket** — dọn `.qa/` là mất venv.

### Một chỗ tôi phân loại khác báo cáo
Báo cáo xếp "thiếu `telemax-e2e/playwright/.auth/user.json`" là **chặn**. Thực tế project
`chromium` khai `dependencies: ['setup']`, nên Playwright tự chạy `auth.setup.ts` và tạo
lại `user.json` — miễn là `.env` có credential. Nên nó **không chặn**; cái chặn thật là
thiếu `.env`. `/qa-setup` giữ phân loại này.

## v2.32 — 2026-09-02

Issue #8 đúng, và nguyên nhân gốc nằm ở doc của tôi.

### `pip install openpyxl` THẤT BẠI trên máy hiện đại
Kiểm trực tiếp: `python3 -m pip install openpyxl` trả về
`error: externally-managed-environment` (PEP 668) — đúng như trên macOS Homebrew và
Ubuntu 23+. `SKILL.md` và `README.md` đều ghi mỗi câu `pip install openpyxl`, tức là
**hướng dẫn một lệnh không chạy được**.

Hệ quả đúng như báo cáo mô tả: session nào cũng phải tự xoay, và mỗi session xoay một
kiểu — sinh ra `.qa/.venv` và `~/.qa-venv` mà session sau không biết đường tìm. Đặt venv
trong `.qa/` còn tệ hơn: đó là thư mục **kết quả theo ticket**, không phải chỗ để tooling.

### Lỗi thứ hai báo cáo chưa nêu: `python` vs `python3`
9 lệnh trong doc gọi `python scripts/build.py`. **macOS không có `python`**, chỉ có
`python3` — nên các lệnh đó fail ngay cả khi openpyxl đã cài đúng.

### Fix: một điểm phân giải duy nhất
Thêm `.claude/scripts/qa-py.sh`. Mọi lệnh Python trong harness (9 chỗ, ở 5 file) đổi
sang gọi qua nó. Thứ tự ưu tiên: `.claude/.venv/bin/python` → `$QA_PYTHON` → `python3`
hệ thống nếu import được openpyxl → thất bại kèm đúng ba cách cài.

Đã test 6 nhánh: dùng venv chuẩn, dùng `QA_PYTHON`, dùng python3 hệ thống, **venv tồn
tại nhưng thiếu openpyxl thì tự rơi xuống nhánh sau chứ không chết**, không có gì cả thì
báo lỗi rõ, và **giữ nguyên exit code** — quan trọng vì `build.py` dùng 0/1/2 làm tín hiệu.

`smoke-scripts.sh` cũng chuyển sang gọi qua resolver.

### Kèm theo
- `/qa-setup` thêm cổng kiểm Python + openpyxl, và tạo `.claude/.venv` khi thiếu. Ghi rõ
  **đừng dựng venv ở chỗ khác**; đã có venv riêng thì trỏ `QA_PYTHON` vào nó.
- `.gitignore` thêm `.claude/.venv/`.
- `TESTING.md` thêm hai dòng chẩn đoán: `ModuleNotFoundError: openpyxl`, và "có nhiều
  venv lạc".

## v2.31 — 2026-09-02

Sửa theo báo cáo chạy trọn luồng TLM-3099. Bốn lỗi thật trong file tôi viết.

### `.gitignore` — KHÔNG dòng nào có tác dụng
gitignore **không hỗ trợ comment cuối dòng**, nên `.qa/    # ghi chú` là một pattern rác.
Cả file đang viết kiểu đó → `.qa/`, `.playwright-mcp-profile/`, `playwright/.auth/`,
`result.json`, `*.postman_environment.json` **đều không được ignore**. Nguy hiểm nhất là
hai cái cuối: file env chứa token và report có thể lọt vào commit.

Đã viết lại với comment trên dòng riêng, và **kiểm bằng `git check-ignore`** trong repo
thử: 7/7 pattern khớp đúng. Thêm cảnh báo ngay đầu file để không tái diễn.

### `playwright.config.ts` — `npm run auth` báo "No tests found"
`auth.setup.ts` nằm ở **gốc project**, không trong `testDir` mặc định `./tests`, nên
project `setup` không tìm thấy gì. Thêm `testDir: '.'` cho cả `setup` và `setup-prod`.
Kiểm lại: mỗi project thấy đúng 1 test, tổng 10 test trong 4 file.

Lỗi này tôi bỏ sót ở lần verify trước vì chỉ nhìn tổng số test mà không soi từng project.

### `fill()` không kích hoạt Blazor bind — nút Login giữ `disabled`
Blazor bind qua event trình duyệt; `fill()` đặt value một nhát, không sinh chuỗi event
mà `EditContext` cần. Sửa ở cả ba chỗ (`seed-mcp-profile.mjs`, `auth.setup.ts`,
`auth.prod.setup.ts`): `click()` → `pressSequentially(delay: 30)` → `blur()` → chờ nút
enabled rồi mới click.

`seed-mcp-profile.mjs` không chạy trong test runner nên không dùng `expect` — poll thủ
công với thông báo lỗi nói đúng nguyên nhân, thay vì nuốt vào timeout của `click()`.

**Kèm một lỗ hổng kiểm chứng cùng gốc:** profile có session cũ thì `/login` redirect
thẳng vào `/`, script in `LOGGED_IN` **mà chưa hề gõ ký tự nào** — che mất đúng bug
trên. Nay tách riêng `ALREADY_LOGGED_IN`, và nếu vẫn ở `/login` mà không thấy ô email
thì báo lỗi thay vì đi tiếp.

### `evals/smoke-scripts.sh` — đường dẫn không tồn tại sau khi cài
README bảo copy `.claude/`, `.mcp.json`, `.gitignore` — **không** copy `evals/`. Nhưng
`/qa-setup` lại gọi `bash evals/smoke-scripts.sh`. Chuyển script vào
`.claude/scripts/smoke-scripts.sh` để nó đi theo harness; `evals/` giữ nguyên là tài
liệu, không bắt buộc copy. Đã sửa đường dẫn nội bộ và chạy lại: xanh 18/18.

### `/qa-setup` — thêm ba cổng kiểm, đều KHÔNG chặn nhưng phải báo trước
- **LibreOffice** (`recalc.py`): thiếu thì Summary trống tới khi mở bằng Excel. Không
  kiểm thì lỗi chỉ lộ ở cuối `/qa-write-cases`, sau khoảng 11 phút chạy.
- **`telemax-e2e/playwright/.auth/user.json`**: điều kiện của mọi lần `npx playwright test`.
- **Postman collection**: xác nhận trước rằng nhánh API sẽ bị skip, thay vì phát hiện
  giữa `/qa-run`.

### Giới hạn 4 section — ghi rõ thay vì để công cụ áp đặt
Bảng RESULT BY SECTION chỉ có 4 slot; vượt thì `build.py` thoát code 2. Nay ghi thẳng
vào `testcase-template` và `testcase-writer`: **chia theo cấu trúc thật của tính năng
trước**, vượt thì gộp màn hình gần nhau và ghi lý do vào sheet Assumptions — hoặc nới
bảng trong template, kèm cảnh báo phải tự dịch tham chiếu công thức của các bảng bên dưới.

## v2.30 — 2026-08-30

Giảm thời gian tải trang. Quy tắc reset ở v2.22 đúng về mặt sạch trạng thái nhưng
**không cân với chi phí**: nó bắt `browser_navigate` hai lần cho mỗi case, mà mỗi lần
là `page.goto()` — tải lại document, tải và parse lại bundle JS, dựng lại cả app,
tức 10–30 giây. Bộ 45 case thành 90 lần tải cứng, riêng phần chờ đã hơn 15 phút.

### Reset ba mức, dùng mức nhẹ nhất còn hiệu quả
| Mức | Khi nào | Làm gì | Chi phí |
|---|---|---|---|
| 1 | case sau **cùng màn hình** | đóng modal, xoá filter, cuộn lên đầu | ~0 |
| 2 | case sau **khác màn hình** | điều hướng **trong app** (bấm menu), không `goto` | <1s |
| 3 | mức 2 không sạch, hoặc trạng thái kẹt | `goto` về `/` rồi `goto` trang case | 10–30s |

Mức 2 vẫn ép đổi route thật nên component remount — đủ sạch cho hầu hết trường hợp mà
không tải lại bundle. Thứ **không** đủ vẫn là đi thẳng `browser_navigate` tới đúng URL
đang đứng: SPA có thể không remount.

Sau reset mức 1/2 phải kiểm màn hình đã ở trạng thái xuất phát; sót modal/filter thì
nâng lên mức 3. Nghi ngờ thì lên mức cao hơn — một `goto` thừa tốn 20 giây, một case sai
vì trạng thái bẩn tốn cả buổi truy.

### Gom case theo màn hình
- `test-runner` thêm **bước 0**: sắp case UI gom theo màn hình trước khi chạy, để phần
  lớn reset rơi vào mức 1.
- `testcase-writer` và `checklist-format`: chia section/mục C theo **màn hình**, không
  theo loại kiểm thử. `A. Devices List` chứ không phải `A. Validation` — loại kiểm thử
  đã có cột Type để lọc, không cần dùng section phân loại lần nữa. Chia sai cách thì
  mỗi case nhảy một màn hình khác và buộc điều hướng lại.

## v2.29 — 2026-08-30

Báo tiến trình xuống tới **từng case**. Trước đây chỉ log theo bước, mà bước `3/6`
(chạy nhánh UI) có thể mất hàng chục phút — màn hình đứng im suốt thời gian đó và trông
y như treo, người dùng không biết nên chờ hay nên kill.

- **Trước mỗi case**, một dòng kèm số đếm dồn:
  `case 12/45 · TC-B-003 · đang chạy (11 xong: 9P 2F)`.
  Log ở lúc bắt đầu và gộp kết quả các case trước vào cùng dòng — không log thêm dòng
  nữa khi case kết thúc, tốn gấp đôi mà không thêm thông tin.
- Ba chỗ khác cũng hay bị tưởng treo, log trước khi làm: mở trình duyệt lần đầu
  (`>30s`), trước mỗi lô `npx playwright test`, và đánh dấu hàng loạt case Manual
  (một dòng gộp kèm lý do).
- Lệnh `npx playwright test` nay chạy với `--reporter=line` và `tee` vào
  `.qa/<ticket>/progress.log`, nên `tail -f` thấy từng case chạy xong thay vì im lặng
  tới lúc lệnh kết thúc. Áp cho cả `test-runner` lẫn `prod-verifier`. Đã kiểm đường dẫn
  tương đối `../.qa/...` chạy đúng khi `cd telemax-e2e`.

**Giá:** một lệnh bash mỗi case, bộ 45 case tốn khoảng 1.800 token. Đó là lý do log
đúng một dòng mỗi case và không log từng thao tác bên trong case.

## v2.28 — 2026-08-30

Chỉ giữ MCP Playwright ở **scope project**.

Máy có thêm server `playwright` ở scope `local` hoặc `user` là xung đột: chỉ một bản
thắng, và bản thắng thường **không mang** các tham số trong `.mcp.json` của harness.

Hậu quả im lặng, không có thông báo lỗi nào:

- `--timeout-action` vẫn là mặc định 5s → `browser_wait_for` chết với
  `TimeoutError: Timeout 5000ms exceeded`.
- Không có `--user-data-dir` → browser dùng thư mục tạm, nên **seed profile xong vẫn
  rơi về `/login`**. Đây có thể chính là nguyên nhân gốc của vòng lặp mô tả ở issue #2
  trong báo cáo: đăng nhập → vẫn login → xoá `user.json` → ép `npm run auth` → vẫn login.

Thay đổi:

- `/qa-setup` thêm mục **2c**: `claude mcp list`, phát hiện entry trùng, đề xuất
  `claude mcp remove playwright -s local` (hoặc `-s user`) và **chờ duyệt** — lệnh này
  sửa cấu hình máy người dùng chứ không chỉ repo. Xác nhận lại bằng `list`, rồi bảo
  thoát và mở lại session.
- `/qa-run` gate 5: thấy nhiều hơn một entry `playwright` → **DỪNG**, đừng chạy bằng cấu
  hình không kiểm soát được.
- `qa-config.md` thêm hai dòng: phạm vi MCP, và triệu chứng của xung đột scope.
- `TESTING.md` thêm dòng chẩn đoán *".mcp.json đúng hết mà timeout vẫn 5s, seed profile
  vẫn /login"*.

Người dùng muốn giữ bản local vì lý do riêng thì tôn trọng, nhưng phải nói rõ harness
đang chạy bằng cấu hình mà nó không kiểm soát được.

## v2.27 — 2026-08-30

Sửa theo báo cáo `ISSUES-2026-08-30.md` từ lần chạy thật `/qa-run TLM-3088`.

### #3 — mâu thuẫn tôi tạo ra ở v2.24 (nghiêm trọng nhất về bảo mật)
v2.24 bảo agent tự điền form login bằng MCP, đồng thời cấm để mật khẩu lọt ra ngoài.
**Hai điều đó không cùng tồn tại được**: điền form qua MCP là gọi
`browser_type({text: "<mật khẩu>"})`, và tham số tool call hiện nguyên văn trong
transcript.

Nay: thêm `.claude/scripts/seed-mcp-profile.mjs` — đăng nhập vào chính thư mục profile
MCP từ một tiến trình Node riêng, đọc `.env` trực tiếp, `ctx.close()` để nhả lock.
`/qa-login` gọi script thay vì mô tả điền form. `test-runner` **cấm điền form bằng MCP**;
gặp trang login thì kết thúc chặng và bảo người dùng thoát → seed → mở lại.

Sửa một điểm mong manh trong script gốc: bản trong báo cáo dựa vào `cd telemax-e2e` để
phân giải `@playwright/test`, nhưng **import ESM phân giải theo vị trí FILE chứ không
theo cwd**. Bản này trỏ thẳng đường dẫn tuyệt đối vào `node_modules` của `telemax-e2e`,
đã test chạy được từ mọi thư mục. Kèm kiểm `SingletonLock` để báo lỗi rõ khi profile bị
MCP chiếm, và hỗ trợ `--prod`.

### #1, #4 — hai ngõ cụt, ghi lại để không ai thử lại
- `--isolated --storage-state` **không nạp được session**: session Telemax nằm 100%
  trong localStorage, 0 cookie, và MCP không nạp phần đó. Dòng "Gộp còn MỘT session"
  trong `qa-config.md` đổi thành **ĐÃ THỬ — KHÔNG DÙNG ĐƯỢC**, kèm khẳng định hai session
  tách biệt là **thiết kế, không phải thiếu sót cần tối ưu**.
- `browser_run_code_unsafe` **không có filesystem** (`require` undefined, dynamic import
  chết) → không bơm được storage state từ file vào context MCP.

### #2 — chẩn đoán sai hướng ở gate 6
Thấy `/login` có hai nguyên nhân khác hẳn nhau. Gate nay **probe `localStorage` trên URL
tĩnh cùng origin** (`/favicon.ico`) trước khi kết luận: có `authToken_*` → hết hạn thật;
chỉ `app-version` → profile trống, seed lại vô ích cho tới khi sửa cấu hình. Bỏ bước này
là rơi vào vòng lặp đăng nhập → vẫn login → xoá `user.json` → ép `npm run auth` → vẫn login.
Cùng phép probe được áp cho nhánh hết session giữa chừng trong `test-runner`.

### #5, #6, #7
- `/qa-setup` thêm mục **đối chiếu từng tham số `.mcp.json` với bảng trong `qa-config`**,
  không chỉ kiểm file tồn tại. Kèm kiểm `.gitignore`.
- Gate 5 của `/qa-run`: chạm vào `.mcp.json` là **kết thúc session ngay**; MCP đọc args
  lúc khởi động nên sửa giữa session không có tác dụng **và không có tín hiệu nào báo**.
- Gate 3 (chọn Round) thêm trạng thái thứ ba: Round 1 **chỉ toàn `Blocked`/`Not Run`** và
  Defects rỗng → mặc định **ghi đè Round 1**, vì đẩy sang Round 2 thì `% Executed` của
  Round 1 vĩnh viễn bằng 0.

### #8 — điều kiện dữ liệu phải máy đọc được
Ticket TLM-3088 có 41/45 case rơi vào `[MANUAL]` vì môi trường không đáp ứng, chỉ lộ ra
ở chặng cuối. Nay `testcase-writer` phải gắn nhãn **`[DATA-REQ] <điều kiện>`** ở đầu cột
Note cho case *tự động hoá được nhưng cần dữ liệu*, phân biệt với `[MANUAL]` là *không
tự động hoá được*. `/qa-run` đếm và **gom theo loại điều kiện** trước khi chạy, thay vì
để phát hiện lúc chạy tới case thứ 30.

## v2.26 — 2026-08-30

Bị đẩy về login giữa chặng → **tự đăng nhập lại và chạy tiếp**, thay vì đứng lại hoặc
ghi Fail oan.

Quy tắc đặt ở mục cấp agent "Trình duyệt: MỘT phiên duy nhất" nên phủ cả 2a-1 lẫn 2a-2.

### Bốn bước
1. **Hỏi trước: đây có phải chính điều đang test không?** Case có Expected liên quan tới
   giữ đăng nhập / quyền truy cập / hết phiên thì **bị đẩy về login CHÍNH LÀ kết quả** —
   ghi theo Expected. Tự đăng nhập lại rồi coi như không có gì là **xoá mất bug**.
2. Không phải vậy → đăng nhập lại từ `telemax-e2e/.env`, cùng ba ràng buộc credential
   như bước đăng nhập thường.
3. **Chạy lại từ đầu case đang dở**, không chạy tiếp từ giữa — bị đẩy ra là mất trạng
   thái, mọi thứ làm nửa chừng đều không đáng tin.
4. **Ghi lại mỗi lần**: một dòng `qa-log.sh` và một dòng trong tổng kết. Hai lần trở lên
   trong một chặng là tín hiệu session hết hạn sớm, đáng nêu cho dev.

### Hai hàng rào
- **Chặn vòng lặp:** cùng một case bị đẩy ra 3 lần liên tiếp → DỪNG chặng. Có thể tài
  khoản bị khoá, sai mật khẩu trong `.env`, hoặc chính sản phẩm đang đá người dùng ra.
  Đừng đăng nhập lại lần thứ tư.
- **Gặp 2FA khi đăng nhập lại** → kết thúc chặng, bảo chạy `/qa-login`. Agent không chờ
  người dùng nhập mã được.

### Trường hợp nguy hiểm hơn: session của code hết hạn
Ở bước 2a-1, nếu **nhiều case chạy bằng `npx playwright test` cùng fail với triệu chứng
bị đẩy về login**, đó gần như chắc chắn là `playwright/.auth/user.json` hết hạn —
**không phải 20 bug sản phẩm**. Ghi `Fail` cho cả loạt là tạo ra một lô bug ma gửi cho
dev, đúng thứ làm dev thôi tin bug từ harness.

Xử lý: dừng, báo chạy `npm run auth` làm mới session, chạy lại. Chỉ ghi `Fail` sau khi
chạy lại với session mới mà vẫn hỏng.

## v2.25 — 2026-08-30

Sửa chỗ đặt sai của quy tắc một-phiên-trình-duyệt. v2.21 có nội dung đúng nhưng **nằm
sai vị trí**, nên trên thực tế chưa phủ hết.

- Quy tắc đang nằm **bên trong mục `2a-2` (case chưa có spec)**. Nhưng bước `2a-1`
  cũng mở MCP để điều tra spec fail — nhánh đó không bị quy tắc nào ràng buộc, agent có
  thể mở phiên mới hoặc đóng phiên cũ mà không sai dòng chữ nào.
  Nay nâng lên thành mục cấp agent **"Trình duyệt: MỘT phiên duy nhất, không bao giờ
  đóng"**, đặt trước `## Quy trình`, ghi rõ áp dụng cho cả 2a-1, 2a-2 và cả phiên mà
  command đã mở sẵn lúc đăng nhập.
- `2a-1` được nhắc lại một dòng: điều tra bằng MCP thì dùng chung phiên đang mở, reset
  hai bước, đừng khởi động phiên mới.
- `/qa-run` trước đây **không có dòng nào** về việc giữ cửa sổ khi kết thúc — chỉ
  `/qa-login` có. Nay cả hai đều nói.
- Thêm vào mục "Ranh giới (không vượt)" của `test-runner`: `KHÔNG gọi browser_close,
  kể cả khi chặng đã xong`. Ranh giới là chỗ agent đọc kỹ nhất khi phân vân.

Bài học lặp lại: nội dung đúng mà đặt trong một nhánh con thì chỉ ràng buộc nhánh đó.

## v2.24 — 2026-08-30

Agent **tự đăng nhập**; 2FA vẫn là việc của người dùng.

- `test-runner` và `/qa-login` nay đọc `TELEMAX_USER` / `TELEMAX_PASS` từ
  `telemax-e2e/.env`, tự điền form login và bấm Login. Trước đây cấm tự điền hoàn toàn,
  khiến mỗi lần session hết hạn là phải có người ngồi gõ tay.
- Tài khoản QA hiện tại đã tắt 2FA nên nhánh chờ-người-dùng ít khi chạm tới. Vẫn giữ
  nguyên để khi bật lại thì không hỏng: gặp màn nhập mã thì agent kết thúc chặng, người
  dùng nhập trong cửa sổ rồi gõ `ok`.

### Ba ràng buộc giữ nguyên
- **Chỉ lấy từ `.env`.** Không nhận mật khẩu qua chat kể cả khi người dùng chủ động đưa
  — chat là nơi mật khẩu bị lưu lại lâu nhất. Thiếu biến thì dừng và bảo điền vào file.
- **Không in ra đâu cả**: không nhắc lại trong câu trả lời, không vào `progress.log`,
  không đặt vào tên file.
- **Không chụp màn hình lúc form đang có mật khẩu.** Ảnh Phase 1 nằm ở
  `.qa/<ticket>/phase1/` và có thể bị đính vào bug ClickUp. Chụp sau khi đã vào bên trong.

### Ghi chú kỹ thuật
Tuỳ chọn `--secrets` của `@playwright/mcp` **không** dùng được cho việc này. Đọc
`config.d.ts` của package thì nó chỉ thay thế chuỗi trùng khớp trong *tool response* để
model đỡ vô tình thấy dữ liệu nhạy cảm, và bản thân tài liệu ghi rõ đó là *"a convenience
and not a security feature"*. Nó không cho phép điền một trường mà không biết giá trị.

## v2.23 — 2026-08-30

Chờ dữ liệu về rồi mới thao tác. Khung trang render gần như tức thì, nhưng dữ liệu đến
từ API sau đó — thao tác ngay là thao tác lên màn hình chưa có gì.

### Phase 1 (MCP)
Sau mỗi lần navigate, chờ bằng **tín hiệu dương**: đợi phần tử chứa **dữ liệu thật**
xuất hiện (một dòng trong bảng, tên xe trên tiêu đề, một giá trị số). Không phải đợi
"trang mở ra", không phải đợi spinner biến mất — nhiều màn hình không có spinner.

Ba cái bẫy được ghi thẳng vào `test-runner`:

- **Không chờ cứng** — vừa chậm khi mạng nhanh vừa thiếu khi mạng chậm.
- **Không chờ `networkidle`** trên màn hình realtime: dashboard telematics giữ kết nối
  stream để cập nhật vị trí/trạng thái nên network không bao giờ idle; chờ kiểu đó là
  chờ tới hết timeout.
- **Phân biệt "chưa tải xong" với "không có dữ liệu".** Ô `—`, `0`, hay skeleton có thể
  là đang tải, mà cũng có thể là kết quả đúng. Chờ hết timeout mà vẫn trống thì dừng
  lại phân biệt: thiếu test data hay đúng là lỗi? Đừng ghi `Fail` cho vế đầu — đó là
  bug ma gửi cho dev.

### Phần chạy bằng code
`playwright-export` thêm mục "Chờ dữ liệu về": để `expect()` tự retry vào phần tử dữ
liệu thật, cấm `page.waitForTimeout` (nguồn flaky số một) và cấm
`waitUntil: 'networkidle'`. Màn hình chậm thật thì nới timeout của chính assertion đó,
đừng thêm sleep phía trước.

## v2.22 — 2026-08-30

Chốt cách reset giữa các case: **hai bước, không phải một.**

1. `browser_navigate` về trang chủ `/`
2. `browser_navigate` tới trang của case

Đi thẳng tới trang đích là chưa đủ. Đây là SPA: điều hướng tới **đúng URL đang đứng**
có thể không remount component — modal vẫn mở, filter vẫn giữ, state cũ vẫn còn. Ghé
trang chủ ép đổi route thật, nên lần vào sau là màn hình sạch.

`TESTING.md` thêm dòng chẩn đoán "modal/filter của case trước còn dính sang case sau".

## v2.21 — 2026-08-30

Trình duyệt **không bao giờ bị đóng**, không chỉ trong một chặng.

- `test-runner`: cấm `browser_close` hoàn toàn — không giữa các case, không ở cuối
  chặng, không "dọn dẹp" trước khi kết thúc. Để browser sống tiếp là đúng ý muốn: lệnh
  `/qa-run` sau dùng lại ngay, khỏi khởi động lại và khỏi chờ SPA tải nguội. Nó tự tắt
  khi người dùng thoát Claude Code.
- `/qa-login` cũng để cửa sổ mở nguyên sau khi đăng nhập xong.

### Cái giá của việc giữ browser, và cách trả
Browser sống qua nhiều lệnh nghĩa là nó có thể đang ở trang của lần chạy trước, đang mở
modal, hay đang giữ filter cũ. Nên kèm quy tắc đối trọng: **mở đầu mỗi case luôn
`browser_navigate` tường minh tới trang xuất phát, không giả định đang ở đâu.**

Bỏ bước này thì **case đầu tiên của lần chạy sau sẽ sai lệch còn các case sau thì
đúng** — triệu chứng trông y hệt một bug sản phẩm, và là loại flaky tốn nhiều thời gian
nhất để truy. `TESTING.md` thêm đúng dòng chẩn đoán đó.

## v2.20 — 2026-08-30

Giữ session, để 2FA không thành cực hình.

### Một phiên trình duyệt cho cả chặng — quy tắc cứng
`test-runner` nay bắt buộc mở trình duyệt **một lần** ở case đầu rồi giữ tới hết nhánh
UI: không `browser_close` giữa các case, không mở tab mới mỗi case, giữa hai case chỉ
`browser_navigate` về trang xuất phát.

Đóng rồi mở lại là mất trạng thái đăng nhập của phiên đó — tài khoản có 2FA thì mỗi
lần mở lại là một lần người dùng phải lấy mã, chặng 20 case thành 20 lần chờ người.
Case làm bẩn trạng thái thì điều hướng lại trang, đừng khởi động lại trình duyệt.

### Ba tầng giữ session, ghi rõ trong `qa-config.md`
1. **Trong một chặng** — một phiên duy nhất (quy tắc trên).
2. **Giữa các lần chạy** — profile MCP ở `.playwright-mcp-profile/` (`--user-data-dir`,
   có từ v2.17), sống qua mọi lần chạy tới khi session hết hạn.
3. **Phần chạy bằng code** — `telemax-e2e/playwright/.auth/user.json`, cũng sống lâu.

Tầng 2 và 3 là **hai session tách biệt**, nên lần đầu cài phải đăng nhập hai lượt.
`/qa-login` nay hỏi luôn có muốn làm cả hai trong một lần ngồi không — nói trước là sẽ
phải nhập mã 2FA lần nữa, thay vì để người dùng phát hiện giữa chừng.

### Gộp còn một session: có cách, nhưng không đặt mặc định
Thay `--user-data-dir` bằng `--isolated --storage-state telemax-e2e/playwright/.auth/user.json`
thì MCP dùng chung session với code — đăng nhập một lần cho cả hai.

Tôi thử kiểm xem MCP có chết khi file session chưa tồn tại không, nhưng **phép thử
không kết luận được**: server dùng stdio nên đối chứng cũng thoát ngay, chết vì stdin
đóng chứ không phải vì thiếu file. Không đặt mặc định dựa trên một phép thử hỏng — nếu
nó thật sự chết lúc khởi động thì hậu quả là **mất sạch tool Playwright**, tệ hơn nhiều
so với một lần đăng nhập thừa. Ghi thành tuỳ chọn trong `qa-config.md` kèm đường lùi.

## v2.19 — 2026-08-30

Hai việc: nới timeout cho lần mở trình duyệt đầu tiên, và xử lý 2FA đúng chỗ.

### Timeout
`--timeout-action` mặc định của `@playwright/mcp` chỉ **5 giây** — quá ngắn cho SPA
này, vốn tải nguội mất hơn 30s. `.mcp.json` nay khai báo:
`--timeout-action 30000` · `--timeout-navigation 120000` · `--timeout-settle 1000`.

`test-runner` được dặn: đợi hết timeout rồi mới kết luận lỗi, **đừng kích circuit
breaker vì một lần chậm** đầu buổi.

### 2FA — chờ ở command, không chờ ở agent
Thêm command **`/qa-login`**: mở cửa sổ ở trang login, nhường quyền cho người dùng tự
đăng nhập (kèm mã 2FA), **đợi người dùng gõ `ok`**, rồi chụp snapshot kiểm thật — URL
không còn `/login`, không còn ô mật khẩu. Chưa đạt thì báo kẹt ở đâu và đợi `ok` lần
nữa; ba lần vẫn hỏng thì dừng hẳn.

`/qa-run` cũng có bước này trong cổng đầu vào, nên không phải nhớ chạy `/qa-login` trước.

**Vì sao không để agent chờ:** subagent chạy một chặng rồi kết thúc, không dừng đợi
người dùng nhập 2FA được — "hỏi rồi đợi" ở đó thực chất là đứng im cho tới khi hết giờ.
`test-runner` nay **kết thúc chặng ngay** khi gặp trang login hoặc màn 2FA, và bảo chạy
`/qa-login`. Cùng lý do đã áp cho `claude mcp add` ở v2.13.

Agent không nhận mật khẩu/mã 2FA qua chat và không tự điền form — không đổi.

### Project e2e
`auth.setup.ts` và `auth.prod.setup.ts` nay chờ tối đa **3 phút** sau khi bấm Login để
người dùng nhập mã, nhận diện cả URL dạng `mfa`/`2fa`/`verify`, và hết giờ thì báo lỗi
kèm hướng dẫn thay vì treo im lặng. Thêm script `auth:headed`, `auth:prod`,
`auth:prod:headed` — có 2FA thì phải chạy headed để nhập mã.

## v2.18 — 2026-08-30

Phase 1 nay để lại **bằng chứng bằng file**, không phụ thuộc việc có ai ngồi nhìn.

- `test-runner` chụp **một ảnh cho mỗi case tại đúng mốc kiểm Expected** —
  `<TC-ID>.png`, hoặc `<TC-ID>-FAIL.png` khi case không đạt. Một ảnh mỗi case ở mốc
  assert, không chụp từng thao tác.
- `.mcp.json` thêm `--output-dir .playwright-mcp-output` (đã gitignore). Sau khi chạy
  xong cả nhánh UI, agent gom về `.qa/TLM-XXXX/phase1/` bằng **một lệnh `mv` duy nhất**
  — chuyển từng file sau mỗi case là 20 lệnh bash cho 20 case.
- Actual của case Fail ghi kèm tên file ảnh, để người review mở đối chiếu thay vì tin
  lời agent.
- `clickup-bug-format`: bug từ case UI đính sẵn ảnh có ở `.qa/<ticket>/phase1/` hoặc
  `telemax-e2e/test-results/`, đừng để dev tự dựng lại.
- `qa-config.md` ghi thêm tuỳ chọn `--image-responses omit`: ảnh vẫn được lưu nhưng
  không nạp vào context — tiết kiệm token, đổi lại agent mất khả năng kiểm bằng mắt.
  Không bật mặc định.

### Vì sao
Nhìn trực tiếp là cách kiểm chứng tệ: không tua lại được, phải có mặt đúng lúc, không
chia sẻ cho ai khác được, và giá trị rơi rất nhanh — đến ticket thứ mười thì không ai
nhìn nữa. Giá trị thật của việc hiện cửa sổ là **nút dừng khẩn cấp**, không phải verify.
Verify phải đến từ artifact. Phần chạy bằng code đã có `trace`/`screenshot`/`video`
on-failure; Phase 1 trước đây không có gì cả.

## v2.17 — 2026-08-30

Làm rõ chế độ trình duyệt, và sửa một giả định sai về session của MCP.

- **Phase 1 qua MCP Playwright: cửa sổ HIỆN LÊN.** `@playwright/mcp` mặc định headed
  (kiểm bằng `--help`: *"run browser in headless mode, headed by default"*). Muốn chạy
  ngầm thì thêm `--headless` vào args trong `.mcp.json`.
- **Chạy spec bằng `npx playwright test`: NGẦM**, đúng mặc định của Playwright. Muốn
  nhìn thì `--headed` hoặc `npm run test:headed`.
- `test-runner` nay báo trước cho người dùng khi sắp mở cửa sổ, và nhắc **đừng bấm vào
  nó trong lúc agent chạy** — click của người dùng trộn vào luồng làm kết quả sai.

### Giả định sai đã sửa
Harness ghi Phase 1 mở dashboard-stage *"session đã login"*. Nhưng `@playwright/mcp`
không khai báo `--user-data-dir` thì **tạo thư mục tạm**, tức là mất session sau mỗi
lần khởi động lại — Phase 1 sẽ rơi vào trang login mà không ai lường trước.

`.mcp.json` nay khai báo `--user-data-dir .playwright-mcp-profile` (đã gitignore) và
`--viewport-size 1440x900`. Đăng nhập một lần trong cửa sổ đó là các phiên sau còn
session.

Kèm hàng rào: gặp trang login thì agent **DỪNG, bảo người dùng tự đăng nhập trong cửa
sổ đang mở**. Không tự điền form, không nhận mật khẩu qua chat.

## v2.16 — 2026-08-30

- Điền nốt bảng môi trường ↔ nhánh: **production build từ `master`**.
  Đường đi đầy đủ: feature → **`stage`** (dashboard-stage, test ở `/qa-run`) →
  **`master`** (production, verify ở `/qa-verify-prod`).
- `/qa-verify-prod` nay kiểm cụ thể bằng
  `git log --oneline origin/master --grep="TLM-XXXX"` thay vì chỉ hỏi suông, và vẫn
  hỏi thêm đã build/deploy xong chưa — merge vào `master` và deploy là hai việc khác nhau.
- Nói rõ hơn vì sao base để so diff là `stage` chứ không phải `master`: `master` là bản
  đã lên production, so với nó sẽ lôi vào cả thay đổi đang nằm trên staging của ticket
  khác, làm mục G (Impact) sai.

## v2.15 — 2026-08-30

Làm rõ **môi trường ↔ nhánh build**, sau khi biết dashboard-stage build từ nhánh
`stage`.

- `qa-config.md` thêm bảng **Môi trường ↔ nhánh build** đặt ngay đầu file:
  dashboard-stage ← nhánh **`stage`**; production ← `CHƯA ĐIỀN`, phải hỏi người dùng.
  Ghi thẳng: **`stage` KHÔNG phải `dev`, cũng KHÔNG phải `master`.**
- **Nhánh base để so git diff đổi từ `master` sang `stage`.** So với `master` sẽ lôi
  vào cả thay đổi chưa lên staging, khiến mục G (Impact) nói về vùng ảnh hưởng của một
  bản mà tester không hề đang test. Sửa ở `git-diff-scope`, `qa-analyze`, `test-analyst`.

### Lỗ hổng kéo theo, đã bịt
`/qa-run` trước đây **không kiểm code của ticket đã lên staging chưa**. Chạy test khi
code chưa merge vào `stage` là **đo bản cũ rồi ghi kết quả cho ticket mới** — test vẫn
chạy, vẫn ra số Pass, nên không có gì báo là sai. Cùng loại lỗi với "verify prod trước
khi deploy" đã chặn ở `/qa-verify-prod`.

Nay là mục chặn số 1 của `/qa-run`: kiểm bằng
`git log --oneline origin/stage --grep="TLM-XXXX"` rồi hỏi xác nhận đã build chưa.
Không thấy commit → dừng.

- `prod-verifier` nhắc tra bảng nhánh cho production, không suy từ `stage`/`master`.
- `TESTING.md` thêm hai dòng chẩn đoán: "test Pass hết nhưng không thấy tính năng mới"
  và "mục G nêu vùng ảnh hưởng không liên quan".

## v2.14 — 2026-08-30

- Đường dẫn project Playwright đổi từ `tests/e2e/` sang **`telemax-e2e/`** ở gốc repo,
  khớp tên thư mục thật. Sửa ở `qa-config.md`, README, `test-runner`, `qa-setup`,
  `playwright-export`, `prod-verifier`.
- Mọi lệnh `npx playwright test` trong harness nay có tiền tố `cd telemax-e2e &&`.
  Agent đứng ở gốc repo, nên lệnh không có `cd` sẽ chạy sai chỗ và báo "không tìm thấy
  test" — lỗi trông y hệt như spec chưa tồn tại, dễ khiến agent đi dò lại bằng MCP.
- `.mcp.json` ở project level: đã có từ v2.13, không đổi.

## v2.13 — 2026-08-30

Cài đặt cho repo mới: hai lệnh setup đưa vào harness thay vì nằm trong đầu người dùng.

- **Kèm sẵn `.mcp.json`** ở gốc bộ này, đã đăng ký Playwright MCP với
  `npx -y @playwright/mcp@latest`. Copy vào gốc repo là xong — thường **không cần**
  `claude mcp add` nữa, chỉ cần khởi động lại session để Claude Code nạp server.
- **Thêm command `/qa-setup`**: soát trước những gì đã có (chromium, `.mcp.json`,
  project e2e, `.env`, `qa-config.md`), xin duyệt **một lượt cho cả lô** rồi chạy, và
  liệt kê rõ phần người dùng phải tự làm — điền `.env`, điền `qa-config.md`, bật
  connector OAuth. Không tự điền `.env`, không hỏi mật khẩu qua chat.
- `/qa-run` khi thiếu MCP hoặc thiếu trình duyệt: hỏi có cài ngay không, nêu đúng lệnh
  rồi **chờ gật mới chạy**.
- Lệnh cài dùng đúng `npx -y` — bản trước thiếu `-y` nên treo ở prompt xác nhận của npx.

### Vì sao việc chạy lệnh nằm ở command, không nằm ở agent
`claude mcp add` **sửa cấu hình repo**, nên phải chờ người dùng duyệt. Mà subagent
chạy một chặng rồi kết thúc, không dừng chờ giữa chừng được — agent mà "hỏi rồi đợi"
thì thực chất là đứng im. Nên `test-runner` chỉ **phát hiện và báo rồi kết thúc**;
việc xin duyệt và chạy thuộc về command, nơi chạy trong session chính và chờ được.

## v2.12 — 2026-08-30

Sửa ba chỗ về MCP Playwright, phát hiện khi rà lại theo câu hỏi "có nhắc chạy MCP
trước rồi mới export không, và thiếu MCP có báo không".

### Hướng dẫn cài MCP đang SAI
`test-runner` ghi *"Thiếu → dừng, hướng dẫn bật (`/mcp` → Authenticate → Allow
access)"*. Đó là quy trình của connector OAuth như ClickUp/Figma. **Playwright MCP là
server chạy local, không có bước Authenticate.** Người dùng làm theo sẽ không tìm thấy
nút nào.

Nay hướng dẫn đúng: `claude mcp add playwright -- npx @playwright/mcp@latest`, cấu
hình nằm ở `.mcp.json` **gốc repo** (không phải `.claude/mcp.json`), kiểm bằng `/mcp`.
Kèm cảnh báo lỗi `-32000` do bộ gõ tiếng Việt chèn `~` vào cuối tên package khi gõ
trong terminal.

### Chặn quá tay
Trước đây thiếu MCP là dừng cả chặng `/qa-run`. Nhưng MCP chỉ cần cho **Phase 1 (dò
element)**; case đã có spec thì chạy thẳng bằng `npx playwright test`. Nay tách hai
tình huống: có case chưa có spec → dừng; mọi case đã có spec → chạy tiếp, chỉ báo
trước rằng spec fail sẽ không điều tra được bằng MCP.

### Luồng hai phase bị mờ đi ở chỗ dễ thấy nhất
Đợt gọt description ở v2.8 tôi cắt mất cụm "đã dò qua MCP Playwright ở Phase 1" khỏi
`description` của `playwright-export` — mà description là thứ luôn nạp và là chỗ người
dùng nhìn thấy đầu tiên. Luồng vẫn được mô tả đầy đủ trong body skill và trong
`test-runner`, nhưng ở lớp ngoài thì không còn dấu vết. Đã khôi phục.

Ngoài ra `/qa-run` trước đây **không có dòng nào** nhắc MCP trong cổng đầu vào. Nay
kiểm MCP là mục chặn số 4, kèm mô tả hai phase ngay tại command.

- `playwright-export` thêm mục yêu cầu MCP sẵn sàng trước, và nhắc lại rằng skill
  KHÔNG được bịa selector khi không có Phase 1.
- `qa-config.md` thêm dòng khai báo MCP Playwright.
- `evals/03` thêm 3 kịch bản con: thiếu MCP + có case mới (dừng), thiếu MCP + đủ spec
  (chạy tiếp), và luồng hai phase đầy đủ.

## v2.11 — 2026-08-30

Thêm **chặng 6: verify sau khi deploy lên production**.

Ticket verify xong trên staging, dev fix, deploy lên prod — giờ chạy lại bằng **code**
(project Playwright, KHÔNG dùng MCP) để chắc production hành xử đúng như staging.

- Thêm command `/qa-verify-prod TLM-XXXX` và agent `prod-verifier` (`model: sonnet`).
- Khác hẳn `test-runner`: chỉ chạy spec `.ts` đã có, không dò MCP, không viết spec mới,
  không sửa dữ liệu.

### Hàng rào `@prod-safe` — phần quan trọng nhất
Production là dữ liệu khách hàng thật. Chạy nguyên bộ spec lên đó sẽ **sửa dữ liệu
thật**: case mẫu `TC-B-001` xoá trắng tên xe rồi bấm Save.

- Case **chỉ xem** gắn `{ tag: '@prod-safe' }`; case có ghi dữ liệu thì không gắn.
- Project `prod` trong `playwright.config.ts` lọc bằng `grep: /@prod-safe/`.
  **Quên gắn thì case không chạy trên prod** — hàng rào cố ý nghiêng về phía bỏ sót,
  vì bỏ sót một case còn sửa được, sửa nhầm dữ liệu thật thì không.
- `prod-verifier` từ chối chạy case không gắn tag **kể cả khi người dùng bảo chạy hết**,
  và từ chối gỡ `grep`. Không có case nào gắn tag → DỪNG, không báo "xanh, 0 fail".
- Session và account production tách hẳn khỏi staging (`playwright/.auth/prod.json`,
  `TELEMAX_PROD_USER`). `auth.prod.setup.ts` chặn luôn nếu `PROD_BASE_URL` chứa
  `stage`/`staging`/`localhost`.

### Fail trên prod không tự động là bug
`prod-verifier` phải phân biệt ba loại: **regression thật** (staging Pass, prod Fail,
mở lại thấy đúng sai) · **lệch dữ liệu** (prod không có bản ghi mà case dựa vào) ·
**nhiễu môi trường** (timeout, prod nghẽn — `retries: 1`, chạy lại một lần rồi mới kết
luận). Không phân biệt được thì ghi "chưa kết luận" và hỏi, không đoán để có số đẹp.

### Kèm theo
- Báo cáo `.qa/TLM-XXXX/prod-verify-<ngày>.md`, viết cho tester và quản lý đọc.
- Kết quả prod ghi vào Excel hay chỉ để ở báo cáo → là đầu vào cần xác nhận, mặc định
  là báo cáo riêng (không đụng vào cột Round vốn đang dùng cho staging).
- Command hỏi xác nhận **ticket đã lên production thật chưa** — chạy verify trước khi
  deploy xong là đo bản cũ rồi báo xanh.
- Project e2e: thêm `auth.prod.setup.ts`, project `prod` + `setup-prod`,
  `npm run test:prod`. Đã verify: staging thấy 4 case, prod chỉ thấy 2 case gắn tag.
- Thêm eval `05-prod-safety.json` (3 kịch bản con, gồm cả trường hợp người dùng bảo
  "chạy hết đi").

## v2.10 — 2026-08-30

Artifact xuất ra viết cho **tester đọc**, không phải cho dev.

- `checklist-format` thêm mục **"Viết cho ai đọc"**: câu ngắn một ý một dòng; chủ ngữ
  là người dùng hoặc hệ thống chứ không phải hàm/service; gọi đúng tên nhìn thấy trên
  màn hình; không `H1`/`div`/`endpoint`/tên class/tên bảng DB; URL không thay được tên
  màn hình.
- `testcase-template` thêm mục **"Giọng văn của Steps và Expected"**: mỗi bước một
  thao tác bắt đầu bằng động từ, khoảng 15 từ đổ lại; Expected mô tả cái hiện trên màn
  hình chứ không phải mã HTTP; sheet `Test Cases_VN` là tiếng Việt tự nhiên, không dịch
  máy móc từng chữ.
- Mục **G của checklist** ghi tên chức năng người dùng hiểu, tên kỹ thuật để trong
  ngoặc cho dev: `Hiển thị số km (VehicleDetailMapper)`. Tester đọc cột này để biết
  test lại chỗ nào — họ không tra được tên class.
- Hai file mẫu đã viết lại theo đúng giọng đó: bỏ `H1`, `/devices`, `field`, đổi sang
  "Tiêu đề trang", "Mở menu Devices", `ô "Vehicle Name"`.
- Self-check thêm dòng: *đọc lại như một tester mới vào; chỗ nào phải hỏi lại thì viết
  lại*. `TESTING.md` thêm phép thử tương ứng — đưa file cho tester chưa đọc ticket xem
  họ chạy được không.

Ngoại lệ giữ nguyên chất kỹ thuật: case Type `API` và phần Actual Result của bug —
người đọc chúng cần đúng endpoint, payload, mã HTTP.

## v2.9 — 2026-08-30

Thêm kênh theo dõi tiến trình. Subagent chạy kín nên trước đây gõ lệnh xong là màn
hình đứng yên vài phút, không biết agent đang ở bước nào hay đã treo.

- Thêm `.claude/scripts/qa-log.sh`: in ra màn hình **và** ghi
  `.qa/<ticket>/progress.log`, kèm giờ và số giây trôi qua kể từ đầu chặng.
  Theo dõi trực tiếp: `tail -f .qa/TLM-XXXX/progress.log`.
- Bốn agent đều có mục **"Báo tiến trình"** với danh sách bước cố định
  (analyze 6 bước, write-cases 5, run 6, file-bugs 5). Log ở mốc bước, không log từng
  thao tác nhỏ.
- Bước bị bỏ vẫn log kèm lý do (`"skip: chưa có Postman collection"`) — biến mất
  lặng lẽ là thứ khiến người dùng tưởng đã chạy. Dừng giữa chừng cũng log lý do.
- Command nhắc lệnh `tail -f` trước khi gọi agent.

Log ở lại sau khi chạy, nên truy được bước nào chậm và chặng nào dừng dở.

**Giá:** ~5–6 lệnh bash mỗi chặng, khoảng 200 tokens. Chấp nhận được so với việc ngồi
nhìn màn hình đứng yên, nhưng đó là lý do không log dày hơn.

## v2.8 — 2026-08-30

Rà token. Chi phí mỗi chặng giảm ~20% mà không bỏ hành vi nào.

| Chặng | Trước | Sau |
|---|---|---|
| `/qa-analyze` | 11.500 | 9.500 |
| `/qa-write-cases` | 10.200 | 8.400 |
| `/qa-run` | 10.000 | 8.100 |
| `/qa-file-bugs` | 7.000 | 5.100 |

### Bỏ `input-contract.md`
File này 1.920 tokens và được nạp ở **mọi** chặng, nhưng mỗi chặng chỉ cần bảng của
riêng nó (~200 tokens) — phần còn lại là bảng của ba chặng khác cộng với nội dung đã
có sẵn inline trong command. Nay bảng nằm ngay trong command tương ứng, ba mức
chặn/xác nhận/tự quyết rút thành 4 dòng ở đầu mỗi cổng đầu vào. Riêng thay đổi này
tiết kiệm ~1.860 tokens mỗi chặng.

### Bỏ trùng lặp trong cùng một chặng
- `test-analyst` chép lại quy tắc mục F mà `checklist-format` đã quy định — cả hai
  cùng nạp ở chặng analyze. Giữ lại đúng phần phán đoán thuộc về agent
  (ràng buộc số không mặc nhiên là độ tin Cao), bỏ phần trình bày.
- Bảng "Đầu vào skill cần" của `checklist-format` rút thành 3 dòng văn xuôi.

### Ghi rõ nguyên tắc
`README.md` thêm mục **Ngân sách token** với số đo và 4 quy tắc, trong đó quan trọng
nhất: *trùng lặp giữa các file không bao giờ cùng nạp là miễn phí* — 4 agent lặp cùng
một khối không tốn gì, vì mỗi chặng chỉ nạp một agent. Gom chúng vào một file dùng
chung mới là cách làm file đó phình lên rồi bị nạp ở mọi chặng, đúng lỗi vừa sửa.

Nguyên tắc này nằm ở README chứ không nằm trong `.claude/`: tài liệu cho người thì
miễn phí, mọi dòng thêm vào `.claude/` đều có giá ở mỗi lần chạy.

## v2.7 — 2026-08-30

**Spec Playwright gom theo ticket, không theo màn hình.** Đảo lại quyết định ở v2.4.

- Tên file là mã ticket: `tests/TLM-2899.spec.ts`, chứa **toàn bộ** case UI của ticket
  kể cả khi ticket đụng nhiều màn hình (thêm `describe`, không thêm file).
- Chạy lại cả ticket bằng một lệnh: `npx playwright test tests/TLM-2899.spec.ts`.
- Spec ánh xạ 1:1 với file test case Excel — cùng phạm vi, cùng bộ TC ID, cùng vòng đời.
  Nhất quán với phần còn lại của harness, vốn đã gom mọi thứ theo ticket dưới `.qa/`.
- Tiêu đề test trở lại `TC-Y-NNN — <mô tả>` (bỏ tiền tố ticket ID, vì tên file đã mang
  ticket). Đổi lại: **chạy theo TC ID phải luôn kèm đường dẫn file** — `-g "TC-A-001"`
  trần sẽ vớ phải case của ticket khác.
- Giữ được regression theo màn hình nhờ **tên describe đặt theo màn hình và nhất quán
  giữa các ticket**: `npx playwright test -g "Vehicle Detail"` quét mọi ticket từng
  test màn hình đó.
- `test-runner` bước 0 tra bằng đường dẫn file thay vì grep tiêu đề.
- Report newman chuyển từ `result.json` ở gốc repo sang `.qa/TLM-XXXX/result.json`,
  cùng lý do gom theo ticket.

## v2.6 — 2026-08-30

Siết luồng "chưa có ticket": từ *hỏi ba lựa chọn* thành **dừng và bảo tạo ticket trước**.

- `/qa-analyze` gặp spec dán thẳng vào chat → **DỪNG, chưa phân tích gì**. Bảo người
  dùng tạo ticket rồi quay lại với mã, hoặc để agent tạo giúp: dựng nội dung task
  (tiêu đề, mô tả, AC tách thành danh sách), **đưa duyệt trước khi tạo**, tạo xong
  lấy mã và chạy tiếp luôn — không bắt gõ lại lệnh.
- Phương án "chạy không cần ticket" **không còn được chào** như một lựa chọn ngang
  hàng. Nó chỉ còn là lối thoát khi người dùng đã nghe nhắc mà vẫn nói rõ là cứ chạy
  — khi đó vẫn `TMP-<slug>` + nhãn `[Chat]` + mục A ghi rõ, và không nhắc lại nữa.
- Đầu vào này nâng từ mức 2 (xác nhận) lên **mức 1 (chặn)** trong `input-contract.md`.

## v2.5 — 2026-08-30

Khuyến khích có ticket trước khi chạy, và làm cho trường hợp không có ticket **hiện
rõ trong artifact** thay vì trôi mất.

- `/qa-analyze` hỏi **một lần** khi người dùng dán spec thẳng vào chat: tự tạo ticket,
  để agent tạo giúp qua `ClickUp:clickup_create_task` (dựng nội dung rồi chờ duyệt,
  không tự tạo), hay đi tiếp không ticket. Không hỏi lại ở các chặng sau.
- Đi tiếp không ticket vẫn chạy được, nhưng để lại dấu vết ở đúng ba chỗ người ta sẽ
  tra sau này:
  - checklist: nhãn nguồn mới **`[Chat]`**, và mục A ghi "chưa có ticket — dán tay
    ngày <ngày>";
  - file Excel: `cover.source` ghi `Dán tay trong chat, chưa có ticket — <ngày>`;
  - bug ClickUp: ghi thẳng là chưa có ticket yêu cầu, không bỏ trống lặng lẽ.
- Khoá thư mục dùng `TMP-<slug>` thay cho `TLM-XXXX`. **Cấm bịa mã `TLM-xxxx`** cho
  đẹp ô Cover hay đẹp mục A — đó là mã trỏ vào hư không, tệ hơn ô trống.

Phân biệt cốt lõi: `[AC-03]` ba tháng sau còn mở lại đối chiếu được; `[Chat]` thì nội
dung gốc đã trôi trong lịch sử hội thoại của một người. Nhãn khác nhau để người review
biết dòng nào kiểm chứng lại được.

## v2.4 — 2026-08-30

Khép vòng lặp Playwright: spec export ra nay được **verify ngay** và **dùng lại ở
lần chạy sau**. Trước đây file `.ts` được sinh ra rồi bỏ đó — chưa từng chạy, và
round sau vẫn dò lại toàn bộ bằng MCP.

### Định danh spec — convention load-bearing
Tiêu đề test đổi từ `TC-A-001 — ...` thành **`TLM-XXXX · TC-Y-NNN — ...`**.

Lý do: TC ID chỉ duy nhất **trong một ticket** (mỗi file Excel đánh lại từ `TC-A-001`),
nên `-g "TC-A-001"` sẽ chạy nhầm case của ticket khác. Ticket ID trong tiêu đề làm
khoá tra cứu thành duy nhất.

Kèm theo: file đặt tên theo **màn hình** (`vehicle-detail.spec.ts`), không theo ticket
— ticket sau đụng cùng màn hình thì append vào file đã có. Header comment ghi mỗi
ticket một dòng. **Không duy trì file index** ánh xạ TC ID → spec; index sẽ lệch,
grep trên tiêu đề test mới là nguồn tra cứu. `assets/example.spec.ts` đã cập nhật theo.

### `test-runner` nhánh UI — thêm bước 0 và bước verify
- **Bước 0:** grep `TLM-XXXX · TC-Y-NNN` trong thư mục tests. Có spec → chạy lại bằng
  `npx playwright test -g`, không dò lại bằng MCP.
- **Spec cũ Fail → không được ghi `Fail` ngay.** Phải mở MCP kiểm tay để phân biệt
  *sản phẩm lỗi thật* với *spec mục rữa* (selector đổi vì UI refactor). MCP thấy UI
  đúng → sửa selector, KHÔNG tạo defect. Đây là nguồn bug rác nguy hiểm nhất của
  regression: dev nhận bug cho lỗi không tồn tại rồi thôi tin bug từ harness.
- **Phase 3 (mới):** sau khi export, chạy thử ngay và đối chiếu Phase 1. Lệch thì sửa
  spec, không sửa kết quả — kết quả ghi vào Excel luôn là của Phase 1.
- Tổng kết báo thêm: bao nhiêu case chạy lại bằng spec có sẵn, bao nhiêu dò mới,
  spec nào phải sửa selector.

### Test
`TESTING.md` thêm mục "Phép thử vòng lặp spec": chạy lần 2 phải dùng lại spec; cố ý
làm hỏng một selector để kiểm hàng rào phân biệt bug-thật / spec-hỏng; bỏ ticket ID
khỏi tiêu đề để thấy convention là thứ load-bearing.

## v2.3 — 2026-08-30

### Postman: chưa có thì skip, không chặn
Mục Postman trong `qa-config.md` có thêm trường **Trạng thái**:

- `CHƯA CÓ` (mặc định hiện tại) → `/qa-run` **skip nhánh API và vẫn chạy nhánh UI**.
  Case API ghi `Blocked` + Note `[MANUAL] chưa có Postman collection — chờ bổ sung`.
  Marker `[MANUAL]` khiến `write_defects.py` không tạo defect cho chúng — đúng mong
  muốn, vì chưa chạy thì chưa biết đúng sai, không phải bug.
- `CÓ` nhưng file không tồn tại ở đường dẫn khai báo → vẫn DỪNG, vì đó là sai cấu
  hình chứ không phải "chưa có".

Trước đây thiếu collection là dừng cả chặng, khiến không test được gì kể cả phần UI.

`test-runner` nay tách Blocked thành ba loại trong tổng kết: manual, chưa-có-Postman,
và vướng dependency thật — ba loại cần hành động khác nhau.

## v2.2 — 2026-08-30

Rà lại đầu vào của từng chặng. Nguyên tắc mới xuyên suốt: **thiếu đầu vào thì hỏi
hoặc xin xác nhận, không tự suy đoán.**

### Thêm `.claude/input-contract.md`
Ba mức xử lý đầu vào — *chặn* (không có mặc định an toàn, phải hỏi), *xác nhận*
(có mặc định nhưng mặc định vẫn là phán đoán, phải nêu ra), *tự quyết* (chuyên môn
agent, phải liệt kê trong tổng kết) — kèm bảng đầu vào của cả 4 chặng.

Phân biệt cốt lõi: giá trị **đọc được từ nguồn thật** là dữ liệu, dùng thẳng; giá trị
**agent tự nghĩ ra vì không tìm thấy** là phán đoán, không bao giờ được dùng lặng lẽ.

### Lỗ hổng đầu vào đã bịt
- **Round ghi kết quả test không được khai báo ở đâu cả.** `test-runner` phải chọn
  cột J/K hay L/M mà không có gì chỉ định; `write_defects.py` thì suy round ngược từ
  dữ liệu đã ghi. Ghi nhầm round là nó đọc sai và `% Executed` sai theo. Nay `ROUND`
  là đầu vào mức 1, có đề xuất nhưng phải được xác nhận.
- **Ticket ID suy từ tên nhánh rồi dùng thẳng** → nay phải xác nhận trước khi dùng.
- **Nhánh base `master`** được coi như dữ liệu → nay là mặc định cần xác nhận.
- **Ràng buộc field không có trong spec** → trước đây rơi vào mục F độ tin "Cao" và
  được dùng luôn. Nay maxlength/min/max chỉ được gán Cao khi có căn cứ đọc được
  (schema DB, code validator) và phải ghi rõ căn cứ; không có căn cứ thì độ tin Thấp,
  bắt buộc hỏi. `testcase-writer` đối chiếu D1/D2 trước khi viết, thiếu thì dừng.
- **File .xlsx khi có nhiều file** → không tự lấy file mới nhất, liệt kê và hỏi.
- **Test data đặc thù** ("xe đang có fault") → hỏi hoặc đánh `[MANUAL] thiếu test
  data`, không bịa và không coi như pass.
- **Bug trùng trên ClickUp** → không tự quyết dùng ID cũ, hỏi người dùng.
- **Folder Drive đích** → không tự chọn thư mục gốc.
- **Section "Phản hồi review" rỗng** → hỏi, không hiểu thành "OK hết".
- **Phản hồi trỏ số không tồn tại hoặc mơ hồ** → hỏi, không tự sửa theo phỏng đoán.

### Cấu trúc
- 5 command đều có mục **"Cổng đầu vào"** chạy trước khi gọi agent, gộp mọi câu hỏi
  vào một lượt (subagent chạy xong là kết thúc, không chờ giữa chừng được).
- Khối đầu vào truyền xuống agent nay có đủ trường đã xác nhận (`ROUND`, `COVER`,
  `BASE_BRANCH`, `TEST_DATA`, `CLICKUP_LIST`...).
- 4 agent có mục "Đầu vào — không đoán thay người dùng" và bắt buộc kết thúc bằng
  khối tổng kết `Đã hỏi & được xác nhận / Agent tự quyết / Còn treo`.
- 7 skill có mục "Đầu vào skill cần": bảng cần gì, nguồn ở đâu, thiếu thì làm gì.
- `checklist-format`: cấm thay `[Cần hỏi]` bằng giá trị tự nghĩ rồi gắn `[Suy luận]`.
- Thêm eval `04-input-gate.json` với 4 kịch bản con.

### Test
- Thêm `TESTING.md`: hướng dẫn test 4 tầng (script → discovery → từng chặng →
  end-to-end), 4 phép thử phá hoại, bảng chẩn đoán lỗi.
- Thêm `.claude/scripts/smoke-scripts.sh`: 18 assertion trên tầng script, không cần MCP, chạy
  được ở CI. Hiện xanh toàn bộ.

### Không đổi
Luồng 5 chặng, 3 điểm dừng review, script, template đều giữ nguyên.

## v2.1 — 2026-08-30

Đợt sửa theo checklist *Skill authoring best practices*. Không đổi hành vi luồng;
đổi cấu trúc tài liệu, gỡ tham chiếu gãy, thêm eval.

### Chặn (v2.0 không chạy được tới cùng như mô tả)
- **`recalc.py` không tồn tại.** SKILL.md trỏ tới `<xlsx-skill>/scripts/recalc.py`,
  một placeholder không giải được, trong khi recalc là bước bắt buộc ở 3 skill và
  3 agent. Nay có `testcase-template/scripts/recalc.py` thật (LibreOffice headless,
  không ghi đè file gốc khi lỗi, báo cách thay thế nếu thiếu LibreOffice).
- **Tham chiếu `cases.json` mâu thuẫn** — một chỗ nói schema ở "đầu file này"
  (SKILL.md không hề có), chỗ khác nói ở docstring `build.py`. Nay schema nằm ở
  `reference/cases-json.md`, cả SKILL.md lẫn docstring đều trỏ về đó.
- **TODO treo trong `clickup-bug-format`** (list/space, tag) khiến `bug-filer` dừng
  giữa chừng mỗi lần chạy. Nay gom vào `.claude/qa-config.md` — điểm khai báo duy
  nhất, có trạng thái `CHƯA ĐIỀN` rõ ràng.

### Cấu trúc skill
- **Progressive disclosure**: `common-validate` tách thành `reference/web-fields.md`,
  `reference/api.md`, `reference/telematics.md` (SKILL.md 155 → 76 dòng);
  `testcase-template` tách `reference/openpyxl-traps.md` (290 → 206 dòng).
- **Description gọn lại** ở cả 7 skill: bỏ phần "skill KHÔNG làm gì" (thuộc body,
  không giúp discovery). Tổng metadata luôn-nạp giảm khoảng 40%.
- **Ví dụ cụ thể**: thêm `checklist-format/assets/example-checklist.md` và
  `clickup-bug-format/assets/example-bug.md`, theo mẫu `playwright-export` đã có sẵn.
- **Bỏ khối "KHUÔN DỰ KIẾN v1"** khỏi body 3 skill — ghi chú cho tác giả, không phải
  hướng dẫn cho agent. Trạng thái đó nay nằm ở README + CHANGELOG.
- **Khai báo dependency**: `openpyxl`, `newman`, `@playwright/test`, LibreOffice.
- **Tên MCP tool đầy đủ** dạng `ClickUp:clickup_get_task`, `Figma:get_design_context`
  thay vì nói chung "ClickUp MCP". Ghi rõ dạng `mcp__server__tool` chỉ dùng cho
  allowlist `tools:` trong frontmatter.
- `git-diff-scope`: sửa cấp heading ("Luôn xem" bị lệch ra ngoài Tầng 2); chuyển
  lý luận skill-vs-rule sang README.
- `checklist-format`: nói rõ đánh số bắt đầu ở mục C (A và B không đánh số).

### Eval
- Thêm `evals/` với 3 kịch bản: cấu trúc checklist + lọc diff; build/Traceability
  bắt AC hở; và guard `[MANUAL]` / `Won't fix` khi tạo bug. Chạy tay, chưa có runner.

## v2.0 — 2026-08-23

Bản sửa sau đợt review toàn bộ. Đổi cả cấu trúc lẫn script, không tương thích
ngược với `cases.json` của v1.

### Chặn (v1 không chạy đúng như mô tả)
- **Frontmatter `tools` sai** → agent v1 chạy mà không có ClickUp/Figma/Playwright/
  Drive, và `test-analyst` thiếu cả `Write`. Nay bỏ `tools` để kế thừa toàn bộ.
- **Mô hình dừng-chờ không khớp subagent** → tách thành 5 slash command, mỗi
  command một chặng chạy trọn vẹn rồi kết thúc. Thêm `.claude/commands/`.
- **`write_defects.py` lấp ô trống đầu tiên** → đè mất dòng defect đã review khi
  người dùng xoá một dòng ở giữa. Nay luôn APPEND.
- **`writeback` khoá theo số dòng** → gán Ticket ID nhầm case nếu file bị chèn/xoá
  dòng. Nay khoá theo TC ID.
- **Luồng Drive đọc nhầm file** → review trên Drive nhưng script đọc bản local.
  Nay upload là bước cuối, sau writeback; `bug-filer` bắt xác nhận review bản local.
- **TC ID trùng nuốt case fail** → `build.py` và `write_defects.py` đều chặn.

### Script
- `build.py`: xoá hàm `update_section_table` bị định nghĩa hai lần (bản đầu là
  dead code); dò bảng RESULT BY SECTION động thay vì hard-code row 21–24; validate
  chặt (ID duy nhất/đúng pattern/khớp divider, cover bắt buộc, thiếu bản dịch VN,
  AC không tồn tại); style dòng data định nghĩa cứng (wrap_text, border, divider
  fill) thay vì kế thừa template; bỏ ép row height; cập nhật Summary A2; RECORD OF
  CHANGE append thay vì ghi đè; dựng sheet Traceability; exit code 1/2 thay vì
  warning in ra rồi đi tiếp.
- `write_defects.py`: append an toàn; khoá theo TC ID; tự `.bak`; tôn trọng
  `Fix Status = Won't fix`; bỏ qua case `[MANUAL]`; không tạo defect cho case đã
  Pass ở round sau; báo `skipped` kèm lý do.

### Template
- Dọn sạch metadata mẫu (`CU-1234`, "Vehicle Information") → placeholder.
- Xoá style rác ở vùng data 2 sheet Test Cases (gây fill màu ngẫu nhiên ở sheet VN).
- **Thêm sheet `Traceability`** (AC → TC, cờ MISSING).
- LEGEND: nói rõ `Blocked` bao gồm case chờ chạy tay `[MANUAL]`.

### Skill & agent
- `rules/git-diff-convention.md` → `skills/git-diff-scope/` (rule không có `paths:`
  nạp vào mọi session, tốn context cả khi không làm QA).
- `checklist-format`: sửa mâu thuẫn description (chat vs file); A→H; thêm **mục E2
  (Bảng AC)**; quy tắc append số, không chèn giữa; phản hồi đã xử lý được *chuyển*
  xuống section "Đã xử lý" chứ không xoá.
- `common-validate`: thêm **nhóm 11 — dữ liệu telematics** (độ tươi dữ liệu,
  timezone, đơn vị đo, toạ độ/bản đồ, realtime).
- `playwright-export`: ưu tiên assertion dương; mở rộng phạm vi export sang
  Boundary/Negative/Business rule *quan sát được trên UI*; cấu hình artifact
  (trace/screenshot/video) để có bằng chứng cho bug.
- `clickup-bug-format`: chốt ngôn ngữ; chống trùng với ClickUp chứ không chỉ với
  file; `Won't fix` thay cho xoá dòng.
- `test-runner` tách đôi: chạy test (`test-runner`) và tạo bug + upload (`bug-filer`).
- Thêm **nhánh Manual** để Boundary/Negative không rơi khe và nằm `Not Run` mãi.

### Còn là "khuôn dự kiến v1" — cần dữ liệu thật của team
- `playwright-export`: tinh convention `.ts` sau vài lần chạy Phase 1 thật.
- `postman-api-test`: khớp cấu trúc collection thật (folder/naming/auth).
- `clickup-bug-format`: list/space đích, tag, priority map, status, rule assign.

## v1 — 2026-08
Bản dựng đầu tiên.
