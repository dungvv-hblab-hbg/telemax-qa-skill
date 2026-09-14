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
   **`stage`** (không phải `dev`, không phải `master` — `bash .claude/scripts/qa-config.sh ticket`).
   Kiểm nhanh rồi hỏi tôi xác nhận:
   ```bash
   git fetch origin stage --quiet
   git log --oneline origin/stage --grep="$1" | head
   ```
   Không thấy commit của ticket trên `stage` → **DỪNG**, hỏi tôi đã merge và build
   chưa. Chạy test khi code chưa lên là **đo bản cũ rồi ghi kết quả cho ticket mới** —
   test vẫn chạy, vẫn ra số, nên không có gì báo là sai.
   Đã merge nhưng chưa chắc đã build xong → hỏi tôi, đừng tự cho là xong.
2. **File nào** — liệt kê các `.xlsx` trong `.qa/$1/` và hỏi tôi chọn. Có đúng một
   file thì nêu tên để tôi xác nhận. **Đừng tự lấy file mới nhất.**

   Chọn xong, đọc mọi số liệu cần cho cổng 3, 4 và điều kiện AC bằng **một lệnh** —
   đừng viết openpyxl tạm:

   ```bash
   bash .claude/scripts/qa-py.sh \
     .claude/skills/testcase-template/scripts/write_defects.py \
     --file .qa/$1/<file.xlsx> --mode status
   ```

   Đọc-only, không ghi gì, không tạo `.bak`. Trả về: phân bố Round 1/2, số case đã
   có kết quả, `suggest_round` kèm lý do, `data_req` gom theo điều kiện, `manual`,
   `ac_missing`, số dòng Defects.
