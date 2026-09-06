import { test as setup, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import { PROD_STORAGE_STATE } from './playwright.config';

/**
 * Đăng nhập PRODUCTION, lưu session riêng ở playwright/.auth/prod.json.
 *
 * Tách hẳn khỏi auth.setup.ts (staging) có chủ đích: dùng chung một file session cho
 * hai môi trường là đường ngắn nhất tới chuyện chạy nhầm test lên prod bằng session
 * staging — hoặc tệ hơn, ngược lại.
 *
 * Chỉ chạy như một phần của `npm run test:prod`.
 */
setup('đăng nhập production và lưu session', async ({ page }) => {
  const user = process.env.TELEMAX_PROD_USER;
  const pass = process.env.TELEMAX_PROD_PASS;
  const base = process.env.PROD_BASE_URL;

  if (!base) {
    throw new Error('Thiếu PROD_BASE_URL trong .env — không đoán URL production.');
  }
  if (!user || !pass) {
    throw new Error(
      'Thiếu TELEMAX_PROD_USER / TELEMAX_PROD_PASS. Dùng account QA riêng trên prod, ' +
      'quyền thấp nhất đủ để xem. KHÔNG dùng account admin, KHÔNG dùng chung với staging.'
    );
  }

  // Hàng rào: chạy nhầm URL staging ở project prod thì dừng ngay, đừng ghi đè
  // session prod bằng session staging.
  if (/stage|staging|localhost/i.test(base)) {
    throw new Error(`PROD_BASE_URL trông không giống production: ${base}`);
  }

  await page.goto('/login');

  const email = page.getByPlaceholder('Enter your email');
  await email.waitFor({ state: 'visible', timeout: 45_000 });

  // Blazor bind qua event của trình duyệt. `fill()` đặt value một nhát, KHÔNG sinh
  // chuỗi event mà EditContext cần, nên nút Login giữ nguyên `disabled` và test treo
  // tới hết timeout. Phải gõ từng ký tự rồi blur.
  await email.click();
  await email.pressSequentially(user, { delay: 30 });

  const password = page.getByPlaceholder('Enter your password');
  await password.click();
  await password.pressSequentially(pass, { delay: 30 });
  await password.blur();

  const loginButton = page.getByRole('button', { name: 'Login' });
  await expect(loginButton).toBeEnabled({ timeout: 15_000 });
  await loginButton.click();

  // 2FA: nếu tài khoản có bật, sau khi bấm Login sẽ hiện màn nhập mã. Không tự động
  // hoá được, và cũng không nên — mã chỉ người dùng mới có.
  //
  // Chạy `npm run auth:headed` (hoặc `auth:prod:headed`) để thấy cửa sổ, tự nhập mã
  // trong đó. Timeout dưới đây để rộng 3 phút cho thao tác tay; chạy headless mà gặp
  // 2FA thì sẽ hết giờ và báo lỗi kèm hướng dẫn, chứ không treo im lặng.
  const LOGIN_WAIT = 180_000;
  console.log(
    'Nếu tài khoản bật 2FA: nhập mã trong cửa sổ trình duyệt. ' +
    `Đang chờ tối đa ${LOGIN_WAIT / 1000}s...`
  );

  try {
    await page.waitForURL((url) => !/login|signin|mfa|2fa|verify/i.test(url.pathname), {
      timeout: LOGIN_WAIT,
    });
  } catch {
    throw new Error(
      'Không rời được trang đăng nhập trong ' + LOGIN_WAIT / 1000 + 's. ' +
      'Tài khoản có bật 2FA thì chạy lại bằng `npm run auth:headed` và tự nhập mã ' +
      'trong cửa sổ. Sai mật khẩu hoặc tài khoản bị khoá cũng ra lỗi này.'
    );
  }

  await expect(page.getByPlaceholder('Enter your password')).toHaveCount(0);

  fs.mkdirSync(path.dirname(PROD_STORAGE_STATE), { recursive: true });
  await page.context().storageState({ path: PROD_STORAGE_STATE });

  console.log(`Session production đã lưu: ${PROD_STORAGE_STATE}`);
});
