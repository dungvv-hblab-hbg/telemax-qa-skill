---
description: Đăng nhập vào profile MCP bằng script seed (mật khẩu không qua transcript), giữ session cho các lần chạy sau
argument-hint: (không cần tham số · thêm "prod" nếu đăng nhập production)
---

Đăng nhập vào dashboard để Phase 1 dùng lại session.

Chạy khi: lần đầu cài harness, hoặc `/qa-run` báo đang ở trang login (session hết hạn).

## Phân vai

- **Email + mật khẩu**: chạy script, script tự đọc `telemax-e2e/.env`.
  **KHÔNG điền form bằng MCP** — `browser_type({text: "<mật khẩu>"})` để lộ mật khẩu
  nguyên văn trong transcript. Script chạy trong tiến trình Node riêng nên mật khẩu
  không bao giờ đi qua context.
- **Mã 2FA**: tôi tự nhập trong cửa sổ. Mã chỉ tôi mới có.

Tài khoản QA hiện tại đã tắt 2FA, nên thường chỉ cần bước đầu — command này vẫn giữ
nhánh 2FA để khi bật lại thì không hỏng.

Session lưu ở `.playwright-mcp-profile/` (khai báo `--user-data-dir` trong `.mcp.json`,
đã gitignore), nên **đăng nhập một lần là các phiên sau còn dùng được**.

## Các bước

**1. Kiểm chưa đụng MCP trong session này**

Script seed cần lock trên thư mục profile, mà MCP đã mở browser thì nó giữ lock. Nếu
session này đã gọi tool MCP nào rồi → bảo tôi **thoát Claude Code và mở lại**, rồi chạy
`/qa-login` ngay từ đầu. Script tự kiểm `SingletonLock` và báo lỗi rõ nếu vẫn bị chiếm.

**2. Chạy script seed**

```bash
node .claude/scripts/seed-mcp-profile.mjs          # staging
node .claude/scripts/seed-mcp-profile.mjs --prod   # production, khi tôi gõ /qa-login prod
```

Chạy được từ bất cứ thư mục nào. Cửa sổ sẽ hiện lên; **lần đầu trong ngày có thể mất
hơn 30 giây** vì SPA tải nguội — đừng vội kết luận là treo.

Đọc stdout, không đoán:

| In ra | Nghĩa | Làm gì |
|---|---|---|
| `LOGGED_IN ...` rồi `PROFILE_SEEDED` | xong | sang bước 3 |
| `2FA_REQUIRED` | đang chờ tôi nhập mã | xem dưới |
| exit code 1 | thiếu `.env`, sai mật khẩu, hoặc profile bị chiếm | đọc thông báo lỗi, báo tôi, đừng thử lại mù |

**`2FA_REQUIRED`** → script đang tự chờ tới 5 phút. Nói với tôi rồi **dừng lại chờ**:

> Đang ở màn nhập mã 2FA. Bạn nhập mã trong cửa sổ trình duyệt nhé — tôi không nhận mã
> qua chat. Xong thì gõ **ok** để tôi kiểm tra và chạy tiếp.

Sau đó **KHÔNG làm gì thêm**. Đừng thao tác trong cửa sổ, đừng đoán tôi đã xong, đừng
poll liên tục — mỗi lần kiểm là một tool call, và bạn không biết tôi cần bao lâu để lấy
mã 2FA. Chờ tôi gõ `ok`.

**3. Kiểm kết quả — đọc output của script, không tin cảm giác**

Script tự kiểm trước khi kết thúc: nó chỉ in `LOGGED_IN url=... passwordFields=0` khi
đã rời trang login và không còn ô mật khẩu. Có dòng đó **và** `PROFILE_SEEDED` là đạt.

Chờ 2FA: sau khi tôi gõ `ok`, xem script đã in hai dòng đó chưa. Chưa → báo tôi đang kẹt
ở đâu rồi đợi `ok` lần nữa. Ba lần vẫn chưa xong → dừng hẳn.

Script kết thúc bằng `ctx.close()` để **nhả lock**, nếu không MCP sẽ không mở được
profile. Không thấy `PROFILE_SEEDED` thì đừng chạy `/qa-run` — MCP sẽ vấp lock.

**3b. Hỏi tôi có làm luôn session cho phần chạy bằng code không**

Harness có **hai session tách biệt**: session của MCP (vừa đăng nhập xong, dùng cho
Phase 1) và session của project e2e (`telemax-e2e/playwright/.auth/user.json`, dùng khi
chạy `npx playwright test`).

Nếu session thứ hai chưa có hoặc đã hết hạn, hỏi tôi có muốn làm luôn trong lần này
không — đằng nào tôi cũng đang ngồi đây với mã 2FA trong tay:

```bash
cd telemax-e2e && npm run auth:headed
```

Nói trước là sẽ phải **nhập mã 2FA lần nữa** (hai session, hai lần đăng nhập). Tôi từ
chối thì thôi, ghi nhận là session code chưa sẵn sàng.

**4. Xác nhận đã lưu session**

Báo ngắn: đã đăng nhập vào môi trường nào, bằng tài khoản nào (chỉ email, đừng lặp lại
gì khác), và session giữ ở `.playwright-mcp-profile/`.

Nhắc tôi: session này dùng lại cho các lần `/qa-run` sau; hết hạn thì chạy lại
`/qa-login`. Đóng cửa sổ trình duyệt cũng không mất session, nhưng xoá thư mục profile
thì mất.

**Để cửa sổ trình duyệt mở nguyên** — đừng đóng sau khi đăng nhập xong. `/qa-run` sẽ
dùng lại chính cửa sổ đó, khỏi phải khởi động lại và khỏi chờ SPA tải nguội lần nữa.

Rồi mời tôi chạy `/qa-run TLM-XXXX`.

## Ranh giới

- **KHÔNG điền form login bằng MCP.** `browser_type` với mật khẩu để lộ nguyên văn
  trong transcript. Chỉ dùng script.
- Mật khẩu **chỉ lấy từ `.env`**. KHÔNG hỏi, KHÔNG nhận qua chat kể cả khi tôi chủ động
  đưa — bảo tôi đặt vào `.env`. Không truyền qua tham số dòng lệnh (lộ qua `ps`).
- KHÔNG in mật khẩu ra câu trả lời, `progress.log`, hay tên file.
- Mã 2FA thì tuyệt đối không nhận, không đoán, không tự sinh.
- KHÔNG chạy tiếp sang test — command này chỉ lo đăng nhập.
