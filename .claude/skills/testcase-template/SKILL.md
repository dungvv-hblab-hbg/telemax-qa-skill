---
name: testcase-template
description: >-
  Sinh file test case Excel chuẩn của Telemax từ checklist đã được review confirm:
  clone template rỗng, đổ 14 cột vào sheet "Test Cases" (EN) theo quy ước ID từng
  section, dịch sang "Test Cases_VN", và dựng sheet Traceability (AC → TC) để bắt
  AC còn hở. Dùng khi cần biến checklist/phân tích test thành bộ test case Excel,
  viết test case cho một ticket, hay xuất test case ra file để chạy — kể cả khi
  người dùng chỉ nói "viết test case", "gen test case", "làm file test case cho
  ticket này".
---

# Testcase-template

Sinh **file test case Excel** từ nội dung test case đã được quyết định. Đây là
bước SAU `checklist-format`: checklist ra danh sách "cần test gì", người review
confirm, rồi test case cụ thể được đổ vào file theo skill này.

Ranh giới: skill nhận test case đã có (Section/Type/Priority/Steps/Expected) và đổ
vào đúng khuôn Excel. Nó không tự nghĩ ra test case, không gán Priority, không
quyết khi nào được viết test case — những phần đó do agent điều phối lo.

## Yêu cầu môi trường

- Python 3 + `openpyxl`. **Đừng chạy `pip install openpyxl` trần** — trên macOS
  (Homebrew) và Ubuntu 23+ nó thất bại với `externally-managed-environment` (PEP 668).
  Harness dùng venv chuẩn ở `.claude/.venv`, do `/qa-setup` tạo:
  ```
  python3 -m venv .claude/.venv && .claude/.venv/bin/python -m pip install openpyxl
  ```
- **Mọi script Python gọi qua `.claude/scripts/qa-py.sh`**, không gọi `python`/`python3`
  trực tiếp. Wrapper tự chọn interpreter có openpyxl (venv chuẩn → `$QA_PYTHON` →
  `python3` hệ thống) và giữ nguyên exit code. Gọi trực tiếp thì mỗi session tự xoay
  một kiểu — đã từng sinh ra hai venv lạc mà session sau không biết đường tìm.
- LibreOffice (`soffice`) — cho `scripts/recalc.py`. Không có thì mở file bằng
  Excel một lần cũng có tác dụng tương đương.

## Tài liệu kèm theo

- **Cấu trúc `cases.json`** (đầu vào của `build.py`): xem [reference/cases-json.md](reference/cases-json.md)
- **Bẫy openpyxl, style, nới công thức Summary**: xem [reference/openpyxl-traps.md](reference/openpyxl-traps.md)
  — chỉ cần khi sửa script hoặc thao tác tay lên file .xlsx
- **Template Excel rỗng**: `assets/template.xlsx`
- **Ví dụ `cases.json`**: `assets/example.cases.json`

## Đầu vào skill cần

| Cần | Nguồn | Thiếu thì |
|---|---|---|
| `cover.module` / `version` / `source` / `create_date` | người dùng xác nhận ở cổng đầu vào | **Hỏi.** `build.py` exit 1 nếu thiếu — đừng lách bằng cách tự điền `1.0` hay ngày hôm nay mà không xác nhận |
| `cover.source` khi chưa có ticket | — | Ghi thẳng `Dán tay trong chat, chưa có ticket — <ngày>`. **Đừng bịa mã ticket** để ô Cover trông đẹp: sheet Cover là chỗ người khác tra nguồn sau này |
| Nội dung test case (Steps, Expected, Data) | agent, dựa trên checklist đã review | Ràng buộc/message không có ở D1/D2 → hỏi, không tự nghĩ giá trị |
| Priority | agent quyết theo rủi ro | Tự quyết được, nhưng phải báo phân bố trong tổng kết |
| Danh sách AC | mục E2 của checklist | Không có AC thì Traceability không dựng được — báo rõ, đừng bỏ qua im lặng |

## Giọng văn của Steps và Expected

File này là **tài liệu tester cầm đi chạy tay**, không phải tài liệu kỹ thuật. Sheet
`Test Cases_VN` là bản họ đọc nhiều nhất.

- **Mỗi bước một thao tác**, bắt đầu bằng động từ, khoảng 15 từ đổ lại:
  `2. Bấm nút "Save"` — không phải một đoạn văn mô tả cả luồng.
- **Thao tác nhìn thấy được.** "Mở menu Devices" chứ không phải "mở `/devices`";
  "Xoá trắng ô Vehicle Name" chứ không phải "clear field".
