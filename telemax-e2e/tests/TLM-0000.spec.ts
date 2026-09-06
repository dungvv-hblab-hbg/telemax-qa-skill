import { test, expect } from '@playwright/test';
import { VEHICLE } from '../fixtures/test-data';

/**
 * TLM-0000 — FILE MẪU, xoá khi có ticket thật.
 * Test case: .qa/TLM-0000/TCs_Example_v1.0.xlsx
 * Màn hình: Vehicle Detail, Devices List
 *
 * MỘT FILE CHO MỘT TICKET. Tên file là mã ticket; toàn bộ case UI của ticket nằm
 * trong đây, kể cả khi ticket đụng nhiều màn hình (thêm describe, không thêm file).
 *
 *   npx playwright test tests/TLM-0000.spec.ts                 # cả ticket
 *   npx playwright test tests/TLM-0000.spec.ts -g "TC-A-001"   # một case
 *
 * Chạy theo TC ID thì LUÔN kèm đường dẫn file: TC ID chỉ duy nhất trong một ticket,
 * `-g "TC-A-001"` trần sẽ vớ phải case của ticket khác.
 *
 * Tên describe đặt theo màn hình và giữ nhất quán giữa các ticket, để chạy regression
 * theo màn hình xuyên ticket:  npx playwright test -g "Vehicle Detail"
 *
 * KHÔNG login ở đây — session đã có sẵn qua storageState.
 *
 * TAG @prod-safe: gắn cho case CHỈ XEM, không tạo/sửa/xoá dữ liệu. Chỉ những case
 * gắn tag này mới chạy khi verify sau deploy (`npm run test:prod`) — vì trên
 * production là dữ liệu khách hàng thật. Quên gắn thì case không chạy trên prod;
 * thà bỏ sót còn hơn sửa nhầm dữ liệu thật.
 */

test.describe('Devices List', () => {
  // Chỉ mở trang và đọc -> an toàn trên production.
  test('TC-A-001 — mở trang chi tiết từ danh sách Devices', { tag: '@prod-safe' }, async ({ page }) => {
    // Expected Result (từ cột I của Excel):
    // 1. Mở đúng trang chi tiết của xe vừa chọn
    // 2. Tiêu đề là tên xe, không phải biển số
    await page.goto('/devices');

    await page
      .getByRole('row')
      .filter({ hasText: VEHICLE.rego })
      .first()
      .click();

    // Assertion DƯƠNG: assert cái ĐÚNG phải hiện, đừng chỉ assert cái sai không hiện.
    await expect(page.getByRole('heading', { name: VEHICLE.name })).toBeVisible();
  });
});

test.describe('Vehicle Detail', () => {
  test.beforeEach(async ({ page }) => {
    // Điều hướng chung cho cả nhóm.
    await page.goto('/devices');
    await page.getByRole('row').filter({ hasText: VEHICLE.rego }).first().click();
  });

  // KHÔNG gắn @prod-safe: case này bấm Save, tức là ghi vào dữ liệu thật.
  test('TC-B-001 — bỏ trống tên xe thì hiện message lỗi nguyên văn', async ({ page }) => {
    // Expected Result: hiện message "Vehicle name is required."
    // Message trích nguyên văn từ mục D2 của checklist — đừng viết lại cho gọn.
    await page.getByLabel('Vehicle Name').fill('');
    await page.getByRole('button', { name: 'Save' }).click();

    await expect(page.getByText('Vehicle name is required.')).toBeVisible();
  });

  // Chỉ nhìn -> an toàn trên production.
  test('TC-B-002 — trang chi tiết không có tab bar', { tag: '@prod-safe' }, async ({ page }) => {
    // Expected Result nói về sự VẮNG MẶT -> đây là chỗ hợp lệ để dùng phủ định.
    await expect(page.getByRole('tablist')).toHaveCount(0);
  });

  // Case cần dữ liệu đặc thù chưa seed được: skip có lý do, đừng để lửng.
  // test-runner sẽ ghi Blocked + Note "[MANUAL] cần xe đang báo engine fault".
  test.skip('TC-C-001 — fault card hiện khi xe đang báo engine code', async () => {
    // TODO: cần seed một xe có engine fault trên staging (VEHICLE_WITH_FAULT).
  });
});
