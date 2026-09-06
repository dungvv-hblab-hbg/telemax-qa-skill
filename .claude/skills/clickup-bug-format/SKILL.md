---
name: clickup-bug-format
description: >-
  Khuôn nội dung và quy ước field cho bug tạo trên ClickUp từ test case fail: bốn
  phần bắt buộc (Description, Steps to reproduce, Actual Result, Expected Result),
  cách điền priority/status/list/assignee, chống trùng trước khi tạo, và ghi Bug ID
  trả lại file test case. Dùng khi cần tạo bug hoặc defect trên ClickUp cho case
  Fail/Blocked, hoặc khi người dùng nói "tạo bug cho case này", "file bug lên
  ClickUp".
---

# clickup-bug-format

Khuôn để mọi bug từ harness lên ClickUp đồng nhất, đủ thông tin cho dev fix ngay,
không phải hỏi lại. Skill là phần TĨNH (bug trông thế nào); agent lo phần ĐỘNG (tạo
bug qua MCP sau khi người dùng duyệt).

Xem [../../qa-config.md](../../qa-config.md) cho list/space đích, tag, priority map,
status ban đầu và rule assign. Giá trị nào còn `CHƯA ĐIỀN` là điều kiện chưa thoả:
DỪNG và hỏi người dùng, không đoán.

Ví dụ một bug hoàn chỉnh: [assets/example-bug.md](assets/example-bug.md).

## Nguồn dữ liệu bug

Bug được tạo từ **sheet "Defects & Follow-ups"** (sau khi người dùng review: sửa
Actual, đánh Fix Status). Dữ liệu lấy qua `write_defects.py --mode read`, đã kèm sẵn
steps/expected từ sheet Test Cases. KHÔNG tự bịa nội dung ngoài những gì có trong file.

**Dòng cần tạo bug = chưa có Bug ID VÀ chưa có Fix Status.** Người dùng từ chối một
bug bằng cách đặt **Fix Status = "Won't fix"**, KHÔNG phải bằng cách xoá dòng — xoá
dòng thì lần retest sau case vẫn Fail, vẫn chưa có Bug ID, nên nó quay lại.

**Đọc bản LOCAL.** Nếu người dùng review trên Google Drive, phải tải file về ghi đè
bản local trước khi chạy `--mode read`. Đọc bản local trong khi họ sửa bản Drive là
đọc file cũ.

## Đầu vào skill cần

| Cần | Nguồn | Thiếu thì |
|---|---|---|
| Actual Result cụ thể | cột Actual của sheet Defects (agent điền từ log, người dùng đã review) | Hỏi. **Không viết "nó lỗi" hay mô tả chung chung** |
| Steps + Expected | sheet Test Cases, qua `--mode read` | Hỏi. Không tự viết lại các bước |
| List/Space ClickUp đích | `qa-config.md` | **Hỏi. Không đoán list** — tạo bug nhầm list là rác cho người khác dọn |
| Duyệt danh sách bug + assignee | người dùng | Không tạo bug khi chưa được duyệt |
| Quyết định khi có bug trùng | người dùng | Nêu bug cũ ra và hỏi dùng ID cũ hay tạo mới |

## Ngôn ngữ

Bug viết bằng **tiếng Anh** — cùng ngôn ngữ với sheet "Test Cases" (EN), là nguồn
chân lý mà Steps/Expected được lấy ra. Ngoại lệ: message hệ thống trích nguyên văn
giữ đúng ngôn ngữ gốc trong ngoặc kép.

## Chống trùng — với ClickUp, không chỉ với file

Trước khi tạo, **search ClickUp** theo TC ID và theo tiêu đề gần đúng
(`ClickUp:clickup_search`). Đã có bug mở cho cùng triệu chứng → **không tạo mới**:
lấy Ticket ID cũ đưa vào bugmap writeback và báo người dùng.

File chỉ chống trùng trong phạm vi chính nó; nó không biết tester khác đã raise gì.
Bỏ bước này là đường nhanh nhất để dev nhận 3 bug giống hệt nhau.

## Nội dung bug — 4 phần bắt buộc

**1. Description** — mô tả ngắn vấn đề: cái gì sai, ở màn hình/endpoint nào, ảnh
hưởng ra sao. Cột Description trong Defects trống thì tổng hợp từ Title + bối cảnh
(KHÔNG chép nguyên Title làm description).