- **Expected mô tả cái hiện trên màn hình**, message trích nguyên văn trong nháy.
  Không viết "API trả 422" cho một case UI — tester không nhìn thấy mã đó.
- **Không thuật ngữ code** (`H1`, `div`, `mapper`, tên bảng DB). Nhãn UI tiếng Anh thì
  giữ nguyên trong nháy, phần diễn giải viết tiếng Việt.
- **Sheet VN là tiếng Việt tự nhiên**, không dịch máy móc từng chữ từ EN. Đọc lên phải
  thuận tai người Việt.

Case Type = `API` là ngoại lệ: người chạy nó cần đúng tên endpoint, payload và mã HTTP.

## Nguồn chân lý ngôn ngữ

Sheet **"Test Cases" (EN) là nguồn chân lý** — sinh trước, đầy đủ. Sheet
**"Test Cases_VN" là bản dịch phái sinh** — dịch từ EN sang, một chiều. Không bao
giờ sửa VN rồi mong EN tự đổi. Mọi công thức Summary đếm trên sheet EN.

## Template asset

`assets/template.xlsx` là template **rỗng** (đã xoá data mẫu, giữ khung, header,
dropdown, công thức Summary). Luôn **clone file này cho mỗi ticket mới**, KHÔNG sửa
trực tiếp file asset, KHÔNG append vào file cũ.

8 sheet: `Cover · Summary · Test Cases · Test Cases_VN · Common Validate ·
Defects & Follow-ups · Traceability · Assumptions & Questions`.

Mọi ô ticket-cụ-thể trong template để placeholder `<MODULE>` / `<SOURCE>` / `<VER>`
/ `<DATE>`. Placeholder sót lại trong output nghĩa là `cover` thiếu field —
`build.py` chặn từ trước, exit 1.

## Cấu trúc sheet "Test Cases" (bắt buộc tôn trọng)

- **Header chiếm row 1–5. Data test case bắt đầu từ row 6.**
  Row 1: tiêu đề; row 2: dòng source; row 4–5: header cột (Round 1/Round 2 là ô
  merge, có dòng con Result/Bug ID ở row 5).
- **14 cột A→N theo đúng thứ tự này** (12 *trường*, vì Round 1 và Round 2 mỗi cái
  chiếm 2 cột). Không đổi vị trí — công thức Summary phụ thuộc cột B/C/D/J/L:

  | Cột | Trường | Ghi chú |
  |---|---|---|
  | A | ID | `TC-{section}-{nnn}`, VD `TC-A-001` |
  | B | Section | tên section, dùng cho COUNTIF Summary |
  | C | Type | **chỉ nhận**: UI · Validation · Boundary · Negative · Functional · Business rule · API |
  | D | Priority | **chỉ nhận**: High · Medium · Low (do agent cung cấp) |
  | E | Test Case Title | kèm mã AC trong ngoặc nếu có, VD `(AC-01)` |
  | F | Precondition | điều kiện trước khi chạy |
  | G | Test Steps | nhiều bước dùng `\n` trong cùng một ô, đánh số `1. 2. 3.` |
  | H | Test Data | nhiều giá trị phân tách bằng ` · ` |
  | I | Expected Result | nhiều dòng dùng `\n`; message trích nguyên văn phải khớp mục D2 của checklist |
  | J–K | Round 1: Result · Bug ID | Result mặc định để `Not Run` |
  | L–M | Round 2: Result · Bug ID | Result mặc định để `Not Run` |
  | N | Note / Ref | VD `Xem giả định #12`, `Xem nhóm Text field ở Common Validate`. Hai nhãn máy đọc được, đặt ở **đầu** ô: **`[MANUAL] <lý do>`** cho case chờ chạy tay · **`[DATA-REQ] <điều kiện>`** cho case tự động hoá được nhưng cần dữ liệu môi trường. Vừa cần dữ liệu vừa không tự động hoá được → dùng `[MANUAL]` |

### Quy ước ID — KHÁC với checklist

Test case đánh ID **theo section, reset mỗi section**: `TC-A-001, TC-A-002...` rồi
sang section B lại `TC-B-001`. Checklist thì đánh số liên tục toàn tài liệu. Lý do
khác nhau: checklist để người *trỏ nhanh khi review*; test case để *nhóm theo vùng
chức năng*. Đừng lẫn hai quy ước.

### Giới hạn 12 section

Bảng **RESULT BY SECTION** ở sheet Summary có **12 slot** công thức. Ticket vượt quá thì
`build.py` **thoát với exit code 2** kèm `PROBLEMS`, không im lặng.

