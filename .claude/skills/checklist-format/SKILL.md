---
name: checklist-format
description: >-
  Định dạng chuẩn cho "test-analysis checklist" của Telemax: cấu trúc A–H, đánh số
  liên tục, nhãn nguồn, bảng AC, xuất ra FILE .md để người review duyệt trước khi
  viết test case. Dùng khi cần trình bày kết quả phân tích ticket + code thành
  checklist test — kể cả khi người dùng chỉ nói "phân tích ticket này", "cần test
  những gì", "làm checklist test", hay đang ở bước chuẩn bị trước khi gen test case.
---

# Checklist-format

Skill này định nghĩa **hình dạng** của một test-analysis checklist. Nó không
đọc ticket, không phân tích code, không quyết định khi nào dừng — những việc đó
là của agent gọi skill này. Nhiệm vụ duy nhất của skill: đảm bảo checklist xuất
ra luôn đúng cấu trúc, đúng quy ước, để người review quét được một lượt và phản
hồi bằng số thứ tự.

Ví dụ một checklist hoàn chỉnh (rút gọn): [assets/example-checklist.md](assets/example-checklist.md).

## Chia mục C theo màn hình

Mục C chia theo **màn hình / luồng người dùng**, không theo loại kiểm thử. Test case sẽ
kế thừa cách chia này thành section, và `test-runner` chạy theo thứ tự đó — case cùng
màn hình chạy liền nhau thì không phải tải lại trang giữa chừng, thứ mất 10–30 giây mỗi
lần trên SPA này.

## Đầu vào skill cần

Cần: ticket ID · nội dung ticket đọc được · biết CÓ hay KHÔNG có git diff (quyết định
mục G) · design nếu tính năng có UI. Thiếu thứ nào thì hỏi, không bịa. Spec dán thẳng
vào chat thay vì ticket → mọi dòng gắn nhãn `[Chat]`, mục A ghi rõ chưa có ticket.

Thông tin không đọc được thì dùng nhãn `[Cần hỏi]` — đó là cách checklist ghi nhận
chỗ chưa biết. **Không được thay `[Cần hỏi]` bằng một giá trị tự nghĩ ra rồi gắn
nhãn `[Suy luận]`**: suy luận là rút ra từ dữ kiện có thật, không phải điền chỗ trống.

## Ngôn ngữ

Toàn bộ checklist viết bằng **tiếng Việt**. Ngoại lệ duy nhất: nội dung message
hệ thống trích nguyên văn (mục D2) giữ đúng ngôn ngữ gốc trong ngoặc kép.

## Viết cho ai đọc

Người đọc checklist là **tester và BA**, không phải dev. Nhiều người trong số đó không
đọc code. Viết như hướng dẫn cho một tester mới vào làm.

- **Câu ngắn, một ý một dòng.** Dài quá thì tách, đừng nhồi mệnh đề.
- **Chủ ngữ là người dùng hoặc hệ thống**, không phải hàm/service/bảng.
  "Hệ thống chặn lưu và báo lỗi" — không phải "validator trả về false".
- **Gọi đúng tên nhìn thấy trên màn hình**: tên menu, tên nút, nhãn ô nhập. Nhãn UI
  đang là tiếng Anh thì giữ nguyên trong nháy (`ô "Vehicle Name"`, `nút "Save"`), phần
  diễn giải viết tiếng Việt.
- **Không dùng thuật ngữ code**: `H1`, `div`, `endpoint`, `mapper`, `DTO`, tên bảng
  DB, tên hàm. Không viết tắt nội bộ mà không giải thích.
- **Đường dẫn URL không thay được tên màn hình.** "Mở menu Devices" chứ không phải
  "mở `/devices`".

Ngoại lệ hợp lệ: mã HTTP và tên endpoint ở phần API — người chạy phần đó cần đúng
những thứ này. Nhưng phần UI thì không được dính.

## Quy ước chung (áp dụng toàn tài liệu)

1. **Đánh số chạy liên tục** từ `#1` (bắt đầu ở mục C; mục A và B không đánh số)
   đến hết toàn tài liệu — KHÔNG đánh lại từ 1 ở mỗi mục. Người review phản hồi bằng số: "sai #4, #11, còn lại OK". Số thứ
   tự là khớp nối để tham chiếu về sau (đặc biệt giữa mục F và file test case
   Excel), nên một khi đã gán số thì **giữ nguyên** qua các lần chỉnh sửa.
