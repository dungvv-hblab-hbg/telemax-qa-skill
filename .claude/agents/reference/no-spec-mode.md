# Nhánh không-có-spec

**Ai đọc:** `/qa-analyze` (khi `spec-analyst` báo `SPEC_INSUFFICIENT: có`),
`test-analyst` (khi `MODE` không phải `checklist`), và `/qa-apply-feedback` (khi có
`spec-draft_<TICKET>.md`). Ticket bình thường **không đọc file này**.

Vì sao tách: ~2.800 token chỉ dùng ở một nhánh. Phần lớn ticket có spec, nạp nó mỗi
lần `/qa-analyze` là trả tiền cho tri thức không dùng.

Thay `<TICKET>` bằng mã thật ở mọi chỗ bên dưới.

---

## Vấn đề nhánh này giải

Ticket chỉ có tiêu đề ("Test Order Module"), hoặc không có ticket dev nào vì tính năng
làm từ lâu. Trạng thái **thường gặp**, không phải lỗi, và không đòi được cho có.

Nguy hiểm nếu cứ đi tiếp như bình thường: `test-analyst` vẫn dựng ra một checklist trông
như thật, nhưng mọi dòng đều suy từ chính code — test sinh ra từ đó **không bao giờ đỏ ở
đúng chỗ cần đỏ**, vì chuẩn để so chính là cái đang bị nghi sai.

Lối ra: đổi nguồn của vế "yêu cầu" từ ticket sang **hệ thống đang chạy** (`ui-explorer`,
black-box, vẫn cấm đọc code). Hai vế vẫn độc lập nên chỗ lệch vẫn có nghĩa — chỉ khác
là nó đọc thành "UI làm A, code làm B" thay vì "spec đòi A, code làm B".

Và thứ duy nhất khẳng định được mà không cần spec là **chuẩn phổ quát**: validate thiếu
ở BE, quyền không check, nhánh lỗi không xử, lệch nhất quán. Phần còn lại phải có người
phán — đó là việc của `spec-draft`.

---

## A. Cổng ở `/qa-analyze`

**Dựng danh sách phạm vi trước khi hỏi.** `code-analyst` đã xong; đọc `K3`/`K4` trong
`.qa/<TICKET>/analysis-code.md` để liệt kê màn hình/luồng/endpoint của module. Tick sẵn
thứ có UI, bỏ tick thứ không có UI. Đừng gọi thêm agent nào cho việc này.

Hỏi **một lượt duy nhất**, gộp cả phạm vi lẫn lựa chọn:

> `<TICKET>` "<tiêu đề>": 0 AC, mô tả <n> từ, không Figma, <có/không> commit gắn mã.
> Không dựng được checklist test — mọi dòng sẽ phải suy từ chính code.
>
> Phạm vi tôi thấy trong code:
> `[x] <màn hình A>  [x] <màn hình B>  [ ] <job nền, không UI>`
>
> **a)** Săn bug ngay, không cần spec — *mặc định*. Tôi dò hệ thống đang chạy, đối chiếu
>    với code, chỉ liệt kê thứ **sai bất kể yêu cầu là gì**.
> **b)** a + dựng **spec ngược** để bạn ký → thành spec thật, đẩy lên ticket, các lần
>    sau chạy `/qa-analyze` bình thường.
> **c)** Bạn bổ sung AC vào ticket, tôi chạy lại.

Nêu đúng một lần cái được/mất, đừng lặp ở các chặng sau:

| | Người dùng tốn | Được |
|---|---|---|
| a | 1 lượt duyệt bug | bug ngay, **không có docs**, không có test case Excel |
| b | thêm một lượt ký file | bug + spec cho module, dùng cho mọi lần sau |

Họ trả lời `a`/`b` kèm sửa phạm vi nếu muốn (`a, bỏ màn chi tiết`). Chọn `c` → ghi state
`analyze` = `skipped`, dừng, không chạy gì thêm.

