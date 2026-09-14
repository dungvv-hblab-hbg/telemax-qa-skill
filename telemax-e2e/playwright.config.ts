import { defineConfig, devices } from '@playwright/test';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config();

export const STORAGE_STATE = path.join(__dirname, 'playwright/.auth/user.json');
export const PROD_STORAGE_STATE = path.join(__dirname, 'playwright/.auth/prod.json');

export default defineConfig({
  // Spec của ticket nằm ở tests/TLM-XXXX.spec.ts (xem README).
  testDir: './tests',

  // TẮT CÓ CHỦ ĐÍCH. Dashboard là Blazor WASM: nhiều browser cùng boot nó sẽ khiến
  // một số tab đứng ở trang trắng, và mọi test trong worker đó fail ở beforeEach với
  // "Report Type not found" — triệu chứng giống hệt selector hỏng, rất dễ sửa nhầm.
  // Đo trên TLM-3088: 24 fail khi song song, cùng bộ test pass với 1 worker.
  // Các FILE vẫn chạy song song; chỉ test trong cùng một file bị tuần tự hoá.
  fullyParallel: false,

  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,

  // undefined = số core / 2 (5 worker trên Mac 8 nhân) — quá nhiều cho SPA này.
  workers: process.env.CI ? 1 : 2,

  // Staging đôi khi chậm; 30s mặc định hay đứt oan ở màn hình có bản đồ.
  timeout: 60_000,
  expect: { timeout: 10_000 },

  reporter: [
    ['list'],
    ['html', { open: 'never' }],
  ],

  use: {
    baseURL: process.env.BASE_URL || 'https://dashboard-stage.telemax.com.au',

    // Staging dùng chứng chỉ không hợp lệ với một số máy.
    ignoreHTTPSErrors: true,

    // Bug cần bằng chứng: harness lấy message/screenshot từ test-results/ làm
    // Actual Result. Đừng tắt ba dòng này.
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    // 1. Đăng nhập một lần, lưu session ra file.
    {
      name: 'setup',
      // auth.setup.ts nằm ở GỐC project, không trong testDir mặc định './tests'.
      // Thiếu dòng testDir này thì `npm run auth` báo "No tests found".
      testDir: '.',
      testMatch: /auth\.setup\.ts/,
    },

    // 2. Spec của ticket — session có sẵn, KHÔNG login trong spec.
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

    // 3. Verify sau khi deploy lên production.
    //    CHỈ chạy case gắn tag @prod-safe — case chỉ xem, không sửa dữ liệu.
    //    grep là hàng rào cứng: quên gắn tag thì case KHÔNG chạy trên prod, thà bỏ
    //    sót còn hơn sửa nhầm dữ liệu khách hàng thật.
    {
      name: 'prod',
      testDir: './tests',
      grep: /@prod-safe/,
      dependencies: ['setup-prod'],
      retries: 1,                     // prod có thể chậm/nghẽn nhất thời
      use: {
        ...devices['Desktop Chrome'],
        baseURL: process.env.PROD_BASE_URL,
        storageState: PROD_STORAGE_STATE,
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

    // 4. Kiểm tra hạ tầng — KHÔNG cần đăng nhập, không phụ thuộc setup.
    //    Chạy trước tiên khi mới cài: npm run check
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