2. **Mỗi dòng có nhãn nguồn** đặt đầu dòng, cho biết thông tin đến từ đâu:
   - `[AC-xx]` — lấy từ spec/acceptance criteria (ghi rõ mã hoặc vị trí)
   - `[Comment]` — từ comment trong ticket
   - `[Figma]` — đọc từ design
   - `[Chat]` — người dùng **dán thẳng vào chat**, không có ticket để đối chiếu
   - `[Suy luận]` — AI tự suy ra, chưa có căn cứ trực tiếp
   - `[Cần hỏi]` — chưa có căn cứ, cần BA/Dev xác nhận

   Nhãn nguồn là phần quan trọng nhất của checklist: nó ép phân biệt rõ *cái
   biết chắc* với *cái đang đoán*, để người review biết chỗ nào cần soi kỹ.

   `[Chat]` khác `[AC-xx]` ở chỗ **không mở lại được**. Ba tháng sau, `[AC-03]` còn
   đối chiếu được với ticket; `[Chat]` thì nội dung gốc đã trôi mất trong lịch sử hội
   thoại của một người. Dùng nhãn này khi buộc phải, nhưng ghi ở mục A rằng ticket
   chưa tồn tại và nên tạo.
3. **Xuất ra FILE markdown** (không phải in trong chat). Người review cần một
   artifact lưu được, sửa/comment thẳng vào, và giữ lại làm đầu vào cho bước gen
   test case. Đường dẫn cố định: `.qa/TLM-XXXX/checklist_TLM-XXXX.md` — để dưới
   `.qa/` cho gọn repo và dễ gitignore, không rải ở gốc repo.
4. **Thêm mục mới thì APPEND số ở cuối tài liệu**, tuyệt đối không chèn số vào
   giữa và không đánh lại số. Số thứ tự là khoá tham chiếu ra cột Note của file
   Excel (`Xem giả định #12`); chèn giữa là mọi tham chiếu cũ trỏ sai. Mục bị bỏ
   thì đánh dấu `~~#11 (đã bỏ)~~`, giữ số, không tái sử dụng.
5. **Mã AC phải ổn định.** Ticket chưa đánh mã thì tự gán `AC-01`, `AC-02`… theo
   thứ tự xuất hiện và **giữ nguyên qua mọi lần sửa** — mã này đi thẳng vào sheet
   Traceability của file test case.

## Cấu trúc checklist — theo đúng thứ tự A → H

### A. Nguồn đã đọc  *(không đánh số)*

Liệt kê chính xác đã đọc được **những gì**, TRƯỚC khi nói bất cứ điều gì về nội
dung. Mục này tồn tại để bắt lỗi đọc nhầm/thiếu nguồn — thứ mà mọi mục sau không
bắt được.

- Ticket ClickUp: mã ticket, mở được hay không, đọc được bao nhiêu comment.
  **Không có ticket** (spec dán thẳng vào chat) → ghi thẳng ra ở đây, kèm câu
  "chưa có ticket — nội dung dán tay ngày <ngày>, nên tạo ticket để truy vết được".
  Đừng để mục A trông như đã đọc một nguồn chính thức
- Figma: liệt kê tên **từng frame** đã xem
- Tài liệu khác: API doc, spec cũ, file đính kèm
- Ghi rõ những gì **không** truy cập được và ảnh hưởng của nó

### B. Overview  *(không đánh số)*

3–5 dòng: tính năng làm gì, cho ai, kết quả cuối cùng là gì.

### C. Detail từng phần

Mỗi màn hình hoặc khối chức năng là một mục nhỏ, mô tả **luồng và hành vi**.

Checklist này để **tester dùng**, nên nguyên tắc chi phối là **phủ đủ mọi hành
vi cần test — không được sót case**. Đừng gò số dòng cho đẹp: ticket nhỏ thì C
ngắn, ticket dày (nhiều chục AC) thì C dài là bình thường và đúng. Thà dài mà đủ
còn hơn gọn mà sót.

Giới hạn duy nhất về nội dung: **KHÔNG nhét bảng field hay danh sách message vào
C** — chúng nằm ở phần D để quét được một lượt. C nói *"khối này làm gì, hành xử
ra sao"*; D liệt kê *"field/message cụ thể là gì"*. Nếu thấy mình đang liệt kê
field hay trích message trong C, đó là dấu hiệu nội dung đó thuộc về D.

### D. Các bảng tổng hợp (gom toàn tính năng)

Các bảng này gom dữ liệu của TẤT CẢ các phần ở C vào một chỗ để quét nhanh.

**D1. Bảng field**
`# · Thuộc phần · Tên field · Kiểu · Bắt buộc · Ràng buộc · Nguồn`

**D2. Danh sách message**
`# · Thuộc phần · Tình huống · Nội dung message (trích nguyên văn, trong ngoặc kép) · Nguồn`
Mọi câu thông báo sẽ dùng trong Expected Result về sau đều PHẢI có ở đây.