**Trước khi gọi `ui-explorer`:** chặng này dùng trình duyệt thật. Kiểm **session còn
sống** — chưa đăng nhập thì bảo người dùng chạy `/qa-login` rồi quay lại. Đừng tự đăng
nhập, đừng hỏi mật khẩu qua chat.

```
ui-explorer:
TICKET: <TICKET>
SCOPE:  (danh sách đã tick, mỗi mục một dòng)
```

Xong → gọi `test-analyst`:
```
TICKET: <TICKET>
MODE: findings          (chọn a)  |  spec-draft  (chọn b)
UI_ANALYSIS:   .qa/<TICKET>/analysis-ui.md
CODE_ANALYSIS: .qa/<TICKET>/analysis-code.md
SCOPE: (như trên)
```

**Dùng lại `analysis-code.md` đã có**, đừng chạy lại `code-analyst` — nó vừa chạy xong
song song với `spec-analyst`, kết quả còn nguyên giá trị ở nhánh này.

### Báo lại sau nhánh này

1. `.qa/<TICKET>/findings_<TICKET>.md` — bao nhiêu finding, chia theo mức
2. Mỗi finding một dòng: chuẩn nào bị vi phạm. `test-analyst` loại dòng nào vì không dẫn
   được chuẩn thì nói rõ
3. Còn rác `QA-EXPLORE-*` trên staging không (`ui-explorer` báo ở mục A)
4. Mời chặng tiếp:
   - chọn `a` → đọc file, xoá dòng không đồng ý, rồi `/qa-file-bugs <TICKET>`
   - chọn `b` → thêm `.qa/<TICKET>/spec-draft_<TICKET>.md`: bao nhiêu dòng, **bao nhiêu
     dòng `❓`** (đó là số việc thật của người dùng). Mời ký trong file rồi chạy
     `/qa-apply-feedback <TICKET>`

**Nói thẳng một lần**: nhánh này không sinh test case Excel và không chứng minh hệ thống
làm đúng ý khách. Đừng nói giảm, cũng đừng nhắc lại ở mọi chặng sau.

Ghi state kèm nhánh đã đi — `.qa/<TICKET>/checklist_<TICKET>.md` sẽ không tồn tại, và
`/qa-status` không đoán được điều đó từ đâu ra:
```bash
bash .claude/scripts/qa-state.sh set <TICKET> analyze done    "KHÔNG SPEC · nhánh <a|b> · <n> finding · <n> dòng ❓"
bash .claude/scripts/qa-state.sh set <TICKET> analyze skipped "ticket rỗng, người dùng chọn tự bổ sung AC"
```

---

## B. Hai chế độ của `test-analyst`

Đầu vào đổi: thay `analysis-spec.md` bằng **`analysis-ui.md`** của `ui-explorer`.
`analysis-code.md` giữ nguyên.

Vế "yêu cầu đòi gì" **không tồn tại** ở đây. Đừng giả vờ có nó: không dựng mục C, không
gán mã AC, không xuất checklist. Hai vế bạn có là *UI thấy gì* và *code làm gì* — cả hai
đều là hiện trạng.

### `MODE: findings` — thứ sai mà KHÔNG cần spec

Ghi `.qa/<TICKET>/findings_<TICKET>.md`.

Chỉ đưa vào đây những thứ sai **bất kể khách muốn gì**. Mỗi dòng bắt buộc dẫn được
**chuẩn nào bị vi phạm** — không dẫn được thì nó không phải finding, nó là câu hỏi, đẩy
sang `spec-draft` (hoặc bỏ nếu đang ở `MODE: findings`). Hàng rào này giữ cho chặng
không biến thành bãi ý kiến cá nhân.

Nguồn chuẩn hợp lệ, theo thứ tự ưu tiên:

