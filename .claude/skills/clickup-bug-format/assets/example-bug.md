# Ví dụ một bug hoàn chỉnh

Dựng từ một dòng Defects đã review. Dùng làm mẫu về mức độ cụ thể cần đạt, không
phải để chép nguyên văn.

---

## Ví dụ 1 — bug UI

**Title**
`[Vehicle Detail] Missing error message when vehicle name is left empty`

**Description**
Saving the vehicle detail form with an empty Vehicle Name silently closes the
dialog instead of blocking the save. The record is stored with an empty name, which
then renders as a blank row in the Devices list.

**Steps to reproduce**
1. Log in to dashboard-stage as a Fleet Manager
2. Open Devices → click device `DEV-001`
3. Clear the Vehicle Name field
4. Click Save

**Actual Result**
Dialog closes, no validation message shown. The list row for `DEV-001` renders with
an empty title. `PUT /vehicles/DEV-001` returns 200.

**Expected Result**
Save is blocked and the message "Vehicle name is required." is displayed under the
field. No request is sent.

**Field ClickUp**
- TC ID: `TC-B-004` · Environment: dashboard-stage
- Priority: High (mapped from test case Priority = High)
- Status: Open
- Assignee: đề xuất từ commit đụng `VehicleFormValidator.cs` — **chờ duyệt**

---

## Ví dụ 2 — bug API

**Title**
`[PUT /vehicles/{id}] Returns 500 with stack trace on malformed JSON body`

**Description**
A malformed JSON payload causes an unhandled exception instead of a 400 response.
The error body leaks the internal exception type and file path.

**Steps to reproduce**
1. Authenticate against staging and obtain a valid token
2. Send `PUT /vehicles/DEV-001` with body `{"name": ` (truncated JSON)

**Actual Result**
`500 Internal Server Error`. Body contains `Newtonsoft.Json.JsonReaderException` and
the server path `/app/src/Telemax.Api/Controllers/VehiclesController.cs`.

**Expected Result**
`400 Bad Request` with the standard error envelope. No internal type name or file
path in the response body.

**Field ClickUp**
- TC ID: `TC-API-007` · Environment: staging API
- Priority: High · Status: Open