**D3. Business rule**
`# · Thuộc phần · Diễn giải rule bằng lời của AI · Nguồn`
Diễn giải lại chứ không chép nguyên văn — chép thì không chứng minh được là hiểu.

**D4. Out of scope**
`# · Hạng mục · Lý do hiểu là ngoài phạm vi · Nguồn`

**D5. Mâu thuẫn trong spec**
`# · Nội dung mâu thuẫn · Chỗ A nói gì (ở đâu) · Chỗ B nói gì (ở đâu) · Đang tạm theo bên nào`
BẮT BUỘC ghi rõ vị trí đọc được của cả hai bên, không chỉ nói "spec mâu thuẫn".

### E. Bảng có điều kiện  *(bắt buộc khi đủ điều kiện — không phải tùy chọn)*

**Role × quyền** — bắt buộc khi tính năng có từ **2 vai trò trở lên**.
`# · Vai trò · Xem được gì · Làm được gì · Nguồn`

**State & chuyển trạng thái** — bắt buộc khi bản ghi có **vòng đời**.
Liệt kê cả các chuyển đổi **bị cấm**.

### E2. Bảng AC  *(bắt buộc khi ticket có acceptance criteria)*

`Mã AC · Nội dung AC (tóm tắt) · Thuộc phần nào ở C · Nguồn`

Mục này là **nguồn của sheet Traceability** trong file test case. Mã ở đây phải
khớp chính xác mã mà `testcase-writer` gắn vào từng test case; sai một chữ là
build.py báo AC `MISSING` dù thực ra đã phủ.

Ticket không đánh mã AC → tự gán `AC-01`, `AC-02`… và ghi rõ vị trí gốc trong cột
Nguồn (VD `[AC-03] mục "Yêu cầu" gạch đầu dòng 3`).

### F. Giả định & câu hỏi cho BA/Dev

`# · Spec chưa nói gì · Giả định tạm dùng · Đề xuất của mình (kèm lý do ngắn) · Độ tự tin · Câu hỏi cụ thể cho khách`

Mục này không chỉ nêu câu hỏi treo — với mỗi điểm mờ, **đưa luôn một đề xuất
phương án tốt nhất** kèm lý do, để người dùng có thể mang đi hỏi khách/BA, hoặc
tự tin thì dùng luôn khỏi cần confirm. Cột **Độ tự tin** cho người dùng biết cái
nào xài được ngay, cái nào bắt buộc phải hỏi:

- **Cao** — đề xuất theo chuẩn phổ biến/an toàn (VD maxlength không nói → 255 theo
  chuẩn DB; định dạng ngày → theo convention hệ thống). Có thể **dùng luôn**; chỉ
  đổi nếu khách phản đối.
- **Vừa** — hợp lý nhưng có phương án thay thế; nên xác nhận nếu tiện, không thì
  dùng đề xuất và ghi rõ đã giả định.
- **Thấp** — thuộc nghiệp vụ riêng của khách, không suy đoán an toàn được (VD
  role nào được xoá bản ghi đã duyệt; ngưỡng cảnh báo theo hợp đồng). **Bắt buộc
  hỏi**, không tự quyết.

Đề xuất phải trung thực với độ tự tin — không gán "Cao" cho thứ thực chất là phán
đoán nghiệp vụ. Mục này là mắt xích tham chiếu: cột Note trong file test case Excel
trỏ thẳng vào số ở đây ("Xem giả định #12"), nên số thứ tự phải giữ nguyên về sau.
Khi một câu hỏi được trả lời, nó không còn là giả định — cập nhật lại và test case
liên quan viết theo câu trả lời thật.

### G. Impact / vùng ảnh hưởng từ code  *(chỉ xuất khi CÓ git diff)*

Mục này **chỉ xuất hiện khi ticket có git diff**. Nó tách bạch với phần chính:
- Phần chính của checklist (A–F) dựng từ **spec ClickUp** — "cần test hành vi gì".
- Mục này dựng từ **git diff** — "thay đổi code này *lan tới đâu*, vùng nào cần
  test hồi quy". Diff KHÔNG đẻ ra checklist chính; nó chỉ bổ sung lớp đánh giá
  ảnh hưởng.

`# · Vùng/module bị đụng · Vì sao (thay đổi gì trong diff) · Rủi ro hồi quy · Nguồn`

Cột "Vùng bị đụng" **viết bằng tên chức năng người dùng hiểu**, tên kỹ thuật để trong
ngoặc cho dev: `Phần cảnh báo pin (AlertCalculationService)`. Tester đọc cột này để
biết cần test lại chỗ nào — họ không tra được tên class.

