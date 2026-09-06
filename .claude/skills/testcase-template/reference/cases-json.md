# Cấu trúc `cases.json` — đầu vào của `build.py`

## Mục lục
- Khung tổng thể
- `cover` — metadata sheet Cover
- `acceptance_criteria` — nguồn sheet Traceability
- `sections` / `cases` — nội dung test case
- Ràng buộc validate (nguyên nhân exit code 1)
- Ví dụ tối thiểu chạy được

---

## Khung tổng thể

```json
{
  "cover": { ... },
  "acceptance_criteria": [ ... ],
  "sections": [ { "divider": "...", "cases": [ ... ] } ]
}
```

## `cover` — metadata sheet Cover

| Field | Bắt buộc | Ghi chú |
|---|---|---|
| `project` | không | Mặc định `"Fleet Management"` |
| `module` | **có** | Tên màn hình/tính năng, VD `"Vehicle Detail Page"` |
| `version` | **có** | VD `"1.0"` |
| `source` | **có** | Mã ClickUp + link Figma, VD `"ClickUp TLM-2899 · Figma: /file/xxx"`. Chưa có ticket → `"Dán tay trong chat, chưa có ticket — 2026-08-30"`, đừng bịa mã |
| `create_date` | **có** | Định dạng `YYYY-MM-DD` |
| `change_desc` | không | Dòng đầu của RECORD OF CHANGE |

Thiếu một trong 4 field bắt buộc → `build.py` exit 1, không sinh file. Đây cũng
là lớp chặn placeholder `<MODULE>` / `<SOURCE>` sót lại trong output.

## `acceptance_criteria` — nguồn sheet Traceability

Lấy từ **mục E2 (Bảng AC)** của checklist đã review. Tuỳ chọn, nhưng có thì
`build.py` mới dựng được Traceability và mới bắt được AC hở.

```json
"acceptance_criteria": [
  { "id": "AC-01", "text": "Mở trang chi tiết từ danh sách Devices" },
  { "id": "AC-02", "text": "Tiêu đề hiển thị tên xe, không phải biển số" }
]
```

Mã `id` phải khớp **chính xác** mã trong checklist và mã trong `acs` của từng
case. Sai một chữ là AC bị báo `MISSING` dù thực ra đã phủ.

## `sections` / `cases`

```json
"sections": [
  {
    "divider": "A. Page & Entry",
    "cases": [
      {
        "id": "TC-A-001",
        "section": "Page & Entry",
        "type": "Functional",
        "priority": "High",
        "acs": ["AC-01"],
        "title_en": "...",     "title_vn": "...",
        "precond_en": "...",   "precond_vn": "...",
        "steps_en": "1. ...\n2. ...",     "steps_vn": "1. ...\n2. ...",
        "data_en": "...",      "data_vn": "...",
        "expected_en": "1. ...\n2. ...",  "expected_vn": "1. ...\n2. ...",
        "note_en": "",         "note_vn": ""
      }
    ]
  }
]
```

| Field | Bắt buộc | Ghi chú |
|---|---|---|
| `divider` | có | Chữ cái đầu phải khớp phần giữa của ID: `A. ...` ↔ `TC-A-xxx` |
| `id` | có | Đúng pattern `TC-<CHỮ/SỐ>-<3 chữ số>`, duy nhất toàn file |
| `section` | có | Dùng cho COUNTIF ở Summary; nên khớp phần chữ của `divider` |
| `type` | có | Chỉ 7 giá trị: `UI` `Validation` `Boundary` `Negative` `Functional` `Business rule` `API` |
| `priority` | có | `High` / `Medium` / `Low` — do agent quyết theo rủi ro |
| `acs` | không | Danh sách mã AC case này phủ; `[]` là hợp lệ (case suy luận thêm) |
| `*_en` | có (title/steps/expected) | Sheet EN là nguồn chân lý |
| `*_vn` | có (title/steps/expected) | Bản dịch phái sinh; thiếu → exit 1 |
| `note_en` / `note_vn` | không | Cột N. Case chờ chạy tay phải bắt đầu bằng `[MANUAL]` |

Nhiều dòng trong `steps_*` / `expected_*` dùng `\n` trong cùng một chuỗi, đánh
số `1. 2. 3.`. Nhiều giá trị trong `data_*` phân tách bằng ` · `.

## Ràng buộc validate (nguyên nhân exit code 1)

`build.py` chặn trước khi sinh file khi:

- thiếu field bắt buộc trong `cover`;
- `id` trùng nhau (lỗi im lặng nguy hiểm nhất — `write_defects.py` dựng dict theo
  TC ID, bản sau nuốt bản trước);
- `id` sai pattern, hoặc chữ cái trong ID không khớp `divider`;
- `type` hoặc `priority` không thuộc danh sách dropdown;
- thiếu bản dịch VN của title/steps/expected;
- `acs` trỏ tới mã AC không có trong `acceptance_criteria`.

Exit code 2 (file **có** sinh ra nhưng phải xử lý): còn AC chưa được case nào phủ,
hoặc số section vượt số slot của bảng RESULT BY SECTION.

## Ví dụ tối thiểu chạy được

```json
{
  "cover": {
    "module": "Vehicle Detail Page",
    "version": "1.0",
    "source": "ClickUp TLM-2899",
    "create_date": "2026-08-30"
  },
  "acceptance_criteria": [
    { "id": "AC-01", "text": "Mở trang chi tiết từ danh sách Devices" }
  ],
  "sections": [
    {
      "divider": "A. Page & Entry",
      "cases": [
        {
          "id": "TC-A-001",
          "section": "Page & Entry",
          "type": "Functional",
          "priority": "High",
          "acs": ["AC-01"],
          "title_en": "Open vehicle detail from Devices list",
          "title_vn": "Mở trang chi tiết xe từ danh sách Devices",
          "precond_en": "Logged in, at least one device exists",
          "precond_vn": "Đã đăng nhập, có ít nhất một thiết bị",
          "steps_en": "1. Open Devices list\n2. Click the first device row",
          "steps_vn": "1. Mở danh sách Devices\n2. Bấm dòng thiết bị đầu tiên",
          "data_en": "Device: DEV-001",
          "data_vn": "Thiết bị: DEV-001",
          "expected_en": "1. Detail page opens\n2. Heading shows the vehicle name",
          "expected_vn": "1. Trang chi tiết mở ra\n2. Tiêu đề hiển thị tên xe",
          "note_en": "",
          "note_vn": ""
        }
      ]
    }
  ]
}
```
