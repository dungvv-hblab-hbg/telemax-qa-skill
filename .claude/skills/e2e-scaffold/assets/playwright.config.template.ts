/**
 * KHUÔN playwright.config.ts cho repo mới cài harness QA.
 *
 * Thay mọi <PLACEHOLDER> rồi xoá dòng này. Bốn thứ bên dưới là HÀNG RÀO của harness,
 * không phải tuỳ chọn phong cách — đọc comment trước khi sửa:
 *
 *   1. project `prod` có `grep: /@prod-safe/`
 *   2. storageState staging và production là hai file khác nhau
 *   3. project staging tên `chromium` để mọi lệnh truyền --project được
 *   4. trace/screenshot/video bật, vì bug cần Actual Result thật
 */
import { defineConfig, devices } from '@playwright/test';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config();

// Hai file TÁCH BIỆT. Dùng chung một file cho hai môi trường là đường ngắn nhất tới
// chuyện chạy test staging bằng session production — hoặc tệ hơn, ngược lại.
export const STORAGE_STATE = path.join(__dirname, 'playwright/.auth/user.json');
export const PROD_STORAGE_STATE = path.join(__dirname, 'playwright/.auth/prod.json');

export default defineConfig({
  // Spec của ticket: tests/<TICKET-ID>.spec.ts — MỘT FILE CHO MỘT TICKET.
  testDir: './tests',

  // Tắt nếu test đụng cùng bản ghi trên staging (case Create/Delete chạy song song
  // sẽ giẫm lên nhau, và triệu chứng trông y hệt một bug sản phẩm).
  fullyParallel: true,

  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,

  // 30s mặc định hay đứt oan trên SPA có bản đồ/biểu đồ. Nới ở đây, đừng rải sleep.
  timeout: 60_000,
  expect: { timeout: 10_000 },

  reporter: [['list'], ['html', { open: 'never' }]],

  use: {
    baseURL: process.env.BASE_URL || '<STAGING_URL>',

    // Bật nếu môi trường staging dùng chứng chỉ tự ký.
    // ignoreHTTPSErrors: true,

    // HÀNG RÀO 4 — bug cần bằng chứng. `clickup-bug-format` yêu cầu Actual Result
    // cụ thể (message thật, status thật); harness lấy chúng từ test-results/.
    // Đừng tắt ba dòng này.
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    // 1. Đăng nhập một lần, lưu session ra file.
    {
      name: 'setup',
      // auth.setup.ts nằm ở GỐC project, không trong testDir './tests'.
      // Thiếu dòng testDir này thì `npm run auth` báo "No tests found".
      testDir: '.',
      testMatch: /auth\.setup\.ts/,
    },

    // 2. HÀNG RÀO 3 — project staging có tên, để mọi lệnh truyền --project=chromium.
    //    Chạy `playwright test` KHÔNG có --project sẽ chạy MỌI project khớp, gồm cả
    //    `prod` bên dưới: đăng nhập production giữa một chặng test staging, và mỗi
    //    TC ID ra hai dòng kết quả.
    {
      name: 'chromium',
      testDir: './tests',
      dependencies: ['setup'],
      use: {
        ...devices['Desktop Chrome'],
        storageState: STORAGE_STATE,
        launchOptions: {
          // Cần khi chạy headless trong container/CI.
          args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
        },
      },
    },

    // 3. HÀNG RÀO 1 — verify sau khi deploy. CHỈ case gắn @prod-safe (case chỉ xem,
    //    không tạo/sửa/xoá dữ liệu). `grep` là hàng rào CỨNG: quên gắn tag thì case
    //    KHÔNG chạy trên prod. Nghiêng về bỏ sót có chủ đích — bỏ sót một case còn
    //    sửa được, sửa nhầm dữ liệu khách hàng thật thì không.
    //    ĐỪNG gỡ dòng grep, đừng thêm --grep-invert, đừng chạy --project=chromium
    //    với PROD_BASE_URL.
    {
      name: 'prod',
      testDir: './tests',
      grep: /@prod-safe/,
      dependencies: ['setup-prod'],
      retries: 1,                     // prod có thể chậm/nghẽn nhất thời
      use: {
        ...devices['Desktop Chrome'],
        baseURL: process.env.PROD_BASE_URL,
        storageState: PROD_STORAGE_STATE,   // HÀNG RÀO 2 — không dùng chung với staging
        launchOptions: {
          args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
        },
      },
    },

    {
      name: 'setup-prod',
      testDir: '.',
      testMatch: /auth\.prod\.setup\.ts/,
      use: { baseURL: process.env.PROD_BASE_URL },
    },

    // 4. Kiểm hạ tầng — KHÔNG cần đăng nhập, không phụ thuộc setup.
    //    Chạy đầu tiên khi mới cài: npm run check
    {
      name: 'check',
      testDir: './checks',
      use: {
        ...devices['Desktop Chrome'],
        launchOptions: {
          args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
        },
      },
    },
  ],
});