Ví dụ: spec là "thêm màn hình cấu hình ngưỡng pin"; diff cho thấy nó sửa
`AlertCalculationService` dùng chung → dòng impact: "cảnh báo pin hiện có có thể
bị ảnh hưởng, cần test hồi quy phần cảnh báo cũ". Đây là vùng lan toả mà spec
không nói tới.

Khi KHÔNG có diff (code chưa xong / ticket không đụng code): **bỏ hẳn mục này**,
không để trống, không suy đoán impact khi chưa có căn cứ code.

### H. Kế hoạch test  *(chỉ xuất khi dự kiến trên 15 case)*

Bảng ước lượng quy mô theo `Section × Type`. Bộ Type dùng cố định:
**UI · Validation · Boundary · Negative · Functional · Business rule · API**
(bộ Type này phải trùng khớp với skill `testcase-template` để bước gen test case
khớp nối được — không tự đổi tên loại).

**Mỗi ô ghi mức S / M / L, KHÔNG ghi con số cụ thể.** Con số (5, 8, 12...) trông
như đã thiết kế test case xong, dễ gây hiểu nhầm; trong khi đây mới chỉ là ước
lượng độ lớn để người review thấy quy mô. Quy ước:
- `–` : section không có loại test đó
- `S` : ít (khoảng 1–3 case)
- `M` : vừa (khoảng 4–8 case)
- `L` : nhiều (trên 8 case)

Đây chỉ để người review thấy độ lớn, KHÔNG phải bản thiết kế test case chi tiết.
Ticket nhỏ (ước lượng ≤15 case) thì bỏ hẳn mục H (Kế hoạch test).

## Câu kết & section Phản hồi review

Cuối file checklist, thêm một section để người review viết phản hồi trực tiếp vào
file:

```markdown
---
## Phản hồi review
<!-- Viết phản hồi vào đây. VD:
  #4 sai — maxlength thật là 100, không phải 255
  #11 bỏ, không thuộc scope ticket
  #98 — khách xác nhận có role view-only, Edit ẩn với họ
  Còn lại OK.
Lưu file lại rồi chạy /qa-apply-feedback TLM-XXXX. -->

(để trống cho người review)
```

Cơ chế: người review ghi vào section này rồi lưu file → chạy
`/qa-apply-feedback TLM-XXXX` → Claude áp các chỉnh sửa vào đúng mục (theo số thứ
tự) → **chuyển nội dung phản hồi đã xử lý xuống section `## Đã xử lý (YYYY-MM-DD)`**.

**Chuyển, không xoá.** Đây là chữ của người dùng; parse sai một lần mà đã xoá thì
không lấy lại được, và cũng không truy được vì sao checklist đổi. Section "Đã xử
lý" nằm cuối file, người dùng tự dọn khi thấy đủ.

Giữ nguyên số thứ tự đã gán khi sửa; mục mới append số ở cuối.

Việc *đọc phản hồi, áp sửa, quyết khi nào checklist chốt* là hành vi luồng do
agent điều phối; skill chỉ quy định file phải có section này và định dạng của nó.

## Tự kiểm trước khi xuất

- [ ] Đọc lại như một tester mới vào: chỗ nào phải hỏi lại thì viết lại
- [ ] Phần UI không dính thuật ngữ code (`H1`, `endpoint`, tên class, tên bảng)
- [ ] Mục A đứng trước tiên, liệt kê nguồn đã/không đọc được
- [ ] Mọi dòng nội dung đều có nhãn nguồn
- [ ] Số thứ tự chạy liên tục toàn tài liệu, không reset theo mục
- [ ] C phủ đủ hành vi cần test, không sót case; field/message không lẫn vào C
- [ ] Mọi message dùng cho Expected Result đều có trong D2
- [ ] E xuất hiện nếu có ≥2 vai trò hoặc bản ghi có vòng đời
- [ ] E2 liệt kê đủ mọi AC, mã ổn định, mỗi AC trỏ về phần tương ứng ở C
- [ ] F: mỗi điểm mờ đều có đề xuất + độ tự tin; không gán "Cao" cho phán đoán nghiệp vụ
- [ ] **G** chỉ xuất khi CÓ git diff; không có diff thì bỏ hẳn, không suy đoán impact
- [ ] **H** chỉ xuất khi ước lượng >15 case; mỗi ô ghi S/M/L (không con số); đúng bộ Type
- [ ] Số thứ tự mới được append ở cuối, không chèn giữa, không đánh lại
- [ ] Xuất ra file `.qa/TLM-XXXX/checklist_TLM-XXXX.md`
- [ ] Kết thúc bằng section Phản hồi review để người dùng chỉnh sửa
