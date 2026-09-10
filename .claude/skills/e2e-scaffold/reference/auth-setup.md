# Viết `auth.setup.ts` cho một app mới

Đây là file **app-specific nhất** của cả project e2e, và là chỗ dễ mất buổi nhất khi
dựng cho app lạ. Đọc hết trước khi viết.

Nguyên tắc chi phối: **spec của ticket không bao giờ chứa bước đăng nhập và không bao
giờ chứa credential.** Đăng nhập một lần ở đây, lưu `storageState`, mọi spec dùng lại.

## Khung bắt buộc

```ts
import { test as setup, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import { STORAGE_STATE } from './playwright.config';

setup('đăng nhập và lưu session', async ({ page }) => {
  const user = process.env.<PREFIX>_USER;
  const pass = process.env.<PREFIX>_PASS;

  // 1. Fail SỚM với thông báo rõ, thay vì đứt giữa chừng bằng "element not found".
  if (!user || !pass) {
    throw new Error(
      'Thiếu <PREFIX>_USER / <PREFIX>_PASS. Copy .env.example sang .env rồi điền. ' +
      'KHÔNG hardcode credential vào file test.'
    );
  }

  await page.goto('<ĐƯỜNG_DẪN_LOGIN>');

  // 2. Chờ TƯỜNG MINH trước khi điền — SPA tải nguội có thể mất hơn 30s.
  const email = page.<LOCATOR_EMAIL>;
  await email.waitFor({ state: 'visible', timeout: 45_000 });

  // 3. Điền — xem "Bẫy điền form" bên dưới trước khi chọn fill() hay pressSequentially()
  // 4. Bấm nút, chờ rời trang login
  // 5. Kiểm THẬT rồi mới lưu
  await expect(page.<LOCATOR_PASSWORD>).toHaveCount(0);

  fs.mkdirSync(path.dirname(STORAGE_STATE), { recursive: true });
  await page.context().storageState({ path: STORAGE_STATE });
});
```

## Bẫy 1 — `fill()` không phải lúc nào cũng chạy

`fill()` đặt `value` một nhát rồi bắn một event `input`. Framework nào bind theo
**chuỗi event thật của trình duyệt** sẽ không nhận, nút submit giữ nguyên `disabled`,
và test treo tới hết timeout mà không có lỗi nào nói vì sao.

Đã gặp thật với **Blazor** (`EditContext`). Angular với `updateOn: 'blur'` và một số
form React có validate tuỳ biến cũng cho triệu chứng y hệt.

**Triệu chứng nhận biết:** ô nhập nhìn thấy có chữ, nhưng nút submit vẫn xám.

**Cách xử:**

```ts
await email.click();
await email.pressSequentially(user, { delay: 30 });   // gõ từng ký tự
await password.click();
await password.pressSequentially(pass, { delay: 30 });
await password.blur();                                 // một số form chỉ validate khi blur

const loginButton = page.getByRole('button', { name: '<TÊN_NÚT>' });
await expect(loginButton).toBeEnabled({ timeout: 15_000 });   // chờ enable, đừng click mù
await loginButton.click();
```

Thử `fill()` trước; chỉ đổi sang `pressSequentially` khi thấy nút không enable.
`pressSequentially` chậm hơn, nhưng đây chạy đúng một lần mỗi session nên không đáng kể.

## Bẫy 2 — Chọn selector khi app chưa có `data-testid`

Thứ tự ưu tiên (giống `playwright-export`):

1. `getByRole('button', { name: '...' })` — ổn định nhất
2. `getByLabel(...)` / `getByPlaceholder(...)` — cho ô nhập
3. `getByTestId(...)` — nếu app có
4. CSS/XPath — chỉ khi hết cách, kèm `// TODO: cần data-testid`

Dò selector thật bằng MCP Playwright (`browser_snapshot` trên trang login) rồi mới
viết — **đừng đoán**. Chưa dò được thì để `TODO` và **để `npm run check` đỏ có chủ
đích**: đỏ ngay từ đầu tốt hơn là mọi spec đỏ về sau với lý do khó hiểu.

## Bẫy 3 — 2FA

Không tự động hoá được, và cũng không nên — mã chỉ người dùng mới có.

Cho timeout rộng (3 phút) để họ tự nhập trong cửa sổ, kèm `console.log` nói rõ đang
chờ gì. Chạy headless mà gặp 2FA thì phải **hết giờ rồi báo lỗi kèm hướng dẫn**, đừng
treo im lặng:

```ts
const LOGIN_WAIT = 180_000;
console.log(`Nếu tài khoản bật 2FA: nhập mã trong cửa sổ. Đang chờ tối đa ${LOGIN_WAIT / 1000}s...`);
try {
  await page.waitForURL((url) => !/login|signin|mfa|2fa|verify/i.test(url.pathname), { timeout: LOGIN_WAIT });
} catch {
  throw new Error(
    `Không rời được trang đăng nhập trong ${LOGIN_WAIT / 1000}s. Tài khoản bật 2FA thì chạy ` +
    '`npm run auth:headed` và tự nhập mã. Sai mật khẩu hoặc tài khoản bị khoá cũng ra lỗi này.'
  );
}
```

## Bẫy 4 — Kiểm THẬT trước khi lưu session

Rời khỏi `/login` **chưa chứng minh** đã đăng nhập: app có thể redirect sang trang
lỗi, hoặc sang chính `/login` với query khác. Assert một dấu hiệu dương:

```ts
await expect(page.<LOCATOR_PASSWORD>).toHaveCount(0);   // không còn ô mật khẩu
```

Lưu một session hỏng còn tệ hơn không lưu: mọi spec sau đó đỏ, và triệu chứng trông
như bug sản phẩm.

## `auth.prod.setup.ts` — bản production, TÁCH HẲN

Chép khung trên, đổi ba thứ:

1. Đọc `<PREFIX>_PROD_USER` / `<PREFIX>_PROD_PASS`, ghi ra `PROD_STORAGE_STATE`.
2. **Bắt buộc có `PROD_BASE_URL`** — không đoán URL production:
   ```ts
   if (!base) throw new Error('Thiếu PROD_BASE_URL trong .env — không đoán URL production.');
   ```
3. **Hàng rào chống chạy nhầm môi trường:**
   ```ts
   if (/stage|staging|localhost/i.test(base)) {
     throw new Error(`PROD_BASE_URL trông không giống production: ${base}`);
   }
   ```
   Không có dòng này thì một lần `.env` sai là ghi đè session prod bằng session
   staging, và lần verify sau báo xanh trên môi trường sai.

Tách hai file là **có chủ đích**, đừng gộp lại cho gọn. Dùng account QA riêng trên
prod, quyền thấp nhất đủ để xem — không dùng account admin, không dùng chung với
staging.

## `checks/setup-check.spec.ts` — bắt lỗi selector TRƯỚC khi nó lan

Một file nhỏ, không cần đăng nhập, assert đúng những selector mà `auth.setup.ts` dựa
vào. Đổi UI mà quên sửa `auth.setup` thì **file này đỏ trước**, thay vì mọi spec cùng
đỏ với lý do khó hiểu.

Cho timeout 45s (không phải 10s mặc định): SPA tải nguội đầu ngày mất hơn 30s, và đứt
vì app chậm sẽ bị hiểu nhầm thành "selector sai" — đúng cái nhầm file này sinh ra để
tránh.

File trong `checks/` **không phải test case của ticket**: không có TC ID, không bao
giờ ghi kết quả vào Excel.
