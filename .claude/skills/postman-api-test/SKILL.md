---
name: postman-api-test
description: >-
  Khớp các API cần test với bộ Postman collection sẵn có của team, chạy CHỌN LỌC
  bằng newman theo đúng scope ticket, rồi đọc kết quả pass/fail kèm status code và
  body lỗi thật để làm Actual Result. Dùng khi cần test API cho một ticket, kiểm
  endpoint bị ảnh hưởng bởi thay đổi code, hay chạy lại API test — kể cả khi người
  dùng nói "test API cho ticket này", "chạy API test", "kiểm endpoint X".
---

# Postman-api-test

Skill này là **cầu nối** giữa test case và bộ Postman collection sẵn có của team
(đã đầy đủ auth + test pass/fail). Nó KHÔNG viết lại API test từ đầu — tận dụng
collection team, chỉ bổ sung phần thiếu và chạy đúng phạm vi.

## Yêu cầu môi trường

`newman` (`npm install -g newman`) và collection + environment của team ở đường dẫn
khai báo trong [../../qa-config.md](../../qa-config.md).

## Ranh giới (đọc kỹ — tránh nhầm loại)

- Skill KHÔNG tự quyết **API nào cần test**. Việc đó là phán đoán của **agent**,
  suy ra từ 3 nguồn: (1) mô tả ticket, (2) input người dùng, (3) git diff các
  thay đổi liên quan API. Agent đưa cho skill *danh sách endpoint + case cần phủ*.
- Skill KHÔNG tự đăng nhập hay cầm token thật. Auth do collection/environment của
  team xử lý; skill chỉ dùng lại cơ chế đó.
- Skill lo: khớp endpoint ↔ request trong collection, bổ sung case còn thiếu theo
  đúng cấu trúc team, chạy chọn lọc bằng newman, đọc report.

## Vị trí collection

Collection KHÔNG nằm trong harness (`.claude/`). Nó là tài sản của team, sống trong
repo code cạnh source và thay đổi theo API thật. Harness chỉ *trỏ tới* nó; đường dẫn
khai báo trong [../../qa-config.md](../../qa-config.md).

Mục Postman trong `qa-config.md` có trường **Trạng thái**:

- **`CHƯA CÓ`** — team chưa dựng collection. Nhánh API được **skip**: case API ghi
  `Blocked` + Note `[MANUAL] chưa có Postman collection — chờ bổ sung`. Đây là trạng
  thái hợp lệ, không phải lỗi, và KHÔNG chặn nhánh UI. Skill này không được gọi.
- **`CÓ`** nhưng file không tồn tại ở đường dẫn khai báo — đó là sai cấu hình: DỪNG,
  báo người dùng. KHÔNG tạo collection rỗng, KHÔNG đoán vị trí khác.

Khi team bổ sung collection: đổi Trạng thái thành `CÓ`, chạy lại `/qa-run`; các case
đang mang marker `[MANUAL] chưa có Postman collection` sẽ được chạy thật ở round sau.

## Đầu vào skill cần

| Cần | Nguồn | Thiếu thì |
|---|---|---|
| Danh sách endpoint cần test | agent suy từ ticket / diff / input người dùng | Hỏi. Skill không tự chọn endpoint |
| TC ID tương ứng từng case | file test case Excel | Hỏi. Không tạo request không truy vết được |
| Đường dẫn collection + environment | `qa-config.md` | Trạng thái `CHƯA CÓ` → skip nhánh API, đánh `[MANUAL]`. Trạng thái `CÓ` mà file không có → dừng, báo |
| Auth | environment của team | Dừng, hướng dẫn người dùng cấu hình. **Không hỏi token qua chat** |

## Bước 1 — Khớp endpoint với collection sẵn có

Với mỗi endpoint agent đưa vào:
- **Đã có request trong collection** → dùng lại. Nếu test case Excel yêu cầu case
  chưa được phủ (VD 401 token hết hạn, 409 tạo trùng), **thêm assertion** vào tab
  Tests của request đó theo đúng style team đang dùng (`pm.test` + `pm.expect`).
- **Chưa có request** → thêm request mới, đặt đúng folder module, đặt tên theo
  quy ước team (VD `PUT /vehicles/{id} — update odometer`), kế thừa auth ở mức
  collection/folder (KHÔNG hardcode token trong request).

