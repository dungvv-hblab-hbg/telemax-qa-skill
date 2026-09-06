---
description: Chạy test UI (Playwright) + API (newman) theo scope ticket, ghi kết quả và điền sheet Defects
argument-hint: TLM-XXXX
---

Chạy test cho ticket **$1**.

## Cổng đầu vào — làm TRƯỚC khi gọi agent

Ba mức: **Chặn** = không có mặc định an toàn, phải hỏi · **Xác nhận** = có mặc định
nhưng mặc định vẫn là phán đoán, nêu ra chờ tôi gật · **Tự quyết** = chuyên môn của
bạn, làm luôn nhưng liệt kê trong tổng kết. Gộp mọi câu hỏi vào MỘT lượt, mỗi câu nêu
rõ mặc định đề xuất. Không bao giờ hỏi mật khẩu/token qua chat.

**Chặn:**
1. **Code của ticket đã lên dashboard-stage chưa?** dashboard-stage build từ nhánh
   **`stage`** (không phải `dev`, không phải `master` — xem `.claude/qa-config.md`).
   Kiểm nhanh rồi hỏi tôi xác nhận:
   ```bash
   git log --oneline origin/stage --grep="$1" | head
   ```
   Không thấy commit của ticket trên `stage` → **DỪNG**, hỏi tôi đã merge và build
   chưa. Chạy test khi code chưa lên là **đo bản cũ rồi ghi kết quả cho ticket mới** —
   test vẫn chạy, vẫn ra số, nên không có gì báo là sai.
   Đã merge nhưng chưa chắc đã build xong → hỏi tôi, đừng tự cho là xong.
2. **File nào** — liệt kê các `.xlsx` trong `.qa/$1/` và hỏi tôi chọn. Có đúng một
   file thì nêu tên để tôi xác nhận. **Đừng tự lấy file mới nhất.**
