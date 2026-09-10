# Phase 1 — vận hành trình duyệt qua MCP

**Ai đọc:** `test-runner`, và CHỈ khi bước 2a-0 xác định còn case UI **chưa có spec**
(tức là phải dò bằng MCP). Case đã có spec chạy bằng `npx playwright test --project=chromium` không cần
một dòng nào trong file này.

Vì sao tách khỏi `test-runner.md`: đây là ~2.000 token chỉ dùng ở một nhánh. Round 2
trở đi, khi spec đã export xong, nhánh đó thường không chạy nữa — nạp nó mỗi lần
`/qa-run` là trả tiền cho tri thức không dùng.

---

## Trình duyệt: MỘT phiên duy nhất, không bao giờ đóng

**Áp dụng cho toàn bộ chặng — cả khi dùng MCP ở bước 2a-1 (điều tra spec fail) lẫn
2a-2 (dò case mới), và cả khi command đã mở sẵn cửa sổ lúc đăng nhập.**
Mở một lần ở case đầu tiên rồi giữ nguyên: giữa các case, và **cả khi chặng đã xong**.

- KHÔNG gọi `browser_close`. Không giữa các case, không ở cuối chặng, không "dọn dẹp"
  trước khi kết thúc.
- KHÔNG mở tab mới cho mỗi case — dùng lại tab đang có, chỉ `browser_navigate`.
- Case làm bẩn trạng thái (mở modal, filter dở dang) → reset bằng điều hướng, đừng
  khởi động lại trình duyệt.

Vì sao cứng: mỗi lần mở lại tốn khởi động trình duyệt cộng SPA tải nguội (hơn 30
giây), và **tài khoản có bật 2FA thì còn là một lần người dùng phải đi lấy mã**.
Chặng 20 case mà đóng/mở mỗi case sẽ thành 20 lần chờ người.

Để browser sống tiếp sau khi chặng kết thúc là **đúng ý muốn**: lệnh `/qa-run` tiếp
theo dùng lại ngay, không phải khởi động lại. Nó tự đóng khi người dùng thoát Claude
Code, không cần bạn dọn.

**Đổi lại: KHÔNG được giả định trình duyệt đang ở đâu.** Nó có thể đang ở trang của
lần chạy trước, đang mở modal, hay đang giữ filter cũ.

**Reset giữa các case — dùng mức NHẸ NHẤT còn hiệu quả, không phải lúc nào cũng `goto`:**

| Mức | Khi nào | Làm gì | Chi phí |
|---|---|---|---|
| 1 | case tiếp theo **cùng màn hình** | đóng modal, xoá filter/ô tìm kiếm, cuộn lên đầu. Không điều hướng | ~0 |
| 2 | case tiếp theo **khác màn hình** | điều hướng **trong app** — bấm menu/link, KHÔNG `browser_navigate` | dưới 1 giây |
| 3 | mức 2 không sạch, hoặc trạng thái kẹt (dialog không đóng được, app lỗi) | `browser_navigate` về `/` rồi `browser_navigate` tới trang của case | **10–30 giây** |

**Vì sao không mặc định mức 3:** `browser_navigate` chạy `page.goto()` — tải lại
document, tải và parse lại bundle JS, dựng lại cả app. Đó là 10–30 giây mỗi lần. Bộ 45
case mà reset cứng hai bước cho mỗi case là 90 lần tải, riêng phần chờ đã hơn 15 phút.

Mức 2 vẫn ép đổi route thật nên component remount — đủ sạch cho hầu hết trường hợp, mà
không tải lại bundle. Đi thẳng `browser_navigate` tới **đúng URL đang đứng** mới là thứ
không đủ: SPA có thể không remount, modal vẫn mở, filter vẫn giữ.

**Sau reset mức 1 hoặc 2, vẫn phải kiểm màn hình đã ở đúng trạng thái xuất phát** trước
khi thao tác — thấy sót modal hay filter cũ thì nâng lên mức 3. Nghi ngờ thì lên mức
cao hơn: một lần `goto` thừa tốn 20 giây, một case sai vì trạng thái bẩn tốn cả buổi
truy.

Bỏ bước reset này thì case đầu tiên của lần chạy sau sẽ sai lệch trong khi các case
sau đúng hết — trông y hệt một bug sản phẩm, mà chạy lại riêng nó thì lại pass.

### Bị đẩy về login giữa chừng — phân biệt nguyên nhân rồi bàn giao

Session có thể hết hạn ngay giữa chặng. Sau mỗi lần điều hướng, nếu thấy URL rơi về
`/login` hoặc ô mật khẩu xuất hiện trở lại:

1. **Trước tiên hỏi: đây có phải chính điều đang test không?** Case nào có Expected
   liên quan tới việc giữ đăng nhập, quyền truy cập, hay hết phiên → **bị đẩy về login
   CHÍNH LÀ kết quả**, ghi `Fail`/`Pass` theo Expected. Đừng coi là sự cố rồi phục hồi —
   làm vậy là xoá mất bug.

2. **Phân biệt hai nguyên nhân trước khi làm gì tiếp.** Probe `localStorage` trên URL
   tĩnh cùng origin (`/favicon.ico` — JS của app không chạy ở đó nên không tự xoá gì):

   ```js
   () => ({ n: localStorage.length, keys: Object.keys(localStorage) })
   ```

   - Có `authToken_*` / `refreshToken` → **session hết hạn thật**.
   - Chỉ `app-version` → **profile trống**, seed lại bao nhiêu lần cũng vô ích cho tới
     khi sửa cấu hình. Kết thúc chặng, báo người dùng, đừng lặp.

3. **Session hết hạn thật → KẾT THÚC CHẶNG.** Báo người dùng đúng hai câu:

   > Session hết hạn ở case <n>/<tổng>. Thoát Claude Code rồi chạy lại `/qa-run <TICKET>`
   > — cổng 6 sẽ tự đăng nhập lại và tiếp tục từ case <n>, không phải chạy lại từ đầu.

   Không bảo họ tự chạy script: `/qa-run` làm việc đó ở cổng 6 (nhánh `FREE`).
   Không tự đăng nhập bằng MCP: `browser_type` với mật khẩu lộ nguyên văn trong
   transcript. Và không tự chạy script lúc này: MCP đang giữ lock trên thư mục
   profile, script sẽ không mở được.

   **Trước khi kết thúc, ghi kết quả của các case ĐÃ chạy xong vào Excel.** Bỏ qua
   bước này là mất hết công của chặng và lần sau `RESUME` không có gì để bám.

4. **Ghi lại**: một dòng `qa-log.sh` và một dòng trong tổng kết, kèm case đang dở tới
   đâu để lần chạy sau biết chỗ tiếp tục. Case đang dở coi như chưa chạy — đừng ghi
   kết quả cho nó.

Session hết hạn hai lần trở lên trong các chặng gần nhau là tín hiệu hết phiên quá sớm,
đáng nêu cho dev.
