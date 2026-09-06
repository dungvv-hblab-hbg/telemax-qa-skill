# Check chuẩn — field nhập liệu & màn hình danh sách

## Mục lục
1. Text field
2. Email
3. Password
4. Number / Amount
5. Checkbox / Radio
6. Dropdown / Combobox
7. Date / Datepicker
8. File upload
9. List / Search / Paging

Mỗi dòng là **khuôn trừu tượng**, không phải test case hoàn chỉnh. Cụ thể hoá theo
field thật / data thật / message thật trước khi đưa vào file test case (xem phần
"Nguyên tắc dùng" trong SKILL.md).

---

## 1. Text field

Default state · valid input · empty hoặc chỉ khoảng trắng · dưới maxlength · đúng
maxlength · vượt maxlength · khoảng trắng đầu/cuối (trim) · ký tự đặc biệt · thẻ
HTML/script (escape, không thực thi) · ký tự đa byte & emoji · paste vượt giới hạn ·
ký tự xuống dòng.

## 2. Email

Đúng định dạng · sai định dạng · ký tự full-width/half-width · vượt maxlength ·
email trùng · phân biệt hoa/thường.

## 3. Password

Đạt policy · thiếu một loại ký tự bắt buộc · độ dài dưới/bằng/trên tối thiểu ·
toggle hiện/ẩn · confirm không khớp · chặn paste (nếu yêu cầu) · không lộ plain text
trong request/log.

## 4. Number / Amount

Số hợp lệ · nhập chữ vào ô số · số âm · số 0 · ranh giới min/max ±1 · thập phân &
làm tròn · dấu phân cách nghìn · số rất lớn (không overflow).

## 5. Checkbox / Radio

Default state · chọn & bỏ chọn (radio chỉ 1/nhóm) · chọn nhiều checkbox · bắt buộc
mà không chọn · trạng thái disabled.

## 6. Dropdown / Combobox

Default value & placeholder · danh sách & thứ tự option · option list rỗng · dropdown
phụ thuộc (reset khi đổi cha) · search trong dropdown · list option rất dài (>500).

## 7. Date / Datepicker

Chọn từ lịch · nhập tay sai định dạng · ngày quá khứ/tương lai · From > To · năm
nhuận (29/02) · timezone khi lưu & hiển thị (không lệch 1 ngày).

## 8. File upload

Đúng loại file · sai loại file · vượt giới hạn dung lượng · file rỗng 0KB · tên file
dài hoặc có ký tự đặc biệt · nhiều file (giới hạn số lượng) · huỷ hoặc mất mạng giữa
chừng · thay file đã có.

## 9. List / Search / Paging

List rỗng · sort từng cột (2 chiều, giữ filter) · filter kết hợp (AND) · search không
kết quả · search ký tự đặc biệt (`%`, `_`, `\`) không lỗi SQL · phân trang (ngưỡng
hiện/ẩn pager) · giữ filter khi back.
