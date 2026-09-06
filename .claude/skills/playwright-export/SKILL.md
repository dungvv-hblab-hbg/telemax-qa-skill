---
name: playwright-export
description: >-
  Viết thao tác test UI **đã dò được qua MCP Playwright ở Phase 1** thành file .ts
  tái dùng, đúng convention project telemax-e2e: cấu trúc file, thứ tự ưu tiên locator, gắn TC ID,
  tái dùng session đăng nhập, assertion ánh xạ từ Expected Result. Dùng khi cần xuất
  một luồng test UI thành code để chạy lại lần sau — kể cả khi người dùng nói "gen
  file .ts", "export test này ra Playwright", "viết lại thành spec để tái dùng".
---

# Playwright-export

## Yêu cầu môi trường

**MCP Playwright phải sẵn sàng trước.** Skill này chỉ viết lại thao tác ĐÃ dò được ở
Phase 1; không có MCP thì không có gì để viết, và skill KHÔNG được bịa selector. Agent
là bên kiểm và dừng — xem `test-runner`.

Node + `@playwright/test`, và project `telemax-e2e` đã tồn tại với
`playwright.config.ts` + `auth.setup.ts`. Đường dẫn khai báo ở
[../../qa-config.md](../../qa-config.md).

Project chưa tồn tại là điều kiện chưa thoả: DỪNG và báo người dùng init trước.
KHÔNG tự tạo project, KHÔNG ghi file .ts vào hư không. Việc kiểm tra và dừng/báo là
hành vi luồng do agent thực thi trước khi gọi skill.

## Đầu vào skill cần

| Cần | Nguồn | Thiếu thì |
|---|---|---|
| Thao tác đã dò được ở Phase 1 | agent chạy MCP Playwright | Hỏi. Skill không tự dò element, không tự bịa selector |
| TC ID + Expected Result | file test case Excel | Hỏi. Không viết test không gắn TC ID |
| Test data cho case cần dữ liệu đặc thù | người dùng cung cấp | Ghi `test.skip` kèm lý do, hoặc báo để đánh `[MANUAL]`. **Không bịa data** |
| Đường dẫn project | `qa-config.md` | Dừng, báo người dùng init trước |
| Ticket ID (để đặt tên file spec) | khối đầu vào của command | Hỏi. Tên file spec chính là mã ticket; thiếu nó thì lần sau không tra lại được |

## Vị trí trong quy trình 2 phase

- **Phase 1 (KHÔNG thuộc skill này):** agent dùng MCP Playwright mở
  dashboard-stage (cửa sổ hiện lên, session giữ ở profile riêng), dò element, chạy thao tác theo test
  case. Đây là HÀNH ĐỘNG có phán đoán → thuộc agent.
- **Phase 2 (skill này):** lấy thao tác đã biết từ Phase 1, viết thành file `.ts`
  đúng khuôn để tái dùng. Đây là KIẾN THỨC về convention code → skill.

Skill này chỉ lo Phase 2. Nó nhận mô tả thao tác (mở trang nào, click gì, kiểm
gì) và xuất code; nó không tự mở trình duyệt hay dò selector.

## Convention bắt buộc (bám project telemax-e2e)

### Định danh — convention BẮT BUỘC, không phải trang trí

Convention này là cách `test-runner` **tìm lại spec đã có** ở lần chạy sau. Sai một
ký tự là không tìm thấy, và nó sẽ dò lại toàn bộ bằng MCP như chưa từng export.

**MỘT FILE CHO MỘT TICKET.** Tên file là mã ticket:

```
tests/TLM-2899.spec.ts
```

Toàn bộ test case UI của ticket nằm trong file này, kể cả khi ticket đụng nhiều màn
hình. Không tách thành `vehicle-detail.spec.ts`, `vehicle-list.spec.ts`... — tách nhỏ
thì chạy lại cả bộ của một ticket phải nhớ mấy file, còn gom một file thì:

```bash
cd telemax-e2e && npx playwright test tests/TLM-2899.spec.ts     # chạy lại toàn bộ ticket, một lệnh
```

File spec ánh xạ 1:1 với file test case Excel `.qa/TLM-2899/TCs_*.xlsx`. Cùng phạm vi,
cùng bộ TC ID, cùng vòng đời.

**Describe block gom theo màn hình**, nhiều màn hình thì nhiều describe trong cùng file:

```ts
test.describe('Vehicle Detail', () => {
  test('TC-A-001 — mở trang chi tiết từ danh sách Devices', async ({ page }) => {
```

Tên describe đặt đúng tên màn hình và **giữ nhất quán giữa các ticket** — đây là cách
chạy regression theo màn hình xuyên nhiều ticket khi cần:

```bash
cd telemax-e2e && npx playwright test -g "Vehicle Detail"        # mọi ticket từng test màn hình này
```

**Tiêu đề test:** `TC-Y-NNN — <mô tả ngắn>`, đúng TC ID trong Excel. Dấu phân cách là
` — ` (space, gạch dài, space) — đừng đổi sang `-` hay `:`, chuỗi này là thứ được grep.

TC ID chỉ duy nhất **trong một ticket**, nên khi chạy theo TC ID **luôn phải kèm đường
dẫn file**, đừng bao giờ chạy `-g "TC-A-001"` trần:

```bash
cd telemax-e2e && npx playwright test tests/TLM-2899.spec.ts -g "TC-A-001"
```

**Header comment** ở đầu file:

```ts
// TLM-2899 — Vehicle Detail
// Test case: .qa/TLM-2899/TCs_Vehicle-Detail_v1.0.xlsx
// Màn hình: Vehicle Detail, Devices List
```

**Không duy trì file index** ánh xạ TC ID → spec. Tên file đã là mã ticket, tra bằng
đường dẫn là đủ; index thì sẽ lệch ngay lần đầu ai đó sửa tay.

### Tag `@prod-safe` — quyết định case nào chạy được sau khi deploy

Case **chỉ xem, không tạo/sửa/xoá dữ liệu** thì gắn tag:

```ts
test('TC-A-001 — mở trang chi tiết', { tag: '@prod-safe' }, async ({ page }) => {
```

Case có bấm Save, Delete, Create, upload, hay đổi setting thì **không gắn**.

Bước verify sau deploy (`/qa-verify-prod`) lọc bằng `grep: /@prod-safe/` và chỉ chạy
case có tag. Quên gắn thì case không chạy trên production — hàng rào cố ý nghiêng về
phía bỏ sót, vì trên prod là dữ liệu khách hàng thật.

Không chắc một case có ghi dữ liệu hay không → **đừng gắn**. Gắn thiếu thì bổ sung
sau; gắn thừa thì đã sửa dữ liệu thật rồi.

### Tái dùng session — KHÔNG login trong spec
- Login đã xử lý bởi `auth.setup.ts` + `storageState` trong config. File spec
  **tuyệt đối không** chứa bước đăng nhập, không hardcode credential.
- Test chỉ `goto` thẳng vào trang cần test; session tự có sẵn.

### Locator — thứ tự ưu tiên
1. `getByRole` (button, heading, row, link...) — ổn định nhất, gần cách người
   dùng nhìn.
2. `getByLabel` / `getByPlaceholder` — cho field form.
3. `getByTestId` — nếu Telemax dashboard có `data-testid`.
4. `getByText` — khi nội dung là dấu hiệu chính (VD text của fault card).
5. CSS/XPath — chỉ khi hết cách; đánh dấu `// TODO: selector tạm, cần data-testid`.

Yêu cầu độ chính xác: **đúng vị trí/đúng phần tử là đủ**, không cần selector hoàn
hảo tuyệt đối (theo chủ trương của team). Selector tạm chấp nhận được, miễn có
đánh dấu để sau thay bằng thứ ổn định.