12 là thoải mái cho gần như mọi ticket, nên **chia theo cấu trúc thật của tính năng**,
đừng nghĩ tới giới hạn. Thật sự vượt thì gộp hai màn hình gần nhau và ghi lý do vào sheet
Assumptions, để người đọc sau biết đó là ràng buộc công cụ chứ không phải thiết kế.

Nới thêm nữa thì phải sửa `assets/template.xlsx`: **không dùng `openpyxl.insert_rows`** —
nó không dịch tham chiếu công thức, và làm hỏng merged cell của LEGEND. Cách đã chạy được
là chụp lại công thức dạng template hoá theo số dòng, gỡ merge, dựng lại vùng từ dòng 21,
rồi merge lại ở vị trí mới. Xem `reference/openpyxl-traps.md`.

### Section divider

Mỗi section mở đầu bằng **một row divider** riêng (chỉ điền cột A dạng
`A. Page & Navigation`, các cột khác để trống, row có fill màu như trong template).
Row divider KHÔNG phải test case — nó không được có giá trị ở cột B/C/D, nếu có thì
COUNTIF sẽ đếm nhầm.

### Marker `[MANUAL]` ở cột N

Case không tự động hoá được thì ghi Result = `Blocked` và cột N bắt đầu bằng
`[MANUAL]` + lý do. Đây không phải trang trí: `write_defects.py` dùng marker này để
**không** tạo defect cho case chờ chạy tay. Thiếu marker thì mỗi case manual đẻ ra
một bug rác gửi cho dev.

Lý do dùng `Blocked` thay vì thêm giá trị `Manual` vào dropdown: cột `Not Run` ở
Summary là công thức trừ (`B - Pass - Fail - Blocked - Impact`), nên thêm một trạng
thái mới sẽ bị gộp nhầm vào "Not Run" và làm `% Executed` sai.

## Giữ dropdown (data validation)

Template có 3 data validation kiểu list, phủ tới row 306:

- Cột C (Type): `UI,Validation,Boundary,Negative,Functional,Business rule,API`
- Cột D (Priority): `High,Medium,Low`
- Cột J & L (Result): `Pass,Fail,Blocked,Impact,Not Run`

Giá trị đổ vào các cột này **phải nằm đúng trong danh sách** — sai một chữ (VD
`Business Rule` viết hoa R, hay `NotRun` liền) sẽ vỡ validation. Khi đổ data bằng
openpyxl, KHÔNG xoá hay ghi đè các data validation này.

## Sheet Traceability (AC → TC)

Sheet này trả lời một câu duy nhất: **có AC nào chưa được test case nào phủ không.**
Đây là lớp bắt sót rẻ nhất của cả harness.

- Nguồn: mục **E2 (Bảng AC)** của checklist → field `acceptance_criteria` trong
  `cases.json`; và field `acs: ["AC-01", ...]` trên từng case.
- `build.py` dựng bảng `AC ID · Nội dung · Test Case IDs · Số TC · Coverage`.
- AC không có TC nào trỏ tới → `Coverage = MISSING` (đỏ, in đậm) và script **thoát
  với exit code 2**, kèm `PROBLEMS` liệt kê mã AC bị hở.
- Chiều ngược lại được phép: một case có `acs: []` (case suy luận thêm) là bình
  thường. Chỉ AC hở mới là lỗi.

**Đừng giao file khi còn `MISSING` chưa giải thích được.** AC thật sự ngoài scope
thì phải nằm ở mục D4 (Out of scope) của checklist, không phải trong danh sách AC.

## Cập nhật Cover (mỗi ticket mới)

Mỗi ticket tạo file mới từ template, nên phải thay metadata ở sheet Cover cho khớp
ticket hiện tại: Module Name, Version, Source/Spec (mã ClickUp + link Figma),
Create Date, và dòng RECORD OF CHANGE đầu tiên. Không để nguyên thông tin ticket mẫu.

## Sheet Defects & Follow-ups (dùng khi tạo bug)

Sheet này là "phiếu bug" — điểm bàn giao người ↔ agent. Cột:
`# · TC ID · Section · Title · Description · Round · Priority · Actual Result/Reason
· Bug ID/Ticket · Assignee · Fix Status`. Cột **Description** (E) và **Actual
Result** (H) là chỗ ghi nội dung bug; validation Fix Status ở cột K.

`scripts/write_defects.py` có 3 mode:

- `--mode fill` — với case Fail/Blocked ở **round mới nhất có kết quả**, APPEND
  dòng Defects; agent điền Actual từ log. Tự bỏ qua: case đã có Bug ID, case đã có
  dòng defect, case `[MANUAL]`, và case đã Pass ở round sau.
- `--mode read` — trả JSON các bug cần tạo = dòng chưa có Bug ID **và chưa có Fix
  Status**, kèm Steps/Expected lấy từ sheet Test Cases.
- `--mode writeback` — ghi Ticket ID về file, **khoá theo TC ID**.

### Ba quy tắc an toàn (mỗi cái từng gây mất dữ liệu thật)

1. **LUÔN APPEND, không lấp lỗ trống.** Dòng mới ghi sau dòng *cuối cùng* có TC ID.
   Lấp ô trống đầu tiên thì một dòng bị xoá ở giữa sẽ khiến lần fill sau đè mất các
   dòng bên dưới — kèm Actual người dùng đã review.
2. **KHOÁ THEO TC ID, không theo số dòng.** `writeback` nhận `{tc_id: ticket_id}`.
   Người dùng chèn/xoá một dòng giữa `read` và `writeback` là index lệch và Ticket
   ID gắn nhầm case.
3. **KHÔNG dùng "xoá dòng" làm tín hiệu từ chối.** Muốn nói "case này không tạo
   bug", đặt **Fix Status = "Won't fix"** (có sẵn trong dropdown cột K). Xoá dòng
   không giữ được ý định: case vẫn Fail và chưa có Bug ID nên lần fill sau nó quay lại.

Script tự tạo `<file>.bak` trước mọi lần ghi (tắt bằng `--no-backup`).

## Quy trình sinh file

Phần cơ khí (clone template, đổ 12 cột, chèn divider, giữ dropdown, nới range
Summary, cập nhật section table, cập nhật Cover) đã đóng gói trong `scripts/build.py`.
Ranh giới: **agent làm phần phán đoán** (nghĩ ra test case, gán Priority theo rủi ro,
viết Expected khớp message ở D2, dịch VN) rồi đóng gói thành JSON; **script làm phần
cơ khí**.

1. Chuẩn bị `cases.json` theo [reference/cases-json.md](reference/cases-json.md).
2. Chạy:
   ```
   bash .claude/scripts/qa-py.sh .claude/skills/testcase-template/scripts/build.py --input cases.json --template assets/template.xlsx --output <out.xlsx>
   ```
3. **Đọc exit code, đừng chỉ đọc stdout:**
   - `0` = sạch.
   - `1` = validate fail, **không sinh file**. Sửa JSON rồi chạy lại; đừng lách
     bằng cách bỏ field.
   - `2` = file sinh được nhưng có `PROBLEMS` (AC hở, hoặc quá số slot section).
     Phải xử lý trước khi giao.
4. Tính lại công thức: `bash .claude/scripts/qa-py.sh .claude/skills/testcase-template/scripts/recalc.py <out.xlsx> 60`
   (openpyxl xoá cache công thức khi save nên Summary sẽ trống cho tới bước này).
5. Kiểm: `total_cases` khớp số case; sau recalc, Total trên Summary == `total_cases`;
   sheet Traceability không còn `MISSING`.
6. Giao file, đặt ở `.qa/TLM-XXXX/`.

## Tự kiểm trước khi giao

- [ ] `build.py` thoát code 0 (hoặc code 2 đã xử lý xong `PROBLEMS`)
- [ ] File là bản clone mới, không phải sửa đè asset
- [ ] Cover đã thay metadata theo ticket hiện tại
- [ ] Data bắt đầu từ row 6; mỗi section có divider; ID reset theo section
- [ ] Cột C/D/J/L chỉ chứa giá trị hợp lệ trong dropdown
- [ ] Steps là thao tác nhìn thấy được, mỗi bước một việc; không thuật ngữ code
- [ ] Sheet VN đọc lên thuận tai người Việt, không phải dịch từng chữ
- [ ] Message trong Expected (cột I) khớp nguyên văn mục D2 của checklist
- [ ] Note (cột N) trỏ đúng số giả định / mục Common Validate khi cần
- [ ] Đã chạy `recalc.py`; Total trên Summary đúng
- [ ] Sheet VN đã dịch đầy đủ, ID/Type/Priority khớp sheet EN
- [ ] Sheet Traceability không còn dòng `MISSING`
- [ ] Không còn placeholder `<MODULE>` / `<SOURCE>` sót ở bất kỳ sheet nào
- [ ] Steps/Expected nhiều dòng hiển thị đủ (wrap bật, không bị ép chiều cao)
