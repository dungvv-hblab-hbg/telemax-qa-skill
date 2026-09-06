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
   D1 và cũng không có giả định độ tin Cao ở F** → hỏi tôi. **Tuyệt đối không lấy
   255 hay bất kỳ số "chuẩn" nào làm thật.**
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

Trước khi gọi agent, nói với tôi một dòng: muốn theo dõi tiến trình thì mở terminal
thứ hai và chạy `tail -f .qa/$1/progress.log`.

Gọi agent `testcase-writer` với:

```
TICKET: $1
CHECKLIST: .qa/$1/checklist_$1.md
OUTPUT_DIR: .qa/$1/
COVER: (module / version / source / create_date tôi đã xác nhận)
OUTPUT_FILE: (tên file tôi đã xác nhận)
ĐÃ LÀM RÕ: (các ràng buộc/message tôi vừa trả lời)
```

Sau khi agent kết thúc, báo bằng tiếng Việt:
1. Đường dẫn file Excel
2. Tổng số case, phân bố theo Type và Priority
3. **Độ phủ AC**: đã phủ bao nhiêu / tổng bao nhiêu. Còn AC nào `MISSING` thì nêu
   thẳng ra và nói rõ đây là lỗ hổng phải xử lý, không phải cảnh báo cho vui
4. Mọi `PROBLEMS` mà `build.py` trả về
5. Khối tổng kết đầu vào: tôi đã xác nhận gì, agent tự quyết gì (priority, chia
   section, gán Type), còn treo gì
6. Lời mời review: mở file, sửa/thêm/bớt case. Sửa xong muốn regenerate thì chạy
   lại `/qa-write-cases $1`; ổn rồi thì chạy `/qa-run $1`

Đừng tự chạy test.