### Truy vết ngược về test case Excel
- File đặt tên đúng mã ticket; mỗi `test()` mở đầu bằng `TC-Y-NNN — ` đúng TC ID trong
  Excel. Ticket + TC ID cùng nhau là khoá truy vết.
- Trong thân test, ghi comment trích **Expected Result** từ Excel, rồi viết
  assertion phản ánh đúng expected đó. Assertion phải kiểm được điều Expected nói,
  không chỉ "trang mở ra".

### Phạm vi export
Tiêu chí là **quan sát được trên UI hay không**, KHÔNG phải tên Type.

Export: Type = **UI · Functional · Validation**, và **Boundary · Negative ·
Business rule khi chúng kiểm được qua UI**. Nhập quá maxlength, bỏ trống field bắt
buộc, ký tự đặc biệt, ranh giới số — đều là thao tác UI bình thường; đừng loại
chúng chỉ vì Type không nằm trong ba cái đầu.

Bỏ qua:
- API (thuộc skill `postman-api-test`, không phải Playwright).
- Business rule thuần server-side không quan sát được qua UI.

Case cần điều kiện dữ liệu đặc biệt (VD "xe đang có fault") → vẫn export được
nhưng ghi rõ cần test data phù hợp, hoặc `test.skip` kèm lý do.

Case thật sự không tự động hoá được thì **không export**, và báo lại cho
`test-runner` để nó ghi `Blocked` + Note `[MANUAL] <lý do>` vào Excel. Bỏ lửng
case đó là để nó nằm `Not Run` mãi và làm sai `% Executed` ở Summary.

## Cấu trúc một file spec (theo assets/example.spec.ts)

Đọc `assets/example.spec.ts` làm mẫu tham chiếu. Khung chuẩn:

1. Header comment: tên màn hình, nguồn ticket, tên file Excel.
2. `test.describe('<Màn hình>', ...)` gom nhóm.
3. `test.beforeEach` cho điều hướng chung (mở đúng trang) nếu các test dùng chung
   điểm vào.
4. Mỗi `test('TC-xxx — ...', ...)`: comment Expected + assertion tương ứng.

## Assertion ánh xạ từ Expected Result

Mỗi dòng Expected trong Excel nên thành một assertion.

**Ưu tiên assertion DƯƠNG.** Assertion phủ định (`not.toHaveText`, `not.toBeVisible`)
pass cả khi phần tử rỗng, không tồn tại, hoặc trang lỗi 500 — nó không chứng minh
được gì. Chỉ dùng phủ định khi Expected thật sự nói về sự vắng mặt.

- "Tiêu đề là tên xe, không phải biển số"
  → `await expect(heading).toHaveText(vehicle.name)` — assert cái ĐÚNG phải hiện,
    đừng chỉ assert cái sai không hiện.
- "Không có tab bar" (Expected nói về sự vắng mặt → phủ định là đúng)
  → `await expect(page.getByRole('tablist')).toHaveCount(0)`.
- "Hiển thị message X" → `await expect(page.getByText('X')).toBeVisible()`
  (X trích nguyên văn từ D2 checklist / cột Expected).

Mỗi assertion phải kiểm được điều Expected nói. `await expect(page).toHaveURL(...)`
một mình không đủ để chứng minh "trang hiển thị đúng".

### Chờ dữ liệu về — dùng auto-retry, không dùng chờ cứng

Dữ liệu đến từ API sau khi khung trang đã render, nên sau `goto` không được thao tác
ngay. Cách chờ đúng là để `expect()` tự retry vào phần tử chứa **dữ liệu thật**:

```ts
await page.goto('/devices');
// expect() tự chờ tới khi dòng dữ liệu xuất hiện — không cần chờ thủ công
await expect(page.getByRole('row').filter({ hasText: VEHICLE.rego })).toBeVisible();
```

- **KHÔNG `page.waitForTimeout(...)`.** Chờ cứng vừa chậm khi mạng nhanh vừa thiếu khi
  mạng chậm — nguồn flaky số một.
