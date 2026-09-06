---
description: Đọc section "Phản hồi review" trong checklist và cập nhật lại checklist
argument-hint: TLM-XXXX
---

Áp phản hồi review vào checklist của ticket **$1**.

## Cổng đầu vào — làm TRƯỚC khi gọi agent

Ba mức: **Chặn** = không có mặc định an toàn, phải hỏi · **Xác nhận** = có mặc định
nhưng mặc định vẫn là phán đoán, nêu ra chờ tôi gật · **Tự quyết** = chuyên môn của
bạn, làm luôn nhưng liệt kê trong tổng kết. Gộp mọi câu hỏi vào MỘT lượt, mỗi câu nêu
rõ mặc định đề xuất. Không bao giờ hỏi mật khẩu/token qua chat.

1. File `.qa/$1/checklist_$1.md` tồn tại không? Không → dừng, bảo tôi chạy
   `/qa-analyze $1` trước.
2. Section **"Phản hồi review"** có nội dung không? **Rỗng thì hỏi tôi**, đừng hiểu
   là "OK hết" rồi báo xong.
3. Đọc lướt phản hồi, gộp thành một lượt hỏi nếu có:
   - số thứ tự không tồn tại trong checklist (VD `#99`) → hỏi tôi ý là mục nào;
   - phản hồi mơ hồ kiểu "#4 sai" mà không nói sai chỗ nào → hỏi lại, **đừng tự sửa
     theo phỏng đoán**.

Trước khi gọi agent, nói với tôi một dòng: muốn theo dõi tiến trình thì mở terminal
thứ hai và chạy `tail -f .qa/$1/progress.log`.

Gọi agent `test-analyst` với:

```
MODE: apply-feedback
TICKET: $1
FILE: .qa/$1/checklist_$1.md
```

Sau khi agent kết thúc, báo bằng tiếng Việt:
1. Đã áp những mục nào (theo số)
2. Câu hỏi mục F nào đã được trả lời, còn treo mấy câu độ tin **Thấp**
3. Nếu còn câu hỏi Thấp chưa trả lời: nói rõ **chưa nên** viết test case, và liệt
   kê đúng những câu cần hỏi khách/BA
4. Khối tổng kết đầu vào: đã hỏi & xác nhận gì, còn treo gì
5. Nếu đã sạch: mời chạy `/qa-write-cases $1`

Nhắc lại một lần nếu người dùng vẫn muốn đi tiếp khi còn câu hỏi treo, rồi tôn
trọng quyết định của họ.
