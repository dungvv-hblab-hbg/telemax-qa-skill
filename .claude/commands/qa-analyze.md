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
   tiếp: dùng ID tạm `TMP-<slug-tính-năng>` cho thư mục `.qa/` **và thay cho mọi `$1`
   ở phần dưới** (`$1` rỗng làm `qa-state.sh` exit 2), mọi dòng checklist
   lấy từ nội dung dán gắn nhãn `[Chat]`, mục A ghi rõ chưa có ticket. Nêu một lần
   ba thứ sẽ mất — không đối chiếu lại được spec gốc, bug không link ngược về ticket,
   người khác không mở lại được nguồn — rồi tôn trọng quyết định của tôi, đừng nhắc
   lại ở các chặng sau. Đây là lối thoát khi tôi cố ý chọn, không phải một phương án
   ngang hàng để chào.
2. **Nhánh base để so diff** — mặc định **`stage`** (nhánh build ra dashboard-stage,
   `bash .claude/scripts/qa-config.sh ticket`). Không phải `dev`, không phải `master`. Nêu ra để tôi
   xác nhận hoặc đổi.

   Kiểm luôn **ticket đã có commit trên `origin/stage` chưa** (lệnh ở Bước 0 của skill
   `git-diff-scope`) rồi nêu cho tôi cách diff sẽ dùng: **đã merge → diff theo commit
   merge (`git diff <sha>^ <sha>`)**; **chưa merge → diff nhánh ba chấm**. **Đừng mặc
   định `stage...feature`** — ticket đã merge thì nhánh feature luôn cũ hơn `stage` và
   diff đó lôi vào công việc của người khác, im lặng, không có tín hiệu nào báo.
3. **Không tìm thấy commit/nhánh của ticket** — hỏi tôi: code chưa xong, hay ticket
   này không đụng code? Câu trả lời quyết định checklist có mục G hay không.
**Không hỏi về Figma ở đây.** Chỉ agent mới đọc ticket, nên hỏi "ticket có link
Figma không" ở cổng này là hỏi mù — hoặc tôi phải tự mở ClickUp trả lời, hoặc bạn
phải gọi `clickup_get_task` để rồi agent gọi lại lần nữa và giữ hai bản nội dung
ticket trong context. Agent tự xử: không thấy Figma thì ghi `[Cần hỏi]` ở mục A và
nêu trong khối "còn treo". Tôi có sẵn link ở tay thì tự đưa, không cần được hỏi.

Mọi thứ đọc được từ ticket/git thì dùng thẳng, không cần hỏi.

Trước khi gọi agent, nói với tôi một dòng: muốn theo dõi tiến trình thì mở terminal
thứ hai và chạy `tail -f .qa/$1/progress.log`.

## Chạy ba chặng: hai agent SONG SONG rồi một agent tổng hợp

```
spec-analyst  (chỉ spec, CẤM đọc code)  ─┐
                                         ├─►  test-analyst  ─►  checklist
code-analyst  (chỉ code + git diff)     ─┘     (tổng hợp)
```

**Vì sao tách:** một agent đọc cả spec lẫn code rồi dựng checklist sẽ mô tả *code
đang làm gì* thay vì *spec đòi gì* — và bug loại "code khác spec" trở nên vô hình vì
test được suy ra từ chính cái sai. Tách ra thì hai vế độc lập, và **chỗ chúng lệch
nhau** thành mục **D6** của checklist: sản phẩm giá trị nhất của chặng này.

Đắt hơn một agent, và đó là chủ ý — đổi token lấy test có nghĩa.

**Gọi hai agent đầu trong CÙNG MỘT message** để chúng chạy song song. Đừng chờ
`spec-analyst` xong mới gọi `code-analyst` — chúng không phụ thuộc nhau (một cái chỉ
cần ticket ID, cái kia chỉ cần ticket ID + nhánh base).

`spec-analyst`:
```
TICKET: $1
FIGMA: (link tôi đưa, hoặc "không có")
```

`code-analyst`:
```
TICKET: $1
BASE_BRANCH: (giá trị tôi đã xác nhận)
HAS_DIFF: (có / không — kèm lý do tôi đã nói)
```

Cả hai xong → gọi `test-analyst`:
```
TICKET: $1
SPEC_ANALYSIS: .qa/$1/analysis-spec.md
CODE_ANALYSIS: .qa/$1/analysis-code.md   (ghi "không có" nếu code-analyst báo không có diff và không đọc được gì)
```

`spec-analyst` **DỪNG** (không đọc được ticket) → dừng cả chặng, đừng gọi tiếp: không
có yêu cầu thì không có gì để test. `code-analyst` dừng hoặc không có diff → **vẫn
gọi** `test-analyst`, nó biết cách bỏ mục G và D6.

`spec-analyst` báo **`SPEC_INSUFFICIENT: có`** → **đừng gọi `test-analyst`**, sang cổng
ngay dưới đây.

## Cổng giữa — ticket không đủ dữ kiện để dựng checklist

Ticket chỉ có tiêu đề ("Test Order Module"), hoặc tính năng làm từ lâu không có ticket
dev nào. Đi tiếp như bình thường thì `test-analyst` vẫn dựng ra một checklist trông như
thật, nhưng mọi dòng đều suy từ chính code — test sinh ra từ đó **không bao giờ đỏ ở
đúng chỗ cần đỏ**. Dừng ở đây và để tôi chọn.

**Đọc `.claude/agents/reference/no-spec-mode.md`, mục A** rồi làm đúng theo: dựng danh
sách phạm vi từ `analysis-code.md` đã có, hỏi tôi MỘT lượt gồm cả phạm vi lẫn ba lựa
chọn, rồi gọi `ui-explorer` + `test-analyst` ở chế độ tương ứng. Đừng làm theo trí nhớ —
file đó giữ nguyên văn câu hỏi, khuôn đầu vào của agent, và cách ghi state cho nhánh này.

## Ghi trạng thái (bắt buộc — để `/qa-status` và resume dùng được)

**Ngay trước khi gọi agent:**
```bash
bash .claude/scripts/qa-state.sh set $1 analyze in_progress "bắt đầu phân tích"
```

**Ngay sau khi agent kết thúc**, kể cả khi hỏng — command vẫn sống sau agent, nên
đây là chỗ duy nhất ghi được cả trường hợp thất bại:
```bash
bash .claude/scripts/qa-state.sh set $1 analyze done   "<tóm tắt 1 dòng: bao nhiêu AC, bao nhiêu dòng D6>"
bash .claude/scripts/qa-state.sh set $1 analyze failed "<lý do dừng>"
```


Journal này là **nhật ký, không phải nguồn chân lý** — artifact trên đĩa mới là sự
thật. Đừng bỏ bước ghi: bỏ là `/qa-status` mù, và lần chạy sau không biết tiếp từ đâu.