| Chuẩn | Ví dụ điều bắt được |
|---|---|
| **UI ≠ code** (`U2`/`U3` vs `K1`/`K2`) | FE chặn 200 ký tự, `K1` cho thấy BE không validate |
| `skill: common-validate` | field bắt buộc không báo lỗi khi bỏ trống |
| Nhất quán trong cùng `SCOPE` | màn A hiện giờ theo timezone user, màn B theo UTC |
| Nghiệp vụ telematics | thiết bị offline vẫn hiện toạ độ realtime |
| Nhánh lỗi / rỗng không xử (`U4`) | API 500 → spinner quay mãi |

Khuôn mỗi finding — `bug-proposer` đọc thẳng file này nên **giữ đúng nhãn**:

```markdown
### F-01 · [<màn hình>] <triệu chứng, một dòng>
- Mức: Critical | High | Medium | Low
- Chuẩn vi phạm: <chuẩn nào, nói rõ>
- Căn cứ UI: <U2/U3/U4 — quan sát gì>
- Căn cứ code: <file:dòng, hoặc "không có">
- Steps: 1. … 2. … 3. …
- Expected: <cái chuẩn đòi, KHÔNG phải cái bạn nghĩ khách muốn>
- Actual: <quan sát thật>
- Ảnh: <đường dẫn, hoặc "không có">
```

Đầu file ghi một khối cảnh báo, không được bỏ:

> Ticket này không có spec. Danh sách dưới đây **chỉ gồm thứ sai bất kể yêu cầu là gì**.
> Nó KHÔNG chứng minh hệ thống làm đúng ý khách — phần đó cần spec, xem `spec-draft`.

### `MODE: spec-draft` — thêm bản mô tả cho người ký

Làm **toàn bộ** phần `findings` ở trên, rồi ghi thêm
`.qa/<TICKET>/spec-draft_<TICKET>.md`.

Mô tả **mọi hành vi quan sát được** trong `SCOPE`, mỗi hành vi một dòng đánh số liên
tục, và **điền sẵn phán đoán** để người dùng chỉ phải sửa chỗ sai:

| Dấu | Khi nào điền sẵn | Kèm theo |
|---|---|---|
| `✅` | hành vi khớp quy ước chung, không có gì đáng ngờ | căn cứ (`U…`/`K…`) |
| `❌` | đã thành finding ở trên | trỏ `→ F-xx`, không chép lại nội dung |
| `❓` | **chỉ con người biết** — con số nghiệp vụ, quy tắc miền, ý định | **câu hỏi cụ thể**, không phải "cần xác nhận" |

`❓` đắt nhất cho người dùng nên đừng rải bừa; nhưng ràng buộc số mà không có chuẩn nào
bảo chứng thì **luôn** là `❓`, đừng ✅ cho xong.

```markdown
# Spec ngược (BẢN NHÁP, CHƯA DUYỆT) — <TICKET>
Mỗi dòng sửa dấu đầu dòng thành ✅ (đúng ý định) / ❌ (sai — sẽ thành bug) /
❓ (chưa biết — sẽ thành câu hỏi cho BA), sửa chữ nếu cần, rồi chạy
`/qa-apply-feedback <TICKET>`.

## <màn hình>
✅ 12. Danh sách mặc định sắp theo ngày tạo giảm dần. [U1]
❌ 13. Ô Ghi chú chặn 200 ký tự ở FE, BE không validate. → F-01
❓ 14. Order ở trạng thái Shipped vẫn huỷ được, không cảnh báo. [U4]
     Hỏi: nghiệp vụ có cho huỷ sau khi đã giao không?
```

**KẾT THÚC.** Báo: mấy finding theo mức, mấy dòng spec-draft chia theo ✅/❌/❓, và
**bao nhiêu dòng ❓** — đó là số việc thật của người dùng.

---

## C. Ký duyệt ở `/qa-apply-feedback`

Vẫn **chạy thẳng trong session chính**, không gọi subagent: việc ở đây là đọc chữ người
dùng ký và xin duyệt, mà xin duyệt thì phải chờ người được.

### 1. Đọc file đã ký, phân ba nhóm

