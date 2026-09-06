# Chi tiết cơ chế Excel & bẫy openpyxl

Đọc file này khi **sửa `build.py` / `write_defects.py`**, hoặc khi phải thao tác
tay lên file .xlsx. Chạy quy trình bình thường thì không cần — script đã lo hết.

## Mục lục
- Style dòng data (script tự áp, không kế thừa template)
- Nới công thức Summary
- RESULT BY SECTION — dò động, không chèn/xoá dòng
- Làm sạch các sheet phụ
- Bẫy đã trả giá

---

## Style dòng data — script tự áp, KHÔNG kế thừa template

`write_cases` áp style **cứng trong code**, không đọc style của template. Lý do:
template chỉ có style tới row 5 ở sheet EN (divider ra trắng trơn) và có style rác
tới row 33 ở sheet VN (fill màu rơi ngẫu nhiên vào dòng test case).

Ba điểm bắt buộc:

- `wrap_text=True, vertical="top"` cho mọi ô data. Thiếu thì Steps và Expected
  nhiều dòng (`\n`) hiển thị dồn thành một dòng.
- **KHÔNG ép `row_dimensions[r].height`** cho dòng data. Ép cứng (VD 28) là cắt
  cụt nội dung đã wrap. Để `None` cho Excel tự autofit.
- `clear_data_region` xoá cả **giá trị lẫn style** trước khi đổ, để style rác của
  template không dính vào dòng mới.

## Nới công thức Summary (bước dễ quên nhất)

Sheet Summary đếm bằng `COUNTA/COUNTIF` trên các range **cố định `$6:$33`**:
`$B$6:$B$33 · $C$6:$C$33 · $D$6:$D$33 · $J$6:$J$33 · $L$6:$L$33`.

Template gốc chỉ tính tới row 33. Bộ test case vượt quá row 33 thì phải **nới các
range này tới row cuối cùng có data** — kể cả section divider ở giữa, vì
COUNTIF/COUNTA tự bỏ qua ô trống/không khớp nên nới rộng an toàn hơn nới thiếu.
Sau khi đổ hết data, đếm row cuối và cập nhật mọi công thức có tham chiếu
`'Test Cases'!$X$6:$X$33` thành `$X$6:$X${row_cuối}`.

Bỏ qua bước này thì Summary đếm thiếu case: thống kê sai mà file vẫn "mở được"
nên rất dễ lọt.

## RESULT BY SECTION — dò động, không chèn/xoá dòng

Bảng RESULT BY SECTION trong Summary (4 dòng mẫu) dùng tên section **cứng** của
ticket mẫu. Mỗi ticket có section khác nhau nên script ghi đè tên section thật vào
cột A các dòng này.

Vị trí bảng được **dò động** qua header "Section" ở cột A và đếm số slot có sẵn
công thức — không hard-code row. Template đổi layout thì script vẫn tìm đúng.

**KHÔNG chèn/xoá dòng ở vùng này.** `openpyxl.insert_rows` / `delete_rows` KHÔNG
tự dịch tham chiếu công thức (`$A28`...) của các bảng bên dưới (RESULT BY PRIORITY,
LEGEND), nên chèn/xoá sẽ làm các bảng đó **đếm nhầm ô** mà file vẫn recalc sạch —
lỗi âm thầm rất khó thấy.

**Nếu buộc phải nới bảng** (đã làm một lần, 4 → 12 slot): đừng dùng `insert_rows`. Cách
chạy được là chụp công thức của mọi dòng phía dưới ở dạng **template hoá theo số dòng**,
**gỡ hết merged cell** trong vùng bị dịch (LEGEND có `B33:J33`… và ghi vào merged cell sẽ
ném `MergedCell object attribute 'value' is read-only`), dựng lại toàn vùng từ dòng 21,
rồi merge lại ở vị trí đã dịch. Kiểm bằng cách build một ticket vượt số slot cũ và đối
chiếu RESULT BY SECTION cộng đúng Total.

Cách an toàn khi chỉ dùng bảng có sẵn: chỉ ghi đè trong khung slot có sẵn; section thừa thì xoá sạch cả
dòng (tên + công thức); ticket có nhiều section hơn số slot thì script **thoát với
exit code 2** kèm `PROBLEMS`, không phải in warning rồi đi tiếp. Section rơi ngoài
bảng làm RESULT BY SECTION không cộng khớp Total mà file vẫn mở bình thường.
Xử lý: gộp section, hoặc thêm dòng tay rồi tự dịch tham chiếu các bảng bên dưới.

## Làm sạch các sheet phụ

"Tạo file mới từ template" chỉ sạch nếu template asset đã được làm sạch **mọi**
sheet mang nội dung ticket-cụ-thể, không chỉ 2 sheet chính:

- **Test Cases / Test Cases_VN** — xoá data mẫu; header row 1–2 do script cập nhật
  theo ticket (đừng để sót dòng source cũ như `CU-1234`).
- **Assumptions & Questions** — template rỗng phần data, giữ header. Giả định của
  ticket do agent đổ vào.
- **Traceability** — giữ header, data do `build.py` đổ từ `acceptance_criteria`.
- **Common Validate** — GIỮ NGUYÊN. Đây là bản tra cứu tái dùng cho mọi màn hình,
  test case trỏ tới nó.
- **Defects & Follow-ups** — giữ header, data do agent/tester điền khi chạy test.

## Bẫy đã trả giá — đừng lặp lại

- **Template phải sạch data cũ ở CẢ HAI sheet EN và VN.** Dọn một sheet, quên sheet
  kia → data mới lẫn data cũ. Script có lớp phòng thủ `clear_data_region`, nhưng
  template asset vẫn nên sạch sẵn.
- **Vùng data không được còn merged cell.** Ghi vào ô merge sẽ lỗi read-only.
  Template asset đã gỡ merge ở row ≥6; tạo template mới phải gỡ tương tự.
- **`cell(r, c, None)` KHÔNG xoá giá trị sẵn có** trong openpyxl — phải gán
  `cell(r, c).value = None`. Bẫy này làm dòng section cũ không chịu biến mất.
- **TC ID trùng là lỗi im lặng nguy hiểm nhất.** `write_defects.py` dựng dict theo
  TC ID; ID trùng thì bản sau nuốt bản trước, và bản bị nuốt có thể chính là dòng
  đang Fail — case fail đó không bao giờ thành bug. `build.py` chặn từ đầu,
  `write_defects.py` chặn lần nữa; đừng gỡ hai lớp chặn đó.
- **openpyxl xoá cache giá trị công thức khi save.** Summary sẽ trống cho tới khi
  recalc hoặc mở bằng Excel. Chạy `scripts/recalc.py` sau MỌI lần script ghi file,
  kể cả `write_defects.py`.
- **openpyxl cũng làm rơi chart / image / pivot / comment.** Template hiện không có
  nên chưa vỡ — đừng thêm chart vào template rồi ngạc nhiên khi nó biến mất.
