---
name: common-validate
description: >-
  Bộ check validate chuẩn tái dùng cho mọi màn hình Telemax, gom theo loại field:
  text, email, password, number, checkbox/radio, dropdown, date, file upload,
  list/search/paging, API, và dữ liệu telematics (thiết bị offline, timezone, đơn
  vị đo, toạ độ/bản đồ, realtime). Dùng khi viết test case cho một form có field
  nhập liệu hoặc một endpoint, để không sót ca biên quen thuộc — empty, maxlength,
  ký tự đặc biệt, ranh giới số, sai định dạng, token lỗi. Kích hoạt cả khi người
  dùng chỉ nói "viết test cho field X", "phủ validate cho form này", "test API
  endpoint này".
---

# Common-validate

Nguồn tri thức để không sót ca biên khi viết test case — thứ con người dễ quên (VD
quên test paste vượt maxlength, quên năm nhuận, quên token hết hạn).

## Chọn nhóm rồi đọc đúng file

| Cần phủ | Đọc |
|---|---|
| Field nhập liệu, dropdown, date, upload, list/search/paging | [reference/web-fields.md](reference/web-fields.md) |
| Endpoint API | [reference/api.md](reference/api.md) |
| Màn hình/endpoint hiển thị dữ liệu từ thiết bị | [reference/telematics.md](reference/telematics.md) |

Chỉ đọc file tương ứng với thứ đang test. Màn hình có cả form lẫn dữ liệu thiết bị
thì đọc cả hai.

Skill KHÔNG tự đoán field nào thuộc nhóm nào. Người viết nhìn màn hình thật, với mỗi
field chọn (các) nhóm phù hợp. Một field có thể áp nhiều nhóm (VD ô "Email đăng
nhập" áp cả Text field lẫn Email). Field read-only (trang chi tiết chỉ hiển thị)
thường chỉ cần vài check hiển thị — default state, truncation, missing value — bỏ
qua các check nhập liệu.

## Đầu vào skill cần (đọc trước phần dưới)

Mỗi check chỉ thành test case dùng được khi có **3 thứ lấy từ nguồn thật**:

| Cần | Nguồn | Thiếu thì |
|---|---|---|
| Tên field / endpoint thật | màn hình, spec | Hỏi |
| Ràng buộc thật (maxlength, min/max, định dạng) | mục D1 của checklist, hoặc giả định độ tin Cao đã review ở mục F | **HỎI. Không lấy 255 hay bất kỳ số "chuẩn" nào làm thật** |
| Message thật, nguyên văn | mục D2 của checklist | **HỎI. Không viết "an error is displayed"** |

Đây là chỗ dễ đoán bừa nhất trong cả harness: test case đoán ràng buộc trông vẫn
đầy đủ và vẫn chạy được, nhưng nó đo sai thứ cần đo và không ai phát hiện ra.

## Nguyên tắc dùng (quan trọng nhất)

Mỗi dòng check trong các file reference là **khuôn trừu tượng**, KHÔNG phải test
case hoàn chỉnh. Khi áp vào một field thật, phải **cụ thể hoá 3 thứ**:

1. **Field thật** — thay "the field" bằng tên field thật trên màn hình (VD "Biển số").
2. **Data thật** — dùng giá trị đúng ràng buộc thật của field. Maxlength thật là 100
   thì dùng 99/100/101, không dùng 254/255/256.
3. **Message thật** — Expected phải trích **nguyên văn** message của hệ thống (lấy
   từ mục D2 của checklist), không dùng câu chung chung "an error is displayed".

Viết theo giọng tester đọc được: thao tác nhìn thấy trên màn hình, không thuật ngữ
code (xem mục "Giọng văn" ở skill `testcase-template`).

Một check chung → một test case cụ thể. Chép nguyên câu khuôn vào Expected là test
case vô nghĩa, vì nó không kiểm được message thật.

## Gán Type cho test case sinh ra

Dùng đúng bộ Type cố định của harness:
**UI · Validation · Boundary · Negative · Functional · Business rule · API**

Ánh xạ gợi ý: hiển thị mặc định → UI · sai định dạng/bắt buộc → Validation · ranh
giới độ dài/số/toạ độ → Boundary · nhập bậy/mất mạng/gửi lặp/dữ liệu bẩn từ thiết bị
→ Negative · luồng lưu thành công → Functional · ràng buộc nghiệp vụ và quy tắc
chuyển đổi đơn vị → Business rule · endpoint → API.

## Quan hệ với sheet "Common Validate" và skill `testcase-template`

- **Sheet "Common Validate"** trong file test case là bản tra cứu tĩnh, nằm sẵn
  trong template và đi theo mọi file. KHÔNG fill lại mỗi ticket, KHÔNG do skill này
  sinh ra.
- **Skill này** không đổ sheet, không sinh file. Nó là tri thức về *cần phủ gì*.
- Test case cụ thể được đổ vào sheet "Test Cases" qua skill `testcase-template`.

## Tự kiểm khi dùng

- [ ] Đã chọn đúng (các) nhóm cho từng field theo màn hình thật
- [ ] Mỗi check đã cụ thể hoá: field thật + data đúng ràng buộc thật + message nguyên văn
- [ ] Field read-only không bị nhồi check nhập liệu vô nghĩa
- [ ] Không chép nguyên câu khuôn vào Expected
- [ ] Test case sinh ra có Type gán đúng theo bộ Type cố định
- [ ] Màn hình/endpoint có dữ liệu từ thiết bị đã được soi nhóm telematics
- [ ] Case không tự động hoá được đã ghi rõ lý do để đánh dấu `[MANUAL]` khi chạy