Bug là tài liệu cho **dev**, nên chi tiết kỹ thuật ở Actual (status code, message
lỗi) là đúng chỗ. Nhưng **Description phải đọc hiểu được ngay** — nói cái gì sai ở màn
hình nào, ảnh hưởng ai, không mở đầu bằng tên class.

**2. Steps to reproduce** — các bước tái hiện, đánh số. Lấy từ **Test Steps** (cột G
sheet Test Cases). Phải đủ để người khác làm theo ra đúng lỗi.

**3. Actual Result** — hiện trạng thật khi lỗi. Lấy từ cột **Actual Result** của
Defects (agent đã điền từ log test, người dùng đã review). Cụ thể: message sai gì,
status code nào, hành vi lệch ra sao — không viết chung chung "nó lỗi".

**4. Expected Result** — kết quả đúng đáng lẽ phải xảy ra. Lấy từ **Expected Result**
(cột I). Nếu là message, trích nguyên văn.

## Tiêu đề bug

Ngắn, cụ thể, có ngữ cảnh: `[Màn hình/API] — <triệu chứng ngắn>`.
Ví dụ: `[Vehicle Detail] Missing error message when vehicle name is left empty`.
Tránh tiêu đề mơ hồ kiểu "Bug ở trang chi tiết".

## Truy vết & liên kết

- Ghi **TC ID** liên quan trong bug (để đối chiếu ngược file test case).
- Ghi **ticket gốc** (`TLM-XXXX`) để bug link ngược về yêu cầu. Ticket gốc không tồn
  tại (spec dán tay, khoá là `TMP-<slug>`) → ghi thẳng vào bug là chưa có ticket yêu
  cầu, đừng bỏ trống lặng lẽ: dev đọc bug sẽ không biết đối chiếu với cái gì.
- Nêu **môi trường** test.
- Đính screenshot/log nếu có (`ClickUp:clickup_attach_task_file`), không đính data
  nhạy cảm nguyên văn. Bug từ case UI thường đã có ảnh sẵn ở
  `.qa/TLM-XXXX/phase1/<TC-ID>-FAIL.png` (Phase 1) hoặc `telemax-e2e/test-results/`
  (chạy bằng code) — đính vào, đừng để dev phải tự dựng lại.

## Sau khi tạo bug

Bug tạo trên ClickUp sinh **Ticket ID dạng TLM-xxxx**. Ghi ID này trả lại file test
case:

```
bash .claude/scripts/qa-py.sh .claude/skills/testcase-template/scripts/write_defects.py --file <out.xlsx> --mode writeback \
  --bugmap '{"TC-A-003": "TLM-9001"}'
bash .claude/scripts/qa-py.sh .claude/skills/testcase-template/scripts/recalc.py <out.xlsx>
```

**Khoá theo TC ID, KHÔNG theo số dòng.** Giữa `--mode read` và `--mode writeback`,
chỉ cần người dùng chèn hoặc xoá một dòng trong Excel là mọi index dòng lệch đi và
Ticket ID sẽ gắn sang case khác — sai lặng lẽ, không có gì báo.

Script ghi vào cột "Bug ID/Ticket" của sheet Defects **và** cạnh Result của round
fail ở sheet Test Cases. Nhờ đó nhìn file biết ngay case nào đã có bug, và lần
retest `--mode read`/`fill` tự bỏ qua dòng đã có Ticket ID nên không tạo trùng.

## Ranh giới

- Skill chỉ định KHUÔN; KHÔNG tự tạo bug. Agent tạo qua ClickUp MCP, chỉ sau khi
  người dùng đã duyệt danh sách bug + assignee.
- KHÔNG tạo bug cho dòng đã có Bug ID, đã có Fix Status, hoặc case `[MANUAL]`.
- KHÔNG đính data khách/nhạy cảm nguyên văn vào bug.

## Tự kiểm trước khi tạo bug

- [ ] Đủ 4 phần: Description · Steps · Actual · Expected
- [ ] Tiêu đề cụ thể, có ngữ cảnh màn hình/API
- [ ] Có TC ID + môi trường
- [ ] Actual cụ thể (message/status thật), không chung chung
- [ ] Assignee đã được người dùng duyệt (hoặc để trống, ghi "assign tay")
- [ ] Đã search ClickUp chống trùng trước khi tạo
- [ ] List/Space đích trong `qa-config.md` đã điền (không còn `CHƯA ĐIỀN`)
- [ ] Sau khi tạo: ghi Bug ID về file bằng bugmap khoá theo TC ID
- [ ] Đã chạy `recalc.py` sau writeback
