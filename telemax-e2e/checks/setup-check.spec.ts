import { test, expect } from '@playwright/test';

/**
 * Kiểm tra hạ tầng, KHÔNG cần đăng nhập. Chạy đầu tiên khi mới cài:
 *
 *   npm run check
 *
 * Xanh = tới được staging và form login đúng như convention giả định.
 * Đỏ = sửa ở đây trước, đừng đi tiếp; mọi spec khác đều dựa trên hai điều này.
 *
 * File trong checks/ KHÔNG phải test case của ticket — nó không có TC ID và không
 * bao giờ được ghi kết quả vào file Excel.
 */
test.describe('Setup check', () => {
  test('mở được dashboard staging', async ({ page }) => {
    const res = await page.goto('/login');
    expect(res?.status(), 'staging phải trả 2xx/3xx').toBeLessThan(400);
  });

  test('form login đúng selector mà auth.setup.ts giả định', async ({ page }) => {
    await page.goto('/login');

    // Ba selector này là thứ auth.setup.ts dựa vào. Đổi UI mà quên sửa auth.setup
    // thì test này đỏ trước, thay vì mọi spec cùng đỏ với lý do khó hiểu.
    //
    // Timeout 45s (không phải 10s mặc định): đây là SPA, lần tải nguội đầu ngày
    // mất hơn 30s để render xong form. Đứt ở đây vì app chậm sẽ bị hiểu nhầm
    // thành "selector sai" — đúng cái nhầm mà test này sinh ra để tránh.
    const SLOW = { timeout: 45_000 };
    await expect(page.getByPlaceholder('Enter your email')).toBeVisible(SLOW);
    await expect(page.getByPlaceholder('Enter your password')).toBeVisible(SLOW);
    await expect(page.getByRole('button', { name: 'Login' })).toBeVisible(SLOW);
  });
});