| Dấu | Nghĩa | Đi đâu |
|---|---|---|
| `✅` | đúng ý định | thành spec chính thức |
| `❌` | sai | thành bug |
| `❓` | chưa trả lời | thành câu hỏi cho BA |

**Dòng `❓` mà người dùng đã viết câu trả lời ngay dưới** → tính là `✅`, dùng chữ của
họ, bỏ câu hỏi đi. Dòng `❓` còn trống thì vẫn là `❓`.

**Dòng không có dấu nào, hoặc bị sửa chữ mà ý không rõ** → **HỎI NGAY TẠI ĐÂY**, gộp mọi
câu vào một lượt. Đừng đoán, đừng bỏ qua lặng lẽ. Tuyệt đối không tự đổi `❓` thành `✅`
cho đủ bộ — dòng `❓` còn lại là thông tin thật: nó nói module này còn chỗ chưa ai biết
đúng sai.

### 2. Xin duyệt MỘT LÔ, trước khi ghi bất cứ đâu

```
✅ <n> dòng  → đăng làm mô tả của <TICKET> trên ClickUp
❌ <n> dòng  → thêm vào findings_<TICKET>.md (F-xx), chờ /qa-file-bugs
❓ <n> dòng  → đăng làm comment câu hỏi trên <TICKET>
```

Ba việc này đều **ghi ra ngoài**. Chưa gật thì chưa chạm vào ClickUp.

### 3. Ghi

**Luôn ghi bản local trước**: `.qa/<TICKET>/spec-signed_<TICKET>.md`, gồm nhóm `✅` đã
đánh số lại liên tục. Ghi local trước để ClickUp hỏng giữa chừng vẫn không mất chữ đã ký.

- **`✅` → ClickUp**: `ClickUp:clickup_update_task` đặt vào mô tả của `<TICKET>`, **nối
  thêm vào phần mô tả có sẵn**, đừng ghi đè tiêu đề hay nội dung đang có. Ticket dạng
  `TMP-<slug>` (không có ticket thật) → bỏ bước này, nêu rõ trong tổng kết và đề nghị
  tạo một ticket QA để neo. Thiếu MCP ClickUp → dừng đúng bước này, bản local đã an
  toàn, đừng làm lại từ đầu.
- **`❌` → `findings_<TICKET>.md`**: dòng đã trỏ `→ F-xx` thì thôi, đã có rồi. Dòng mới
  thì append `F-xx` tiếp theo, **giữ đúng khuôn ở mục B**. Không có "chuẩn vi phạm" thì
  lấy chính chữ người dùng ký làm chuẩn — họ đã phán nó sai, đó là căn cứ hợp lệ.
- **`❓` → comment**: `ClickUp:clickup_create_task_comment`, một comment gộp mọi câu hỏi,
  đánh số. Đừng tạo mỗi câu một comment.

### 4. Giữ chữ đã ký

Chuyển nội dung đã xử lý xuống `## Đã ký (YYYY-MM-DD)` ở cuối `spec-draft_<TICKET>.md` —
**KHÔNG xoá**, cùng lý do như section "Phản hồi review".

### 5. Báo lại & mời chặng tiếp

1. Ghi được những gì, ở đâu (local + link ClickUp)
2. Còn bao nhiêu `❓` chưa ai trả lời — nêu thẳng, đây là phần module vẫn chưa có chuẩn
3. Mời tiếp, **đúng thứ tự này**:
   - có `❌` → `/qa-file-bugs <TICKET>`
   - đã đăng spec lên ClickUp → **`/qa-analyze <TICKET>`** chạy lại từ đầu. Lần này
     `spec-analyst` đọc được AC thật nên ra checklist bình thường, rồi
     `/qa-write-cases <TICKET>` như mọi ticket khác.

Vì sao chạy lại cả `/qa-analyze` thay vì dựng thẳng checklist ở đây: nó **tự kiểm chứng**
spec vừa đăng có đọc lại được không. Spec chỉ nằm trong máy một người thì lần sau không
ai dùng được. Tốn thêm một lượt, và đó là chủ ý.