3. **Ghi kết quả vào Round 1 hay Round 2** — đọc cột Round 1 rồi phân **ba** trạng
   thái, không phải hai:

   | Round 1 đang là | Đề xuất |
   |---|---|
   | trống hoàn toàn | ghi Round 1 |
   | **chỉ toàn `Blocked` / `Not Run`**, sheet Defects rỗng | **ghi đè Round 1** — đã chạm nhưng chưa thực thi case nào; đẩy sang Round 2 thì `% Executed` của Round 1 vĩnh viễn bằng 0 |
   | có kết quả thật (`Pass`/`Fail`) | ghi Round 2 |

   Nêu đề xuất kèm số liệu đọc được (VD "Round 1 có 41 Blocked + 4 Not Run, Defects
   rỗng → đề xuất ghi đè Round 1") rồi **chờ tôi xác nhận**. Ghi nhầm round làm
   `write_defects.py` đọc sai round và `% Executed` sai theo.
4. **Test data đặc biệt** — đếm case có nhãn `[DATA-REQ]` ở cột Note, **gom theo loại
   điều kiện** rồi báo trước khi chạy: "13 case cần xe có Idle/Trip data, 4 case cần
   account date format = null". Hỏi tôi cung cấp hay thống nhất đánh `[MANUAL]`.
   **Đừng bịa dữ liệu, đừng tự cho là có.**

   Bộ case cũ chưa có nhãn `[DATA-REQ]` thì tự dò từ cột Precondition/Test Data và nêu
   ra — đừng để tôi phát hiện lúc chạy tới case thứ 30.
5. **MCP Playwright đã cài chưa, và có đúng một bản không** — kiểm danh sách tool
   (`Playwright:browser_*`), rồi `claude mcp list`.

   Thấy **nhiều hơn một** entry `playwright` (scope `local`/`user` + `project`) →
   **DỪNG**. Chỉ một bản thắng, và bản thắng có thể không mang cấu hình trong
   `.mcp.json` — khi đó timeout vẫn 5s và profile đã seed **không được dùng**, nên mọi
   lệnh rơi về `/login` mà không có lỗi nào báo. Bảo tôi chạy `/qa-setup` để dọn, hoặc
   `claude mcp remove playwright -s local` rồi khởi động lại session.
   Nhánh UI chạy hai phase: **Phase 1 dò element bằng MCP Playwright** — cửa sổ trình
   duyệt sẽ hiện lên, nói trước cho tôi và nhắc tôi đừng bấm vào nó trong lúc chạy —
   rồi **Phase 2 export ra file `.ts`** (chạy lại bằng `npx playwright test` thì ngầm,
   không hiện cửa sổ). Case nào đã có spec thì bỏ qua Phase 1, chạy thẳng bằng
   `cd telemax-e2e && npx playwright test`.
   - Thiếu MCP **và** có case UI chưa có spec → **DỪNG**. Hỏi tôi có cài ngay không,
     nêu đúng lệnh sẽ chạy rồi **chờ tôi đồng ý mới chạy**:
     `claude mcp add playwright -- npx -y @playwright/mcp@latest`.
     Harness đã kèm `.mcp.json` ở gốc repo nên thường chỉ cần khởi động lại session.
     Chưa cài xong thì đừng bịa selector, và đừng tự chạy lệnh khi tôi chưa gật.

     **Chạm vào `.mcp.json` là KẾT THÚC SESSION NGAY.** MCP server đọc args lúc khởi
     động, nên sửa file giữa session **không có tác dụng gì và không có tín hiệu nào
     báo** — tool vẫn chạy, vẫn trả kết quả, chỉ là bằng cấu hình cũ. Đừng kiểm lại
     bằng MCP trong cùng session: kết quả không phản ánh file. Bảo tôi thoát rồi mở lại.
   - Chưa tải trình duyệt (`npx playwright install chromium`) → cũng hỏi rồi chạy.
   - Thiếu MCP **nhưng** mọi case UI đã có spec → chạy tiếp được, nhưng nói trước là
     spec fail sẽ không điều tra được.
6. **Session đăng nhập còn sống không** — mở dashboard-stage bằng MCP và xem có rơi
   vào trang login không. **Lần mở đầu tiên trong ngày có thể mất hơn 30 giây** (SPA
   tải nguội + trình duyệt khởi động lần đầu); đợi hết timeout rồi mới kết luận.

   Thấy `/login` thì **CHƯA được kết luận là session hết hạn** — hai nguyên nhân khác
   hẳn nhau cho cùng một triệu chứng. Probe `localStorage` trên một **URL tĩnh cùng
   origin** (`/favicon.ico`, nơi JS của app không chạy nên không tự xoá gì):

   ```js
   () => ({ n: localStorage.length, keys: Object.keys(localStorage) })
   ```

   | Kết quả | Nghĩa | Xử |
   |---|---|---|
   | có `authToken_*`, `refreshToken`… | session hết hạn thật | seed lại (dưới) |
   | chỉ `app-version` | **profile trống / MCP không nạp state** | đăng nhập lại **cũng vô ích** cho tới khi sửa cấu hình — dừng, báo tôi |

   Bỏ bước probe này là rơi vào vòng lặp: đăng nhập → vẫn `/login` → xoá `user.json` →
   ép `npm run auth` → vẫn `/login`.

   Cần seed lại → **KHÔNG điền form bằng MCP** (lộ mật khẩu trong transcript). Bảo tôi
   thoát Claude Code, chạy `node .claude/scripts/seed-mcp-profile.mjs`, rồi mở lại và
   chạy `/qa-run $1`. Script cần lock profile mà MCP đang giữ, nên phải thoát trước.

   **Hiện ra màn 2FA** (tài khoản này đang tắt, nhưng phòng khi bật lại) → **nhường
   quyền cho tôi rồi ĐỢI**, đừng gọi agent:

   > Đang ở màn nhập mã 2FA. Bạn nhập mã trong cửa sổ trình duyệt nhé — tôi không nhận
   > mã qua chat. Xong thì gõ **ok** để tôi kiểm rồi chạy tiếp.

   Sau đó **không làm gì thêm, không poll, không đoán tôi đã xong**. Tôi gõ `ok` thì
   chụp snapshot kiểm thật (URL không còn `/login`, không còn ô mật khẩu). Chưa đạt →
   báo tôi đang kẹt ở đâu rồi đợi `ok` lần nữa. Ba lần vẫn hỏng → dừng hẳn.

   Session lưu ở `.playwright-mcp-profile/` nên đăng nhập một lần là các lần sau còn
   dùng. Muốn làm riêng bước này thì chạy `/qa-login`.

7. **Môi trường Playwright** — thiếu `.env` của project e2e → dừng, hướng dẫn tôi tự
   cấu hình. **Đừng hỏi mật khẩu hay token qua chat.**
8. **Postman** — đọc Trạng thái ở `.claude/qa-config.md`. `CHƯA CÓ` thì **skip nhánh
   API và nói rõ sẽ skip bao nhiêu case**, đừng dừng cả chặng và đừng hỏi lại mỗi lần.

**Xác nhận:** chạy toàn bộ case hay một phần (mặc định toàn bộ); có export `.ts`
không (mặc định có, cho nhánh UI).

Trước khi gọi agent, nói với tôi một dòng: muốn theo dõi tiến trình thì mở terminal
thứ hai và chạy `tail -f .qa/$1/progress.log`.

Gọi agent `test-runner` với:

```
TICKET: $1
TESTCASE_FILE: (file tôi đã chọn)
ROUND: (1 hoặc 2 — tôi đã xác nhận)
SCOPE: (toàn bộ / danh sách TC ID)
EXPORT_TS: (có / không)
TEST_DATA: (dữ liệu tôi cung cấp, hoặc "đánh [MANUAL]" cho case nào)
```

Sau khi agent kết thúc, báo bằng tiếng Việt:
1. Số Pass / Fail / Blocked — tách riêng **Blocked vì chờ chạy tay `[MANUAL]`** và
   **Blocked vì vướng dependency thật**
2. Danh sách case Fail kèm Actual tóm tắt
3. File `.ts` đã export, file `result.json` của newman
4. Case nào bị `write_defects.py` skip và vì sao
5. Khối tổng kết đầu vào: tôi đã xác nhận gì, agent tự quyết gì (phân nhánh
   UI/API/Manual), còn treo gì
6. Bước tiếp theo: mở **file LOCAL** (không phải bản trên Drive), review sheet
   **Defects & Follow-ups** — sửa Actual nếu sai, đặt **Fix Status = "Won't fix"**
   cho case không muốn tạo bug (**đừng xoá dòng**), rồi chạy `/qa-file-bugs $1`

**Để cửa sổ trình duyệt mở nguyên khi xong** — đừng đóng, đừng "dọn dẹp". Lệnh sau
dùng lại chính phiên đó, khỏi khởi động lại và khỏi chờ SPA tải nguội. Nó tự tắt khi
tôi thoát Claude Code.

Đừng tạo bug, đừng upload Drive.
