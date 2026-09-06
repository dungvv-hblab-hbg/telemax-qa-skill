---
description: Phân tích ticket Telemax -> file test-analysis checklist để bạn review
argument-hint: TLM-XXXX
---

Chạy chặng 1 của quy trình QA cho ticket **$1**.

## Cổng đầu vào — làm TRƯỚC khi gọi agent

Ba mức: **Chặn** = không có mặc định an toàn, phải hỏi · **Xác nhận** = có mặc định
nhưng mặc định vẫn là phán đoán, nêu ra chờ tôi gật · **Tự quyết** = chuyên môn của
bạn, làm luôn nhưng liệt kê trong tổng kết. Gộp mọi câu hỏi vào MỘT lượt, mỗi câu nêu
rõ mặc định đề xuất. Không bao giờ hỏi mật khẩu/token qua chat.

Chờ tôi trả lời xong mới gọi agent. Đừng đoán thay tôi.

1. **Ticket ID** — `$1` rỗng thì hỏi. Nếu tôi không đưa mà bạn suy từ tên nhánh
   (`git rev-parse --abbrev-ref HEAD | grep -oE 'TLM-[0-9]+'`) thì **hỏi xác nhận
   đúng ticket đó không**, đừng dùng thẳng.

   **Nếu tôi dán thẳng nội dung spec vào chat thay vì đưa mã ticket** — **DỪNG, chưa
   phân tích gì cả**, và bảo tôi tạo ticket trước:

   > "Nội dung này chưa có ticket. Tạo ticket ClickUp trước rồi quay lại đưa tôi mã
   > nhé — checklist, test case và bug sau này đều cần link ngược về ticket, còn nội
   > dung dán trong chat thì ba tháng nữa không ai mở lại được.
   >
   > Bạn tự tạo rồi chạy lại `/qa-analyze TLM-XXXX`, hoặc để tôi tạo giúp từ nội dung
   > bạn vừa dán — tôi dựng nội dung task đưa bạn duyệt trước, tạo xong là chạy tiếp
   > luôn với mã mới."

   - Tôi chọn để bạn tạo giúp → dựng nội dung task (tiêu đề, mô tả, AC tách thành
     danh sách), **đưa tôi duyệt rồi mới tạo** qua `ClickUp:clickup_create_task`.
     Không tự tạo. Tạo xong lấy mã trả về, chạy tiếp chặng phân tích luôn, không bắt
     tôi gõ lại lệnh.
   - Tôi chọn tự tạo → dừng ở đây, không phân tích. Tôi sẽ quay lại với mã ticket.

   **Chỉ khi tôi đã nghe nhắc mà vẫn nói rõ là cứ chạy không cần ticket** thì mới đi
   tiếp: dùng ID tạm `TMP-<slug-tính-năng>` cho thư mục `.qa/`, mọi dòng checklist
   lấy từ nội dung dán gắn nhãn `[Chat]`, mục A ghi rõ chưa có ticket. Nêu một lần
   ba thứ sẽ mất — không đối chiếu lại được spec gốc, bug không link ngược về ticket,
   người khác không mở lại được nguồn — rồi tôn trọng quyết định của tôi, đừng nhắc
   lại ở các chặng sau. Đây là lối thoát khi tôi cố ý chọn, không phải một phương án
   ngang hàng để chào.
2. **Nhánh base để so diff** — mặc định **`stage`** (nhánh build ra dashboard-stage,
   xem `.claude/qa-config.md`). Không phải `dev`, không phải `master`. Nêu ra để tôi
   xác nhận hoặc đổi.
3. **Không tìm thấy commit/nhánh của ticket** — hỏi tôi: code chưa xong, hay ticket
   này không đụng code? Câu trả lời quyết định checklist có mục G hay không.
4. **Ticket không có link Figma** — hỏi tôi có design ở đâu khác không, hay tính năng
   vốn không có UI.

Mọi thứ đọc được từ ticket/git thì dùng thẳng, không cần hỏi.

Trước khi gọi agent, nói với tôi một dòng: muốn theo dõi tiến trình thì mở terminal
thứ hai và chạy `tail -f .qa/$1/progress.log`.

Gọi agent `test-analyst` với:

```
MODE: analyze
TICKET: $1
BASE_BRANCH: (giá trị tôi đã xác nhận)
HAS_DIFF: (có / không — kèm lý do tôi đã nói)
FIGMA: (link tôi đưa, hoặc "không có")
```

Sau khi agent kết thúc, nói với tôi bằng tiếng Việt, ngắn gọn:
1. Đường dẫn file `.qa/$1/checklist_$1.md`
2. Tóm tắt: bao nhiêu mục, bao nhiêu AC, bao nhiêu câu hỏi độ tin **Thấp** (bắt
   buộc hỏi khách), có mục G (impact từ diff) hay không
3. Khối tổng kết đầu vào: tôi đã xác nhận gì, agent tự quyết gì (mức 3), còn treo gì
4. Lời mời review: mở file, ghi phản hồi vào section **"Phản hồi review"** ở cuối
   (tham chiếu bằng số: `#4 sai — maxlength thật là 100`), lưu lại, rồi chạy
   `/qa-apply-feedback $1`

Đừng tự đi tiếp sang viết test case.