- **KHÔNG `waitUntil: 'networkidle'`** trên màn hình realtime: dashboard giữ kết nối
  stream nên network không bao giờ idle, chờ kiểu đó là chờ tới hết timeout.
- Màn hình tải chậm thật thì nới timeout của chính assertion đó
  (`{ timeout: 30_000 }`), đừng thêm sleep phía trước.

## Bằng chứng khi fail (cần cho bug)

`clickup-bug-format` yêu cầu Actual Result cụ thể — message thật, status thật.
Muốn có thì `playwright.config.ts` phải bật artifact:

```ts
use: {
  trace: 'on-first-retry',
  screenshot: 'only-on-failure',
  video: 'retain-on-failure',
},
```

Artifact rơi vào `test-results/`. Khi một case fail, lấy message/screenshot từ đó
làm Actual thay vì mô tả chung chung "nó lỗi". Nhớ gitignore `test-results/` và
`playwright-report/`.

## Sau khi export — CHẠY THỬ NGAY, đừng giao spec chưa từng chạy

Spec được viết từ thao tác MCP đã thành công nên nó *có vẻ* đúng. "Có vẻ đúng" không
đủ: có thể không compile, có thể selector tạm sai, và không ai biết cho tới lần chạy
sau. Chạy verify ngay, đây là feedback loop bắt buộc:

```bash
cd telemax-e2e && npx playwright test tests/TLM-XXXX.spec.ts -g "TC-Y-NNN"
```

Đối chiếu với kết quả Phase 1:

- **Khớp** (cùng Pass, hoặc cùng Fail vì cùng lý do) → spec dùng được, giao.
- **Phase 1 Pass mà spec Fail** → spec sai, KHÔNG phải sản phẩm sai. Sửa selector
  (đây là lúc thay selector tạm bằng `data-testid` thật) rồi chạy lại. **Tuyệt đối
  không ghi `Fail` vào Excel dựa trên lần chạy này** — sẽ tạo bug cho lỗi không có thật.
- **Không compile / không chạy được** → sửa cho chạy được rồi mới giao. Spec không
  chạy được thì lần sau `test-runner` cũng không dùng lại được.

Sửa 2 lần vẫn không khớp thì dừng, giữ kết quả Phase 1, và ghi comment
`// TODO: spec chưa khớp Phase 1, cần xem lại selector` ngay trên `test()` đó.

## Tự kiểm trước khi giao file .ts

- [ ] File tên đúng mã ticket: `tests/TLM-XXXX.spec.ts`, một file cho cả ticket
- [ ] Ticket đụng nhiều màn hình → nhiều `describe` trong cùng file, KHÔNG tách file
- [ ] Tên describe đúng tên màn hình và nhất quán với ticket trước (để chạy regression theo màn hình)
- [ ] KHÔNG có bước login / credential trong spec
- [ ] Mỗi test() có tiêu đề đúng dạng `TC-Y-NNN — <mô tả>`, đúng dấu ` — `
- [ ] Case chỉ-xem đã gắn `{ tag: '@prod-safe' }`; case có ghi dữ liệu thì KHÔNG gắn
- [ ] Header comment có ticket, file Excel, danh sách màn hình
- [ ] **Đã chạy `cd telemax-e2e && npx playwright test tests/TLM-XXXX.spec.ts -g "..."` và kết quả khớp Phase 1**
- [ ] Có comment Expected + assertion phản ánh đúng Expected đó
- [ ] Locator theo thứ tự ưu tiên; selector tạm có đánh dấu TODO
- [ ] Assertion là DƯƠNG khi Expected nói về sự hiện diện; phủ định chỉ khi Expected nói về sự vắng mặt
- [ ] Không export case API / business rule thuần server-side
- [ ] Case không tự động hoá được đã báo lại cho test-runner để đánh `[MANUAL]`
- [ ] Không có giá trị test data hardcode rải rác trong body test (dùng fixture/const)
- [ ] Case cần data đặc biệt được ghi chú hoặc skip có lý do