3. **Ghi kết quả vào Round 1 hay Round 2** — dùng `suggest_round` từ lệnh trên. Nó
   phân **ba** trạng thái, không phải hai:

   | Round 1 đang là | Đề xuất |
   |---|---|
   | trống hoàn toàn | ghi Round 1 |
   | **chỉ toàn `Blocked` / `Not Run`**, sheet Defects rỗng | **ghi đè Round 1** — đã chạm nhưng chưa thực thi case nào; đẩy sang Round 2 thì `% Executed` của Round 1 vĩnh viễn bằng 0 |
   | có kết quả thật (`Pass`/`Fail`) | ghi Round 2 |

   Nêu đề xuất **kèm số liệu thật từ JSON** (VD "Round 1 có 41 Blocked + 4 Not Run,
   Defects rỗng → đề xuất ghi đè Round 1") rồi **chờ tôi xác nhận**. Ghi nhầm round
   làm `write_defects.py` đọc sai round và `% Executed` sai theo.
4. **Test data đặc biệt** — lấy `data_req` từ JSON, đã **gom sẵn theo điều kiện**:
   "13 case cần xe có Idle/Trip data, 4 case cần account date format = null". Báo
   trước khi chạy, hỏi tôi cung cấp hay thống nhất đánh `[MANUAL]`.
   **Đừng bịa dữ liệu, đừng tự cho là có.**

   `data_req` rỗng mà bộ case là loại cũ (chưa gắn nhãn) thì tự dò từ cột
   Precondition/Test Data và nêu ra — đừng để tôi phát hiện lúc chạy tới case thứ 30.

   `ac_missing` không rỗng → nêu ra ngay ở lượt hỏi này: chạy test trên bộ case còn
   hở AC là đo sai độ phủ.
5. **MCP Playwright: có, và đúng MỘT bản** — kiểm danh sách tool (`Playwright:browser_*`)
   rồi `claude mcp list`.
   - Nhiều hơn một entry `playwright` → **DỪNG**, bảo tôi chạy `/qa-doctor` để chẩn
     (đọc-only, không cài gì) rồi làm theo lệnh nó đề xuất.
     Bản thắng có thể không mang cấu hình `.mcp.json`, và hỏng **im lặng**
     (xem [docs/DEAD-ENDS.md](../../docs/DEAD-ENDS.md) §3).
   - Thiếu MCP **và** còn case UI chưa có spec → **DỪNG**, nêu lệnh
     `claude mcp add playwright -- npx -y @playwright/mcp@latest` rồi **chờ tôi gật**.
     Chạm `.mcp.json` là phải thoát session và mở lại — sửa giữa session không có
     tác dụng và không báo gì.
   - Thiếu MCP **nhưng** mọi case UI đã có spec → chạy tiếp được; nói trước là spec
     fail sẽ không điều tra được.

   Ghi kết quả vào `MCP_OK` của khối đầu vào. Agent không kiểm lại.

6. **Session đăng nhập — seed TRƯỚC, đừng probe bằng MCP**

   Thứ tự này quan trọng: script seed cần lock trên thư mục profile, mà **gọi một
   tool MCP là MCP mở browser và chiếm lock**. Probe trước rồi mới phát hiện hết
   session thì đã tự khoá đường, và lối ra duy nhất là bắt tôi thoát Claude Code.

   ```bash
   test -L .playwright-mcp-profile/SingletonLock && echo LOCKED || echo FREE
   ```

   - **`FREE`** (chưa tool MCP nào chạy trong session này) → chạy thẳng, **không cần
     hỏi tôi**:
     ```bash
     node .claude/scripts/seed-mcp-profile.mjs
     ```
     Script idempotent: còn session thì in `ALREADY_LOGGED_IN` rồi thoát ngay, không
     gõ ký tự nào. Hết session thì nó đăng nhập lại, đọc mật khẩu từ `.env` trong
     tiến trình riêng. **Cả hai nhánh đều không phải restart Claude Code.**
     - `PROFILE_SEEDED` hoặc `ALREADY_LOGGED_IN` → xong, ghi `SESSION_OK`.
     - `2FA_REQUIRED` → nhường quyền cho tôi rồi **ĐỢI**, đừng gọi agent:

       > Đang ở màn nhập mã 2FA. Bạn nhập mã trong cửa sổ trình duyệt nhé — tôi không
       > nhận mã qua chat. Xong thì gõ **ok** để tôi kiểm rồi chạy tiếp.

       Sau đó không poll, không đoán tôi đã xong. Ba lần vẫn hỏng → dừng hẳn.
     - exit 1 → đọc thông báo lỗi, báo tôi, **đừng thử lại mù**.

   - **`LOCKED`** (session này đã gọi tool MCP rồi) → không seed được nữa. Probe
     `localStorage` trên `/favicon.ico` (URL tĩnh cùng origin, JS của app không chạy
     nên không tự xoá gì):
     ```js
     () => ({ n: localStorage.length, keys: Object.keys(localStorage) })
     ```
     | Kết quả | Nghĩa | Xử |
     |---|---|---|
     | có `authToken_*` | session còn sống | đi tiếp |
     | rỗng / chỉ `app-version` | hết session **hoặc** profile không được nạp | **DỪNG**, bảo tôi thoát Claude Code rồi chạy lại `/qa-run $1` — lần sau sẽ vào nhánh `FREE` và tự seed |

     Bỏ bước probe này là rơi vào vòng lặp: đăng nhập → vẫn `/login` → xoá
     `user.json` → ép `npm run auth` → vẫn `/login`.

   **KHÔNG điền form login bằng MCP** trong mọi trường hợp — `browser_type` để lộ mật
   khẩu nguyên văn trong transcript. Muốn làm riêng bước này thì chạy `/qa-login`.

7. **Môi trường Playwright** — thiếu `.env` của project e2e → dừng, hướng dẫn tôi tự
   cấu hình. **Đừng hỏi mật khẩu hay token qua chat.**
8. **Postman** — đọc Trạng thái: `bash .claude/scripts/qa-config.sh postman`. `CHƯA CÓ` thì **skip nhánh
   API và nói rõ sẽ skip bao nhiêu case**, đừng dừng cả chặng và đừng hỏi lại mỗi lần.

**Xác nhận:** chạy toàn bộ case hay một phần (mặc định toàn bộ); có export `.ts`
không (mặc định có, cho nhánh UI).

**Xác nhận — tiếp tục hay chạy lại từ đầu.** Round đích đã có sẵn `Pass`/`Fail` ở một
số case (lần chạy trước đứt giữa chừng — hết session, tôi bấm dừng, máy sập) thì nêu
số liệu rồi hỏi:

> "Round 1 đã có kết quả cho 30/45 case. Tiếp tục từ case 31, hay chạy lại cả 45?"

Mặc định đề xuất **tiếp tục** (`RESUME: có`). Chạy lại từ đầu một bộ 45 case là vài
chục phút, và kết quả 30 case cũ vẫn nằm nguyên trong file. Chỉ chạy lại cả bộ khi
tôi nói rõ — VD dev vừa deploy bản mới nên kết quả cũ không còn đúng.

Trước khi gọi agent, nói với tôi một dòng: muốn theo dõi tiến trình thì mở terminal
thứ hai và chạy `tail -f .qa/$1/progress.log`.

Gọi agent `test-runner` với:

```
TICKET: $1
TESTCASE_FILE: (file tôi đã chọn)
ROUND: (1 hoặc 2 — tôi đã xác nhận)
SCOPE: (toàn bộ / danh sách TC ID)
RESUME: (có = bỏ qua case đã có kết quả ở ROUND / không = chạy lại tất cả)
EXPORT_TS: (có / không)
TEST_DATA: (dữ liệu tôi cung cấp, hoặc "đánh [MANUAL]" cho case nào)
MCP_OK: (đã kiểm ở cổng 5: có/không, mấy bản, scope nào)
SESSION_OK: (đã seed/xác nhận ở cổng 6 lúc <giờ>, hoặc "?" nếu chưa kiểm được)
```

`MCP_OK` và `SESSION_OK` có giá trị → agent **dùng thẳng, không kiểm lại**. Ghi `?`
thì agent tự kiểm như cũ (trường hợp có ai gọi agent trực tiếp, không qua command).

**Agent trả về mà KHÔNG có khối tổng kết + số P/F/B** — VD chỉ nói "đang chờ background
run…" — thì coi là **thất bại**, và **KHÔNG gọi lại agent**. Artifact trên đĩa mới là sự
thật, đọc số liệu từ đó:

```bash
bash .claude/scripts/qa-py.sh .claude/skills/testcase-template/scripts/write_defects.py \
  --file .qa/$1/<file.xlsx> --mode status
```

Rồi ghi trạng thái, báo tôi số liệu đọc được, và hỏi có chạy lại với `RESUME: có` không:

```bash
bash .claude/scripts/qa-state.sh set $1 run failed "agent kết thúc không tổng kết — <số liệu đọc từ file>"
```

Gọi lại agent mù là trả thêm một lần nữa cái giá đã trả: lượt hỏng kiểu này từng tốn
423k token / 349 tool call / 37 phút và vẫn không trả kết quả.

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

**Để cửa sổ trình duyệt mở nguyên khi xong** — nó tự tắt khi tôi thoát Claude Code.

Đừng tạo bug, đừng upload Drive.

## Ghi trạng thái (bắt buộc — để `/qa-status` và resume dùng được)

**Ngay trước khi gọi agent:**
```bash
bash .claude/scripts/qa-state.sh set $1 run in_progress "chạy test"
```

**Ngay sau khi agent kết thúc**, kể cả khi hỏng — command vẫn sống sau agent, nên
đây là chỗ duy nhất ghi được cả trường hợp thất bại:
```bash
bash .claude/scripts/qa-state.sh set $1 run done   "<tóm tắt 1 dòng: P/F/B, tới case bao nhiêu>"
bash .claude/scripts/qa-state.sh set $1 run failed "<lý do dừng>"
```

Journal này là **nhật ký, không phải nguồn chân lý** — artifact trên đĩa mới là sự
thật. Đừng bỏ bước ghi: bỏ là `/qa-status` mù, và lần chạy sau không biết tiếp từ đâu.
