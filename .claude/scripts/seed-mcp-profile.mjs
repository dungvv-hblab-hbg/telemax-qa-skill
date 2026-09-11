#!/usr/bin/env node
/**
 * seed-mcp-profile.mjs — Đăng nhập vào profile trình duyệt mà MCP dùng, KHÔNG để mật
 * khẩu lọt vào transcript.
 *
 *   node .claude/scripts/seed-mcp-profile.mjs
 *
 * Vì sao cần: điền form login bằng MCP nghĩa là gọi `browser_type({text: "<mật khẩu>"})`,
 * và tham số tool call hiện NGUYÊN VĂN trong lịch sử hội thoại. Script này chạy trong
 * tiến trình Node riêng, đọc thẳng `.env`, nên mật khẩu không bao giờ rời khỏi tiến trình.
 *
 * Vì sao không dùng `--isolated --storage-state`: session của Telemax nằm 100% trong
 * localStorage, 0 cookie — và MCP không nạp được storage state đó. Đã thử, không dùng
 * được. Xem `.claude/qa-config.md`.
 *
 * THỨ TỰ QUAN TRỌNG: chạy script này TRƯỚC khi gọi bất kỳ tool MCP nào trong session.
 * MCP khởi động browser lười, nhưng một khi đã khởi động thì nó giữ lock trên thư mục
 * profile và `launchPersistentContext` ở đây sẽ báo profile đang bị chiếm.
 *
 * Output:
 *   LOGGED_IN url=/ passwordFields=0
 *   PROFILE_SEEDED
 * Bật 2FA thì in `2FA_REQUIRED` rồi chờ tới 5 phút cho người dùng gõ mã trong cửa sổ.
 *
 * Exit code: 0 = xong · 1 = thiếu cấu hình hoặc không đăng nhập được.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '../..');          // .claude/scripts/ -> gốc repo

// Thư mục project e2e KHÔNG cố định: `/qa-setup` (skill e2e-scaffold) để người dùng
// chọn, và mặc định đề xuất là `e2e/`. Hardcode 'telemax-e2e' ở đây thì script chết
// ngay ở repo đầu tiên chọn tên khác. Thứ tự: env -> dò playwright.config -> mặc định.
function findE2E() {
  if (process.env.QA_E2E_DIR) return path.resolve(ROOT, process.env.QA_E2E_DIR);
  for (const d of fs.readdirSync(ROOT, { withFileTypes: true })) {
    if (!d.isDirectory() || d.name === 'node_modules' || d.name.startsWith('.')) continue;
    for (const ext of ['ts', 'js', 'mjs']) {
      if (fs.existsSync(path.join(ROOT, d.name, `playwright.config.${ext}`))) {
        return path.join(ROOT, d.name);
      }
    }
  }
  return path.join(ROOT, 'telemax-e2e');
}
const E2E = findE2E();
const E2E_NAME = path.relative(ROOT, E2E) || 'telemax-e2e';
// Tiền tố biến env cũng do e2e-scaffold đặt theo tên app (VD ACME_USER).
const PFX = process.env.QA_ENV_PREFIX || 'TELEMAX';
const PROFILE = path.join(ROOT, '.playwright-mcp-profile');
const ENV_FILE = path.join(E2E, '.env');

function die(msg) {
  console.error(msg);
  process.exit(1);
}

// Playwright nằm trong node_modules của project e2e. Import ESM phân giải theo vị trí
// FILE, không theo thư mục đang đứng — nên `cd <project e2e>` KHÔNG đủ. Trỏ thẳng đường
// dẫn tuyệt đối để script chạy được từ bất cứ đâu.
const PW_ENTRY = path.join(E2E, 'node_modules', '@playwright', 'test', 'index.mjs');
const PW_CJS = path.join(E2E, 'node_modules', '@playwright', 'test', 'index.js');
let chromium;
try {
  const mod = await import(pathToFileURL(fs.existsSync(PW_ENTRY) ? PW_ENTRY : PW_CJS).href);
  chromium = (mod.chromium ?? mod.default?.chromium);
  if (!chromium) throw new Error('không tìm thấy export chromium');
} catch (e) {
  die(
    `Không nạp được @playwright/test từ ${E2E}/node_modules.\n` +
    `Chạy: cd ${E2E_NAME} && npm install\nChi tiết: ${e.message}`
  );
}

if (!fs.existsSync(ENV_FILE)) die(`Không thấy ${ENV_FILE}. Copy .env.example sang .env rồi điền.`);

// Đọc .env thủ công. Không in giá trị nào ra stdout.
const env = {};
for (const line of fs.readFileSync(ENV_FILE, 'utf8').split('\n')) {
  const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)$/);
  if (m) env[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
}

// Selector form đăng nhập — app khác thì form khác. Khai ở `<project e2e>/.env`
// (hoặc biến môi trường cùng tên); mặc định là form Telemax để repo này không phải
// khai gì. Tiền tố chọn cách tìm: placeholder: (mặc định) · label: · testid: ·
// text: · css: · role:<vai>/<tên>.
function pick(key, fallback) {
  return process.env[key] || env[key] || fallback;
}
const SEL = {
  path:     pick('LOGIN_PATH', '/login'),
  email:    pick('LOGIN_EMAIL', 'placeholder:Enter your email'),
  password: pick('LOGIN_PASSWORD', 'placeholder:Enter your password'),
  submit:   pick('LOGIN_SUBMIT', 'role:button/Login'),
  twofa:    pick('LOGIN_2FA', 'role:heading/Two-Factor Authentication'),
  remember: pick('LOGIN_REMEMBER', 'role:checkbox/Remember this device'),
};

function loc(page, spec) {
  const m = spec.match(/^(placeholder|label|testid|text|css|role):([\s\S]*)$/);
  const [kind, val] = m ? [m[1], m[2]] : ['placeholder', spec];
  switch (kind) {
    case 'label':  return page.getByLabel(val);
    case 'testid': return page.getByTestId(val);
    case 'text':   return page.getByText(val);
    case 'css':    return page.locator(val);
    case 'role': {
      const i = val.indexOf('/');
      return i < 0
        ? page.getByRole(val.trim())
        : page.getByRole(val.slice(0, i).trim(), { name: val.slice(i + 1) });
    }
    default:       return page.getByPlaceholder(val);
  }
}

const prod = process.argv.includes('--prod');
const base = prod
  ? env.PROD_BASE_URL
  : (env.BASE_URL || 'https://dashboard-stage.telemax.com.au');
const userKey = prod ? `${PFX}_PROD_USER` : `${PFX}_USER`;
const passKey = prod ? `${PFX}_PROD_PASS` : `${PFX}_PASS`;
const user = env[userKey];
const pass = env[passKey];

if (!base) die(`Thiếu ${prod ? 'PROD_BASE_URL' : 'BASE_URL'} trong ${E2E_NAME}/.env`);
if (!user || !pass) {
  die(`Thiếu ${userKey} / ${passKey} trong ${E2E_NAME}/.env`);
}
if (prod && /stage|staging|localhost/i.test(base)) die(`PROD_BASE_URL trông không giống production: ${base}`);

// Profile đang bị MCP chiếm thì báo rõ, đừng để Chromium ném lỗi khó hiểu.
// Chromium tạo SingletonLock là SYMLINK trỏ tới `<hostname>-<pid>`, và target đó
// không tồn tại như một file. `existsSync` ĐI THEO symlink nên với link treo nó trả
// false — guard này trước đây không bao giờ kích hoạt. `lstatSync` không đi theo.
const LOCK = path.join(PROFILE, 'SingletonLock');
let locked = true;
try { fs.lstatSync(LOCK); } catch { locked = false; }
if (locked) {
  console.error(
    'Thư mục profile đang bị chiếm (có SingletonLock) — nhiều khả năng MCP đã mở browser.\n' +
    'Thoát Claude Code (hoặc đóng browser của MCP) rồi chạy lại script này TRƯỚC khi gọi tool MCP.'
  );
  process.exit(1);
}

let ctx;
try {
  ctx = await chromium.launchPersistentContext(PROFILE, {
    headless: false,
    ignoreHTTPSErrors: true,
    viewport: null,
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
  });
} catch (e) {
  die(
    `Không mở được profile ${PROFILE}.\n` +
    'Nhiều khả năng MCP đang giữ nó — thoát Claude Code rồi chạy lại script này ' +
    `TRƯỚC khi gọi tool MCP.\nChi tiết: ${e.message}`
  );
}

try {
  const page = ctx.pages()[0] ?? (await ctx.newPage());
  await page.goto(`${base}${SEL.path}`, { timeout: 120_000 });

  // Profile có sẵn session thì app tự chuyển vào trong. Báo RIÊNG trạng thái này —
  // gộp chung với LOGGED_IN sẽ che mất lỗi ở phần điền form: script in "đăng nhập
  // thành công" trong khi chưa hề gõ ký tự nào.
  const email = loc(page, SEL.email);
  const onLoginForm = await email
    .waitFor({ state: 'visible', timeout: 20_000 })
    .then(() => true)
    .catch(() => false);

  if (!onLoginForm) {
    if (/login|signin/i.test(new URL(page.url()).pathname)) {
      throw new Error(
        `Đang ở ${SEL.path} nhưng không thấy ô email (${SEL.email}) — trang chưa ` +
        'render xong, hoặc form đã đổi và LOGIN_EMAIL trong .env chưa cập nhật.'
      );
    }
    console.log(`ALREADY_LOGGED_IN url=${new URL(page.url()).pathname}`);
    await ctx.close();
    console.log('PROFILE_SEEDED');
    process.exit(0);
  }

  // Blazor bind qua event của trình duyệt. `fill()` đặt value một nhát, KHÔNG sinh
  // chuỗi event mà EditContext cần, nên nút Login giữ nguyên `disabled` và script treo
  // tới hết timeout với thông báo khó hiểu. Phải gõ từng ký tự rồi blur.
  await email.click();
  await email.pressSequentially(user, { delay: 30 });

  const password = loc(page, SEL.password);
  await password.click();
  await password.pressSequentially(pass, { delay: 30 });
  await password.blur();

  // Script này không chạy trong test runner nên không dùng `expect`. Poll thủ công để
  // khi hỏng thì báo đúng nguyên nhân thay vì nuốt vào timeout của click().
  const loginButton = loc(page, SEL.submit);
  const deadline = Date.now() + 15_000;
  let enabled = false;
  while (Date.now() < deadline) {
    if (await loginButton.isEnabled().catch(() => false)) { enabled = true; break; }
    await page.waitForTimeout(250);
  }
  if (!enabled) {
    throw new Error(
      `Nút submit (${SEL.submit}) vẫn disabled sau 15s. Form không nhận giá trị vừa ` +
      'gõ — kiểm LOGIN_EMAIL / LOGIN_PASSWORD / LOGIN_SUBMIT trong .env có còn khớp ' +
      'form không, hoặc trang có validate thêm gì không.'
    );
  }
  await loginButton.click();

  const twoFactor = loc(page, SEL.twofa);
  if (await twoFactor.isVisible({ timeout: 15_000 }).catch(() => false)) {
    const remember = loc(page, SEL.remember);
    if (await remember.isVisible().catch(() => false)) await remember.check();
    console.log('2FA_REQUIRED');   // agent thấy dòng này thì nhường quyền cho người dùng
  }

  await page.waitForURL((u) => u.pathname !== SEL.path && !/login|signin/i.test(u.pathname), { timeout: 300_000 });
  const pwCount = await loc(page, SEL.password).count();
  console.log(`LOGGED_IN url=${new URL(page.url()).pathname} passwordFields=${pwCount}`);
} catch (e) {
  console.error(
    'Không đăng nhập được trong thời gian chờ. Có thể: sai mật khẩu trong .env, tài khoản ' +
    'bị khoá, hoặc 2FA chưa được nhập.\nChi tiết: ' + e.message
  );
  await ctx.close().catch(() => {});
  process.exit(1);
}

// BẮT BUỘC đóng để nhả lock, nếu không MCP sẽ không mở được profile này.
await ctx.close();
console.log('PROFILE_SEEDED');
