---
description: Áp phản hồi review vào checklist — hoặc, với ticket không có spec, đọc spec ngược bạn đã ký và đẩy lên ClickUp
argument-hint: TLM-XXXX
---

Áp phản hồi review vào checklist của ticket **$1**.

**Chặng này chạy THẲNG trong session chính, không gọi subagent.** Nó chỉ đọc một file
`.md` local, sửa vài mục theo số thứ tự, rồi ghi lại — không MCP, không ticket, không
Excel, output nhỏ. Đưa vào subagent thì mất ~8.500 token cho một việc vài tool call,
và **mất luôn khả năng hỏi lại**: phản hồi mơ hồ là đúng lúc cần hỏi, mà subagent thì
không dừng chờ người được — nó buộc phải kết thúc và bạn chạy lại lệnh từ đầu.

## Chọn nhánh TRƯỚC — hai loại file, hai việc khác nhau

| File có trong `.qa/$1/` | Nhánh |
|---|---|
| `checklist_$1.md` | **áp phản hồi review** — phần còn lại của file này |
| `spec-draft_$1.md` | **ký duyệt spec ngược** — mục "Nhánh ký duyệt" ở cuối |
| cả hai | hỏi tôi muốn làm cái nào. Đừng tự chọn |
| không cái nào | dừng, bảo tôi chạy `/qa-analyze $1` trước |

## Cổng đầu vào

1. File `.qa/$1/checklist_$1.md` tồn tại không? Không → dừng, bảo tôi chạy
   `/qa-analyze $1` trước.
2. Section **"Phản hồi review"** có nội dung không? **Rỗng thì KHÔNG hỏi lại** —
   nói thẳng một lượt rồi kết thúc:

   > Section "Phản hồi review" đang rỗng nên checklist giữ nguyên. Ổn rồi thì chạy
   > `/qa-write-cases $1`; còn muốn sửa thì ghi vào section đó rồi chạy lại lệnh này.

   Vẫn KHÔNG được hiểu rỗng thành "đã áp xong hết" hay tự báo là đã cập nhật —
   checklist không đổi một chữ nào.

## Áp phản hồi

Đọc section "Phản hồi review", áp từng mục vào **đúng số thứ tự** tương ứng.

- **Giữ nguyên số đã gán.** Mục mới **append số tiếp theo ở cuối tài liệu**, tuyệt
  đối không chèn số vào giữa — cột Note của file Excel trỏ theo số này, chèn giữa là
  mọi tham chiếu cũ trỏ sai. Mục bị bỏ thì đánh `~~#11 (đã bỏ)~~`, giữ số, không tái
  sử dụng.
- **Câu hỏi mục F được trả lời** → không còn là giả định; ghi lại câu trả lời thật,
  và đổi độ tin cho đúng. Ràng buộc số của field vẫn phải có căn cứ mới được lên
  "Cao" (xem `skill: checklist-format`).
- **Phản hồi trỏ số không tồn tại (VD `#99`), hoặc mơ hồ ("#4 sai" mà không nói sai
  chỗ nào)** → **HỎI TÔI NGAY TẠI ĐÂY**, gộp mọi câu vào một lượt. Đừng tự sửa theo
  phỏng đoán, và đừng bỏ qua lặng lẽ. Đây chính là lý do chặng này không dùng agent.
- **Sau khi áp xong, CHUYỂN nội dung phản hồi đã xử lý xuống section
  `## Đã xử lý (YYYY-MM-DD)`** ở cuối file — **KHÔNG xoá**. Đó là chữ của người dùng;
  parse sai một lần mà đã xoá thì không lấy lại được, và cũng không truy được vì sao
  checklist đổi. Section "Phản hồi review" để lại rỗng cho vòng sau.

## Báo lại

1. Đã áp những mục nào (theo số), mỗi mục một dòng ngắn nói đổi gì
2. Câu hỏi mục F nào đã được trả lời, còn treo mấy câu độ tin **Thấp**
3. Còn câu hỏi Thấp chưa trả lời → nói rõ **chưa nên** viết test case, và liệt kê
   đúng những câu cần hỏi khách/BA
4. Đã sạch → mời chạy `/qa-write-cases $1`

Nhắc lại một lần nếu tôi vẫn muốn đi tiếp khi còn câu hỏi treo, rồi tôn trọng quyết
định của tôi.

## Ranh giới

- KHÔNG viết test case, KHÔNG tạo file Excel — đó là `/qa-write-cases`.
- KHÔNG tự confirm thay người review, KHÔNG tự đổi `❓` thành `✅`.
- KHÔNG ghi lên ClickUp trước khi tôi duyệt cả lô.
- KHÔNG xoá section "Phản hồi review" — chuyển xuống "Đã xử lý".

## Nhánh ký duyệt — `spec-draft_$1.md`

`/qa-analyze` đã đi nhánh không-có-spec và tôi đã ký ✅/❌/❓ trong file.

**Đọc `.claude/agents/reference/no-spec-mode.md`, mục C** rồi làm đúng theo: phân ba
nhóm, xin duyệt MỘT lô, ghi bản local trước rồi mới đăng ClickUp. Vẫn chạy thẳng trong
session chính, không gọi subagent.

Một điều phải nhớ trước khi mở file đó: **không tự đổi `❓` thành `✅`**. Dòng `❓` còn
lại là thông tin thật — nó nói module này còn chỗ chưa ai biết đúng sai.

## Ghi trạng thái (bắt buộc — để `/qa-status` và resume dùng được)

**Ngay trước khi bắt đầu áp** (chặng này chạy thẳng, không gọi agent):
```bash
bash .claude/scripts/qa-state.sh set $1 apply-feedback in_progress "áp phản hồi"
```

**Ngay sau khi áp xong**, kể cả khi phải dừng vì phản hồi mơ hồ:
```bash
bash .claude/scripts/qa-state.sh set $1 apply-feedback done   "<tóm tắt 1 dòng: áp mấy mục, còn mấy câu Thấp>"
bash .claude/scripts/qa-state.sh set $1 apply-feedback failed "<lý do dừng>"
```

Journal này là **nhật ký, không phải nguồn chân lý** — artifact trên đĩa mới là sự
thật. Đừng bỏ bước ghi: bỏ là `/qa-status` mù, và lần chạy sau không biết tiếp từ đâu.
