# Check chuẩn — endpoint API

Áp cho mọi endpoint có trong scope ticket. Cụ thể hoá status code và message theo
hợp đồng API thật, không dùng câu chung chung.

## Mục lục
- Happy path & schema
- Đầu vào sai
- Xác thực & phân quyền
- Vòng đời tài nguyên
- Phân trang & hiệu năng
- Rò rỉ thông tin

---

## Happy path & schema

Request hợp lệ trả 200/201, body đúng schema (đủ field, đúng kiểu, đúng tên).

## Đầu vào sai

Thiếu field bắt buộc (400/422) · sai kiểu dữ liệu · payload rỗng hoặc JSON hỏng
(phải 400, KHÔNG được 500).

## Xác thực & phân quyền

Token thiếu/sai/hết hạn → 401 · token của user khác → 403 và **không lộ data** của
user đó.

## Vòng đời tài nguyên

Resource không tồn tại → 404 · tạo trùng → 409 · gọi lặp cùng request
(idempotency): không tạo bản ghi thừa.

## Phân trang & hiệu năng

Phân trang đúng · `limit` vượt ngưỡng bị chặn thay vì trả toàn bộ · thời gian phản
hồi trong ngưỡng đã thống nhất.

## Rò rỉ thông tin

Message lỗi không lộ nội bộ: không stack trace, không tên bảng, không đường dẫn
file server.
