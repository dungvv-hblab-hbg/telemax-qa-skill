---
description: Từ checklist đã review, sinh bộ test case Excel (kèm sheet Traceability)
argument-hint: TLM-XXXX
---

Sinh bộ test case cho ticket **$1**.

## Cổng đầu vào — làm TRƯỚC khi gọi agent

Ba mức: **Chặn** = không có mặc định an toàn, phải hỏi · **Xác nhận** = có mặc định
nhưng mặc định vẫn là phán đoán, nêu ra chờ tôi gật · **Tự quyết** = chuyên môn của
bạn, làm luôn nhưng liệt kê trong tổng kết. Gộp mọi câu hỏi vào MỘT lượt, mỗi câu nêu
rõ mặc định đề xuất. Không bao giờ hỏi mật khẩu/token qua chat.

Đọc checklist trước khi hỏi.

**Chặn (phải có câu trả lời mới chạy tiếp):**
1. Checklist còn phản hồi chưa xử lý, hoặc mục F còn câu hỏi độ tin **Thấp** chưa
   có trả lời → dừng, liệt kê đúng những câu đó, hỏi tôi.
2. Có field nào cần ràng buộc thật (maxlength, min/max, định dạng) mà **không có ở
   D1**, và ở F cũng **không có giả định độ tin Cao KÈM căn cứ đọc được** (schema
   DB, code validator, field tương tự — nêu rõ chỗ đọc) → hỏi tôi. Nhãn "Cao" trơn,
   không dẫn được căn cứ, **không tính**. **Tuyệt đối không lấy 255 hay bất kỳ số
   "chuẩn" nào làm thật.**
3. Có Expected Result nào cần message mà **không có trong D2** → hỏi, đừng tự viết
   câu chung chung.

**Xác nhận (nêu mặc định, chờ tôi gật hoặc sửa) — gộp chung vào lượt hỏi trên:**

| Giá trị | Mặc định đề xuất |
|---|---|
| `cover.module` | tên tính năng ở mục B của checklist |
| `cover.version` | `1.0`, hoặc tăng nếu `.qa/$1/` đã có file |
| `cover.source` | mã ClickUp + link Figma ở mục A |
| `cover.create_date` | hôm nay |
| Tên file output | `TCs_<Module>_v<ver>.xlsx` |

## Ghi câu trả lời vào checklist TRƯỚC khi gọi agent

**Chạy thẳng, không subagent.** Mỗi câu tôi trả lời ở cổng đầu vào → ghi một dòng
`#NN — <câu trả lời>` vào section **"Phản hồi review"** của checklist, rồi áp đúng quy
trình của `/qa-apply-feedback`: cập nhật mục F, đổi độ tin, và **chuyển nội dung đã xử
lý xuống section `## Đã xử lý (YYYY-MM-DD)`**.

Agent **chỉ đọc checklist**. Không truyền câu trả lời qua khối đầu vào — đường đó không
để lại dấu vết nào. Đã đo một lượt thật: trả lời ba câu mục F xong thì checklist **vẫn**
ghi cả ba là `Low`/`Blocking`, sheet `Assumptions & Questions` **0 dòng dữ liệu**, và
`state.json` ghi "không PROBLEMS" trong khi chặng trước vẫn ghi câu đầu "vẫn blocking".
Đóng session là mất quyết định, lần chạy sau lại chặn ở đúng câu hỏi đã trả lời, và
không truy được ai quyết gì, ngày nào.

Trước khi gọi agent, nói với tôi một dòng: muốn theo dõi tiến trình thì mở terminal
thứ hai và chạy `tail -f .qa/$1/progress.log`.

Gọi agent `testcase-writer` với:

```
TICKET: $1
CHECKLIST: .qa/$1/checklist_$1.md
OUTPUT_DIR: .qa/$1/
COVER: (module / version / source / create_date tôi đã xác nhận)
OUTPUT_FILE: (tên file tôi đã xác nhận)
```

Khối này **không có** `ĐÃ LÀM RÕ`. Câu trả lời đã nằm trong checklist ở bước trên —
một nguồn, có dấu vết, đọc lại được sau khi session đóng.

Sau khi agent kết thúc, báo bằng tiếng Việt:
1. Đường dẫn file Excel
2. Tổng số case, phân bố theo Type và Priority
3. **Độ phủ AC**: đã phủ bao nhiêu / tổng bao nhiêu. Còn AC nào `MISSING` thì nêu
   thẳng ra và nói rõ đây là lỗ hổng phải xử lý, không phải cảnh báo cho vui
4. Mọi `PROBLEMS` mà `build.py` trả về — trong đó **Note đánh dấu `[GĐ #NN]` mà sheet
   `Assumptions & Questions` không có dòng** là lỗi phải sửa trước khi giao file, không
   phải cảnh báo cho vui
5. **Số dòng `Assumptions & Questions`** đã ghi (`assumptions_written`). Bằng 0 trong
   khi mục F của checklist có câu hỏi được case dựa vào → nêu thẳng ra
6. Khối tổng kết đầu vào: tôi đã xác nhận gì, agent tự quyết gì (priority, chia
   section, gán Type), còn treo gì
7. Lời mời review: mở file, sửa/thêm/bớt case. Sửa xong muốn regenerate thì chạy
   lại `/qa-write-cases $1`; ổn rồi thì chạy `/qa-run $1`

Đừng tự chạy test.

## Ghi trạng thái (bắt buộc — để `/qa-status` và resume dùng được)

**Ngay trước khi gọi agent:**
```bash
bash .claude/scripts/qa-state.sh set $1 write-cases in_progress "sinh test case"
```

**Ngay sau khi agent kết thúc**, kể cả khi hỏng — command vẫn sống sau agent, nên
đây là chỗ duy nhất ghi được cả trường hợp thất bại:
```bash
bash .claude/scripts/qa-state.sh set $1 write-cases done   "<tóm tắt 1 dòng: bao nhiêu case, độ phủ AC>"
bash .claude/scripts/qa-state.sh set $1 write-cases failed "<lý do dừng>"
```

Journal này là **nhật ký, không phải nguồn chân lý** — artifact trên đĩa mới là sự
thật. Đừng bỏ bước ghi: bỏ là `/qa-status` mù, và lần chạy sau không biết tiếp từ đâu.