Mỗi request/case nên gắn **TC ID** từ file Excel trong tên hoặc test name để truy
vết ngược: `pm.test('TC-API-003 — thiếu field bắt buộc trả 422', ...)`.

## Bước 2 — Phủ case theo nhóm API của common-validate

Dùng `common-validate/reference/api.md` làm checklist phủ ca biên, cụ thể hoá theo
endpoint thật: request hợp lệ (2xx, đúng schema) · thiếu field bắt buộc (400/422) ·
sai kiểu · payload hỏng (400 không 500) · token thiếu/sai/hết hạn (401) · token user
khác (403, không lộ data) · không tồn tại (404) · tạo trùng (409) · idempotency khi
gọi lặp · phân trang/limit vượt ngưỡng · message lỗi không lộ nội bộ · thời gian
phản hồi trong ngưỡng.

Chỉ phủ case **liên quan tới thay đổi của ticket** — không nhồi toàn bộ 12 case
cho mọi endpoint nếu ticket chỉ động tới một phần.

## Bước 3 — Chạy CHỌN LỌC bằng newman (không chạy full collection)

Chủ trương: chỉ chạy đúng scope ticket, không chạy cả collection.

Cách cô lập phạm vi (ưu tiên từ dễ nhất):
- **Theo folder**: nếu collection tổ chức theo module, chạy đúng folder liên quan:
  ```
  newman run <collection.json> -e <env.json> --folder "Vehicles"
  ```
- **Theo collection con tạm**: nếu case cần test nằm rải, tạo một collection tạm
  chỉ chứa các request liên quan (export subset) rồi chạy collection tạm đó. Xóa
  sau khi chạy.
- Luôn truyền environment của team (`-e`) để có base URL + auth; KHÔNG nhét secret
  vào lệnh hay commit file env có token.

Xuất report máy-đọc-được để agent tổng hợp:
```
newman run <collection> -e <env> --folder "<module>" \
  -r cli,json --reporter-json-export .qa/TLM-XXXX/result.json
```

## Bước 4 — Đọc kết quả, bàn giao cho agent

Từ `result.json`, với mỗi assertion: lấy TC ID + pass/fail + thông điệp lỗi.
Bàn giao cho agent để:
- Ghi Result (`Pass`/`Fail`) vào cột Round của file Excel, đúng TC ID.
- Với case Fail: **giữ lại message lỗi thật + status code thật** từ `result.json`
  để agent điền vào cột Actual Result của sheet Defects. "Assertion failed" không
  đủ làm Actual — bug cần biết API trả gì.
- Việc tạo bug do `clickup-bug-format` + agent `bug-filer` lo, không thuộc skill này.

Case API **không** chạy được (thiếu môi trường, thiếu data) thì báo lại để agent
ghi `Blocked` + Note `[MANUAL] <lý do>` — đừng để case nằm `Not Run`.

## Bảo mật (ranh giới cứng)

- KHÔNG hardcode token/API key/password trong request, trong lệnh newman, hay
  trong file commit. Auth qua environment/collection variable của team.
- File environment chứa secret KHÔNG được commit (thêm vào .gitignore).
- Report (`result.json`) có thể chứa response nhạy cảm — không đính kèm nguyên
  văn vào bug công khai nếu có data thật; trích phần cần thiết.

## Tự kiểm

- [ ] Danh sách endpoint đến từ agent (ticket/diff), không tự bịa
- [ ] Đã khớp với collection sẵn có; chỉ thêm phần thiếu, không viết lại từ đầu
- [ ] Mỗi case gắn TC ID truy vết về Excel
- [ ] Chỉ phủ case liên quan scope ticket, không nhồi thừa
- [ ] Chạy CHỌN LỌC (folder/subset), không chạy full collection
- [ ] Không hardcode secret; env chứa token không bị commit
- [ ] Report json xuất ra để agent ghi Result + tạo bug
- [ ] Case Fail đã kèm status code + body lỗi thật để làm Actual Result
- [ ] Case không chạy được đã báo để đánh `[MANUAL]`, không bỏ lửng ở `Not Run`
