import { test as setup, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import { STORAGE_STATE } from './playwright.config';

/**
 * Đăng nhập MỘT LẦN rồi lưu session ra playwright/.auth/user.json.
 * Mọi spec trong tests/ dùng lại session này qua storageState — spec không bao giờ
 * chứa bước login và không bao giờ chứa credential.
 *
 * Chạy riêng: npm run auth
 *
 * Selector dựa trên form login thật của dashboard-stage: input dùng placeholder
 * "Enter your email" / "Enter your password", nút "Login". Trang không có
 * data-testid nào, nên đây là lựa chọn ổn định nhất hiện có. Khi FE thêm
 * data-testid thì đổi sang getByTestId.
 */
setup('đăng nhập và lưu session', async ({ page }) => {
  const user = process.env.TELEMAX_USER;
  const pass = process.env.TELEMAX_PASS;

  // Fail sớm với thông báo rõ, thay vì để test đứt ở giữa với lỗi khó hiểu.
  if (!user || !pass) {
    throw new Error(
      'Thiếu TELEMAX_USER / TELEMAX_PASS. Copy .env.example sang .env rồi điền. ' +
      'KHÔNG hardcode credential vào file test.'
    );
  }

  await page.goto('/login');

  // SPA tải nguội có thể mất hơn 30s mới render form -> chờ tường minh trước khi
  // điền, thay vì để fill() đứt với "element not found" khó hiểu.
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

  fs.mkdirSync(path.dirname(STORAGE_STATE), { recursive: true });
  await page.context().storageState({ path: STORAGE_STATE });

  console.log(`Session đã lưu: ${STORAGE_STATE}`);
});
