---
description: Đọc sheet Defects đã review, tạo bug ClickUp, ghi Ticket ID về file, rồi hỏi upload Drive
argument-hint: TLM-XXXX
---

Tạo bug cho ticket **$1**.

## Cổng đầu vào — làm TRƯỚC khi gọi agent

Ba mức: **Chặn** = không có mặc định an toàn, phải hỏi · **Xác nhận** = có mặc định
nhưng mặc định vẫn là phán đoán, nêu ra chờ tôi gật · **Tự quyết** = chuyên môn của
bạn, làm luôn nhưng liệt kê trong tổng kết. Gộp mọi câu hỏi vào MỘT lượt, mỗi câu nêu
rõ mặc định đề xuất. Không bao giờ hỏi mật khẩu/token qua chat.

Gộp thành một lượt hỏi:

1. **Tôi đã review sheet Defects trên bản LOCAL hay trên Google Drive?** Là Drive
   thì dừng, yêu cầu tôi tải file về ghi đè bản local — script chỉ đọc bản local.
2. **File nào** trong `.qa/$1/` nếu có nhiều hơn một. Đừng tự chọn.
3. **List/Space ClickUp đích** — đọc `.claude/qa-config.md`; còn `CHƯA ĐIỀN` thì hỏi
   tôi và bảo tôi cập nhật file đó. **Đừng đoán list.**
4. **Folder Google Drive đích** (nếu sẽ upload) — không biết thì hỏi, đừng tự chọn
   thư mục gốc.

Trước khi gọi agent, nói với tôi một dòng: muốn theo dõi tiến trình thì mở terminal
thứ hai và chạy `tail -f .qa/$1/progress.log`.

Sau đó gọi agent `bug-filer` với:

```
TICKET: $1
TESTCASE_FILE: (file tôi đã chọn)
CLICKUP_LIST: (giá trị từ qa-config.md hoặc tôi vừa đưa)
DRIVE_FOLDER: (folder tôi đã chỉ, hoặc "hỏi lại sau")
```

Agent sẽ dừng xin duyệt danh sách bug + assignee **một lần cho cả lô** trước khi
tạo. Sau khi xong, báo bằng tiếng Việt:
1. Bug đã tạo (TC ID → Ticket ID)
2. Bug bỏ qua và lý do (Won't fix / đã có Bug ID / trùng với bug đã có trên ClickUp)
3. Trạng thái upload Drive
4. Đường dẫn file local + link Drive
5. Khối tổng kết đầu vào: tôi đã xác nhận gì, còn treo gì
