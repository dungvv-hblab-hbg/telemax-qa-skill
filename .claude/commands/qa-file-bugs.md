---
description: Đọc sheet Defects đã review, đề xuất bug -> bạn duyệt cả lô -> tạo bug ClickUp, ghi Ticket ID, upload Drive
argument-hint: TLM-XXXX
---

Tạo bug cho ticket **$1**.

Chặng này chạy **hai nửa, có một điểm dừng duyệt ở giữa**:

```
bug-proposer  ->  BẠN DUYỆT CẢ LÔ  ->  bug-filer
(đọc, dựng, chống trùng)              (tạo, writeback, upload)
```

Điểm duyệt nằm ở đây chứ không nằm trong agent, vì **subagent không dừng chờ người
được**. Trước đây nó nằm trong agent, nên hoặc agent tự duyệt cho mình (mất hàng rào
"con người bấm nút cuối"), hoặc nó kết thúc chặng và bạn phải chạy lại từ đầu.

## Cổng đầu vào — làm TRƯỚC khi gọi agent

Ba mức: **Chặn** = không có mặc định an toàn, phải hỏi · **Xác nhận** = có mặc định
nhưng mặc định vẫn là phán đoán, nêu ra chờ tôi gật · **Tự quyết** = chuyên môn của
bạn, làm luôn nhưng liệt kê trong tổng kết. Gộp mọi câu hỏi vào MỘT lượt, mỗi câu nêu
rõ mặc định đề xuất. Không bao giờ hỏi mật khẩu/token qua chat.

Gộp thành một lượt hỏi:

1. **Tôi đã review sheet Defects trên bản LOCAL hay trên Google Drive?** Là Drive
   thì dừng, yêu cầu tôi tải file về ghi đè bản local — script chỉ đọc bản local.
2. **File nào** trong `.qa/$1/` nếu có nhiều hơn một. Đừng tự chọn.
3. **List/Space ClickUp đích** — `bash .claude/scripts/qa-config.sh clickup`; còn
   `CHƯA ĐIỀN` thì hỏi tôi và bảo tôi cập nhật file đó. **Đừng đoán list.**
4. **Folder Google Drive đích** — hỏi **luôn ở lượt này**, kể cả khi chưa biết có bug
   nào. Đưa folder = đồng ý upload. Chưa muốn upload thì tôi nói rõ, bạn ghi
   `hỏi lại sau`. Đừng tự chọn thư mục gốc.

   Nêu cho tôi một dòng: file test case được upload ở **cuối chặng này** — kể cả khi
   ticket không có bug nào. Đây là chỗ duy nhất trong harness đưa file lên Drive.

Trước khi gọi agent, nói với tôi một dòng: muốn theo dõi tiến trình thì mở terminal
thứ hai và chạy `tail -f .qa/$1/progress.log`.

## Nửa 1 — gọi `bug-proposer`

```
TICKET: $1
TESTCASE_FILE: (file tôi đã chọn)
CLICKUP_LIST: (giá trị từ qa-config hoặc tôi vừa đưa)
```

Agent đọc Defects, dựng nội dung bug, đề xuất assignee, search ClickUp chống trùng,
ghi `.qa/$1/bugs-proposed.json`, rồi **kết thúc**. Nó không tạo gì cả.

## ĐIỂM DỪNG — trình bảng, xin duyệt MỘT lần cho cả lô

Đọc `.qa/$1/bugs-proposed.json` rồi trình cho tôi một bảng gọn:

| TC ID | Tiêu đề bug | Priority | Assignee đề xuất | Trùng? |
|---|---|---|---|---|

Nêu kèm: số dòng bị loại và lý do (`Won't fix hoặc bất kỳ Fix Status nào khác`, đã có Bug ID, `[MANUAL]`), và **mọi
bug nghi trùng** với bug đang mở trên ClickUp — với mỗi cái hỏi rõ tôi muốn **dùng ID
cũ** hay **vẫn tạo mới**.

Xin duyệt **một lần cho cả lô** (danh sách + assignee), không hỏi từng cái. Tôi có
thể bỏ bớt dòng, đổi assignee, hoặc đổi priority trong cùng lượt trả lời.

**Không gọi `bug-filer` khi tôi chưa đồng ý rõ ràng.**

### Danh sách rỗng → BỎ QUA nửa 2 phần tạo bug, nhưng VẪN upload

`bugs: []` thì không có gì để duyệt. Nói với tôi là ticket sạch, rồi gọi thẳng
`bug-filer` với `APPROVED_BUGS: []` để nó chạy bước upload. Đừng kết thúc ở đây —
ticket chạy sạch mà không upload là mất đúng cái đáng chia sẻ nhất.

## Nửa 2 — gọi `bug-filer`

```
TICKET: $1
TESTCASE_FILE: (file tôi đã chọn)
CLICKUP_LIST: (giá trị đã xác nhận)
DRIVE_FOLDER: (folder tôi đã chỉ, hoặc "hỏi lại sau")
APPROVED_BUGS: (danh sách tôi vừa duyệt — TC ID + mọi chỉnh sửa của tôi;
                với bug trùng: ghi rõ "dùng ID cũ TLM-xxxx" hay "tạo mới")
```

## Sau khi xong, báo bằng tiếng Việt

1. Bug đã tạo (TC ID → Ticket ID)
2. Bug dùng lại ID cũ, và bug bỏ qua kèm lý do (Won't fix / đã có Bug ID / tôi loại
   khi duyệt)
3. Bug tạo hỏng và lý do — nêu rõ chạy lại được, writeback khoá theo TC ID nên an toàn
4. Trạng thái upload Drive
5. Đường dẫn file local + link Drive
6. Khối tổng kết đầu vào: tôi đã xác nhận gì, còn treo gì

## Ghi trạng thái (bắt buộc — để `/qa-status` và resume dùng được)

**Ngay trước khi gọi agent:**
```bash
bash .claude/scripts/qa-state.sh set $1 file-bugs in_progress "tạo bug"
```

**Ngay sau khi agent kết thúc**, kể cả khi hỏng — command vẫn sống sau agent, nên
đây là chỗ duy nhất ghi được cả trường hợp thất bại:
```bash
bash .claude/scripts/qa-state.sh set $1 file-bugs done   "<tóm tắt 1 dòng: mấy bug đã tạo, upload chưa>"
bash .claude/scripts/qa-state.sh set $1 file-bugs failed "<lý do dừng>"
```

Journal này là **nhật ký, không phải nguồn chân lý** — artifact trên đĩa mới là sự
thật. Đừng bỏ bước ghi: bỏ là `/qa-status` mù, và lần chạy sau không biết tiếp từ đâu.
