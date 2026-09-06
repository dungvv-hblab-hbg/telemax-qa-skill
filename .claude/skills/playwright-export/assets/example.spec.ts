import { test, expect } from '@playwright/test';

/**
 * TLM-2899 — Vehicle Detail
 * Test case: .qa/TLM-2899/TCs_Vehicle_Detail_v1.0.xlsx
 * Màn hình: Vehicle Detail
 *
 * MỘT FILE CHO MỘT TICKET: tên file là mã ticket (tests/TLM-2899.spec.ts), chứa toàn
 * bộ case UI của ticket kể cả khi đụng nhiều màn hình (thêm describe, không thêm file).
 * Chạy từ trong thư mục telemax-e2e:
 *   npx playwright test tests/TLM-2899.spec.ts                 # cả ticket
 *   npx playwright test tests/TLM-2899.spec.ts -g "TC-A-001"   # một case
 *
 * Tên describe đặt theo màn hình và giữ nhất quán giữa các ticket, để chạy regression
 * theo màn hình xuyên ticket: npx playwright test -g "Vehicle Detail"
 * Session login được tái dùng qua storageState (cấu hình ở playwright.config.ts,
 * project 'chromium' -> dependencies ['setup']). KHÔNG login trong file này.
 */

/**
 * Test data gom một chỗ, không rải giá trị hardcode trong thân test.
 * Khi có fixture thật thì thay khối này bằng import từ fixture; mọi test bên
 * dưới không phải sửa.
 */
const VEHICLE = {
  rego: '51A-12345',
  name: 'Truck 07 — North Depot',
};

test.describe('Vehicle Detail', () => {
  // Điều hướng chung cho cả nhóm: mở trang chi tiết một xe mẫu.
  test.beforeEach(async ({ page }) => {
    await page.goto('/devices');
    await page.getByRole('row').filter({ hasText: VEHICLE.rego }).first().click();
  });

  test('TC-A-001 — mở trang chi tiết từ Devices list, title là tên xe', async ({ page }) => {
    // Expected Result (từ Excel):
    // 1. Mở đúng trang chi tiết của xe vừa chọn
    // 2. Tiêu đề là tên xe, không phải biển số
    await expect(page).toHaveURL(/\/vehicles\/\d+/);

    // Assert DƯƠNG: kiểm cái ĐÚNG phải hiện.
    // `not.toHaveText(rego)` sẽ pass cả khi heading rỗng hoặc trang lỗi 500 —
    // nó không chứng minh được tiêu đề đang hiển thị tên xe.
    await expect(page.getByRole('heading', { level: 1 })).toHaveText(VEHICLE.name);
  });

  test('TC-A-002 — trang cuộn đơn, không có tab bar', async ({ page }) => {
    // Expected: không có tab bar; các card xếp theo thứ tự thiết kế.
    // Expected nói về SỰ VẮNG MẶT -> phủ định ở đây là đúng.
    await expect(page.getByRole('tablist')).toHaveCount(0);

    // Nhưng vẫn kèm một assert dương để chắc trang đã render, không phải trang trắng.
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  });

  test('TC-B-001 — fault card hiện khi xe đang báo engine code', async ({ page }) => {
    // Expected: card đỏ hiện trên cùng; heading "This vehicle has {n} active engine faults"
    // Cần test data là xe ĐANG có fault. Không có fixture phù hợp thì:
    //   test.skip(true, 'cần xe đang có active engine fault');
    // và báo test-runner ghi [MANUAL] vào cột Note của Excel.
    const faultCard = page.getByText(/active engine faults/i);
    await expect(faultCard).toBeVisible();
  });

  test('TC-C-004 — bỏ trống tên xe thì hiện message lỗi nguyên văn', async ({ page }) => {
    // Ví dụ case Type = Validation: vẫn thao tác được trên UI nên VẪN export,
    // không đẩy sang Manual.
    // Expected: 'Vehicle name is required.'  (trích nguyên văn từ D2 checklist)
    await page.getByRole('button', { name: 'Edit' }).click();
    await page.getByLabel('Vehicle name').fill('');
    await page.getByRole('button', { name: 'Save' }).click();

    await expect(page.getByText('Vehicle name is required.')).toBeVisible();
  });
});
