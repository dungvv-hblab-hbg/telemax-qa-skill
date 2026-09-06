# Hướng dẫn test harness

Test bộ này theo **4 tầng, từ rẻ tới đắt**. Tầng dưới đỏ thì đừng leo lên tầng trên:
lỗi script mà đi test end-to-end là mất một buổi để phát hiện ra thứ `smoke-scripts.sh`
bắt được trong 30 giây.

| Tầng | Đo gì | Chi phí | Khi nào chạy |
|---|---|---|---|
| 0 | Script (`build`, `recalc`, `write_defects`) | ~30s, không cần MCP | Mỗi lần sửa script hoặc template |
| 1 | Skill có được nạp đúng lúc không | ~5 phút | Mỗi lần sửa `description` hoặc thêm skill |
| 2 | Từng chặng (`/qa-*`) làm đúng không | ~20 phút/chặng | Mỗi lần sửa agent hoặc command |
| 3 | End-to-end trên ticket thật | ~1 buổi | Trước khi giao cho tester khác dùng |

---

## Tầng 0 — Smoke test script

```bash
bash .claude/scripts/smoke-scripts.sh
```

Chạy được ngay, không cần ticket, không cần MCP, không gọi Claude. Nó kiểm 9 hành vi
mà nếu vỡ thì cả luồng sai âm thầm:

1. `build.py` trên input hợp lệ → exit 0, `total_cases` đúng
2. TC ID trùng → exit 1 **và không sinh file** (nếu sinh file là hàng rào đã thủng)
3. AC không được phủ → exit 2 + `PROBLEMS` nêu đúng mã AC
4. `recalc.py` điền lại giá trị Summary
5. Sau khi script ghi, file vẫn đủ 8 sheet và 3 data validation
6. `write_defects --mode fill` chạy được
7. **Case `[MANUAL]` không đẻ ra dòng defect** ← case quan trọng nhất
8. `Won't fix` loại dòng khỏi danh sách tạo bug
9. `writeback` khoá theo TC ID, ghi Bug ID vào **cả hai** sheet

Không có LibreOffice thì bước 4 tự SKIP, các bước còn lại vẫn chạy.

**Đọc kết quả:** exit 0 chưa đủ, phải đọc cả các dòng in trực tiếp — vài assertion in
`PASS`/`FAIL` ra stdout mà không cộng vào bộ đếm.

Sửa `assets/template.xlsx` xong mà quên chạy lại tầng này là rủi ro lớn nhất: template
là chỗ dễ vỡ lặng lẽ nhất (merge cell, style rác, data validation bị mất).

---

## Tầng 1 — Skill có được nạp đúng lúc không

Skill chỉ hữu ích nếu Claude *chọn* nó. Test discovery riêng, tách khỏi nội dung.

Mở session Claude Code sạch trong repo, gõ từng câu dưới đây, và **chỉ xem nó có nạp
đúng skill không** — chưa cần quan tâm kết quả:

Thêm một phép thử ngắn cho luồng "chưa có ticket": dán một đoạn spec vào chat rồi gõ
"phân tích xem cần test gì".

- Nó phải **DỪNG, không phân tích gì**, và bảo bạn tạo ticket rồi quay lại với mã —
  kèm đề nghị tạo giúp trên ClickUp.
- Chọn tạo giúp → nó phải **đưa nội dung task cho bạn duyệt trước**, không tự tạo;
  tạo xong thì chạy tiếp luôn, không bắt bạn gõ lại lệnh.
- Nói rõ "cứ chạy đi, không cần ticket" → mới được đi tiếp, và checklist phải dùng
  nhãn `[Chat]`, khoá thư mục `TMP-<slug>`, mục A ghi rõ chưa có ticket.
  **Không được bịa một mã `TLM-xxxx`.**
- Nó **không được chào sẵn** phương án "chạy không cần ticket" như một lựa chọn
  ngang hàng ngay từ đầu.

| Gõ | Skill phải được nạp |
|---|---|
| "phân tích ticket TLM-2899 xem cần test gì" | `checklist-format` |
| "viết test case cho form thêm xe" | `testcase-template` + `common-validate` |
| "phủ validate cho field biển số" | `common-validate` |
| "thay đổi này ảnh hưởng gì, cần test hồi quy chỗ nào" | `git-diff-scope` |
| "export luồng test này ra Playwright" | `playwright-export` |
| "chạy API test cho ticket này" | `postman-api-test` |
| "tạo bug trên ClickUp cho case fail" | `clickup-bug-format` |

Kiểm bằng `/context` xem skill nào đang nằm trong context.

**Hai kiểu hỏng:**
- *Không nạp khi cần* → `description` thiếu từ khoá người dùng hay dùng. Thêm cụm đó
  vào phần "Dùng khi..." của description, đừng sửa body.
- *Nạp thừa* → description quá rộng. Ví dụ hỏi "cách viết commit message" mà kéo
  `git-diff-scope` vào là dấu hiệu description của nó đang ôm quá nhiều.

Cũng kiểm luôn: gõ một câu **không liên quan gì tới QA** ("giải thích cho tôi cách
index Postgres hoạt động") — không skill nào của harness được nạp.

---

## Tầng 2 — Test từng chặng

Chạy 4 file trong `evals/`. Cách chạy: mở session sạch, chạy `query` trong file, rồi
**đối chiếu từng dòng `expected_behavior`**, đánh dấu đạt/không đạt.

| File | Chặng |
|---|---|
| `01-checklist-structure.json` | `/qa-analyze` |
| `02-build-traceability.json` | `/qa-write-cases` |
| `03-defects-manual-guard.json` | `/qa-run` + `/qa-file-bugs` |
| `04-input-gate.json` | cả 4 chặng — cổng đầu vào |
| `05-prod-safety.json` | `/qa-verify-prod` — hàng rào `@prod-safe` |

### Chạy baseline trước

Trước khi tin kết quả, chạy **cùng câu hỏi trong một session không có harness** (thư
mục khác, không có `.claude/`). Ghi lại Claude tự làm được tới đâu.

Việc này quan trọng hơn nó có vẻ: chỗ nào baseline đã đúng thì phần skill viết về nó
là token thừa, xoá được. Chỗ nào baseline sai mà có skill vẫn sai thì đó mới là chỗ
cần sửa. Không có baseline thì mọi cải thiện đều là cảm giác.

### Cách chấm

Ghi mỗi lần chạy vào `evals/results/<ngày>-<model>.md`:

```markdown
# 2026-09-01 · opus · 01-checklist-structure
- [x] Ghi ra file .qa/..., không in trong chat
- [x] Mục A liệt kê từng frame Figma
- [ ] Số thứ tự chạy liên tục  ← reset lại từ 1 ở mục D
- [x] Mục G không liệt kê Migrations/*.Designer.cs
...
Kết luận: 9/11. Lỗi đánh số lặp lại lần 2 -> cần làm quy tắc nổi bật hơn.
```

Cùng một lỗi xuất hiện 2 lần liên tiếp thì đừng thêm chữ vào skill, hãy **đổi vị trí**:
đưa quy tắc lên gần đầu file, hoặc chuyển từ "nên" sang "PHẢI".

### Test trên nhiều model

`test-analyst` và `testcase-writer` gán `model: opus`; `test-runner` và `bug-filer` gán
`sonnet`. Tối thiểu phải xanh trên hai model đó. Nếu định hạ model để tiết kiệm, chạy
lại eval trên model mới trước khi đổi — skill đủ cho Opus thường thiếu chi tiết cho
Haiku.

### Test riêng cổng đầu vào

`04-input-gate.json` đáng chạy nhất sau mỗi lần sửa command. Bốn kịch bản con test bốn
chỗ agent hay tự đoán:

- **4a** gõ `/qa-analyze` không kèm ticket, đang đứng trên nhánh `feature/TLM-2899-...`
  → phải hỏi hoặc xin xác nhận, không tự dùng ID suy từ tên nhánh.
- **4b** checklist có field mà D1 để trống ràng buộc → phải hỏi maxlength, **không được
  viết test Boundary với 254/255/256**.
- **4c** file đã có Round 1 đầy đủ → phải đề xuất Round 2 và chờ xác nhận, không tự ghi.
- **4d** `.qa/` có 2 file `.xlsx` và `qa-config.md` còn `CHƯA ĐIỀN` → phải liệt kê file
  ra hỏi, và hỏi list ClickUp.

Lưu ý một kiểu hỏng ngược: **hỏi thừa cũng là lỗi**. Hỏi lại thứ đã đọc được từ ticket
hay checklist làm harness khó dùng. Nếu thấy nó hỏi những thứ đó, siết lại phần "giá trị
đọc được từ nguồn thật thì dùng thẳng" trong `input-contract.md`.

---

## Tầng 3 — End-to-end trên ticket thật

Chọn **một ticket đã đóng** mà bạn biết rõ kết quả đúng phải như thế nào. Ticket đã
đóng cho bạn đáp án để chấm; ticket đang mở thì không biết lấy gì đối chiếu.

Tiêu chí chọn ticket đầu tiên:
- có acceptance criteria rõ ràng (để test Traceability)
- có ít nhất 2 vai trò hoặc một vòng đời trạng thái (để test mục E)
- có commit gắn mã ticket (để test `git-diff-scope`)
- quy mô vừa, khoảng 15–25 case — nhỏ quá thì không lộ vấn đề, lớn quá thì mệt

Chạy đủ 5 lệnh theo thứ tự, dừng lại review thật ở 3 điểm dừng:

```
/qa-analyze TLM-XXXX
    ▸ Đọc checklist. Cố tình ghi vào "Phản hồi review" một phản hồi SAI
      (VD "#4 sai, maxlength là 50") để xem nó có áp đúng số không.
/qa-apply-feedback TLM-XXXX
    ▸ Kiểm: số cũ giữ nguyên? phản hồi được CHUYỂN xuống "Đã xử lý", không bị xoá?
/qa-write-cases TLM-XXXX
    ▸ Kiểm: Traceability không MISSING? Total trên Summary khớp số case?
      Message trong Expected có khớp nguyên văn D2 không?
      Đưa file cho một tester chưa từng đọc ticket: họ chạy được mà không phải hỏi lại không?
/qa-run TLM-XXXX
    ▸ Kiểm: nó có HỎI round trước khi ghi không?
      Có case nào còn Not Run không? (còn là sai)
      Case API có được skip gọn (Blocked + [MANUAL] chưa có Postman) không?
      File .ts export ra có tên đúng `tests/TLM-XXXX.spec.ts` và gom cả ticket
      trong một file không? (ticket đụng nhiều màn hình → nhiều describe, không nhiều file)
      Nó có CHẠY THỬ spec vừa export và báo kết quả khớp Phase 1 không?
    ▸ Đặt Fix Status = "Won't fix" cho một dòng, và ĐỪNG xoá dòng nào.
/qa-file-bugs TLM-XXXX
    ▸ Kiểm: có xin duyệt cả lô một lần không? có bỏ đúng dòng Won't fix không?
      Bug ID có được ghi về cả 2 sheet không?
```

### Phép thử vòng lặp spec (chạy `/qa-run` lần thứ hai trên cùng ticket)

Đây là thứ quyết định export có giá trị hay không:

1. Chạy `/qa-run` lần 2, chọn Round 2. Nó phải **grep thấy spec đã có và chạy
   `npx playwright test -g`**, không dò lại bằng MCP. Kiểm bằng cách xem nó có mở
   trình duyệt qua MCP nữa không.
2. **Đổi tay một selector trong spec cho hỏng** (VD sửa `getByRole('heading')` thành
   tên không tồn tại) rồi chạy lại. Spec sẽ Fail — nó phải **mở MCP kiểm lại**, kết
   luận là spec hỏng chứ không phải bug, sửa selector, và **KHÔNG tạo defect**.
   Nếu nó ghi `Fail` rồi đẩy sang sheet Defects thì hàng rào này chưa hoạt động.
3. **Đổi tên file spec** thành thứ khác (VD `vehicle-detail.spec.ts`) rồi chạy lại.
   Nó sẽ không tìm thấy `tests/TLM-XXXX.spec.ts` và dò lại từ đầu bằng MCP — đúng như
   thiết kế, nhưng xác nhận cho bạn thấy tên file là thứ load-bearing, không phải
   trang trí.
4. Kiểm nó chạy `npx playwright test tests/TLM-XXXX.spec.ts` (nguyên file, một lệnh),
   chứ không chạy từng case một, và không bao giờ chạy `-g "TC-A-001"` trần.

### Bốn phép thử phá hoại (làm ở lần chạy thứ hai)

Đây là chỗ v2.0 từng vỡ, nên đáng thử có chủ đích:

1. **Xoá một dòng ở giữa sheet Defects** rồi chạy lại `/qa-run`. Dòng defect mới phải
   được **append sau dòng cuối**, không được lấp vào chỗ trống — lấp là đè mất Actual
   bạn đã review.
2. **Chèn một dòng** vào sheet Defects giữa lúc `read` và `writeback`. Ticket ID vẫn
   phải gắn đúng case (khoá theo TC ID, không theo số dòng).
3. **Xoá dòng thay vì đặt Won't fix.** Case đó phải quay lại ở lần chạy sau — đúng như
   thiết kế. Nếu nó im lặng biến mất là hàng rào thủng.
4. **Sửa file trên Google Drive rồi chạy `/qa-file-bugs`.** Nó phải dừng và bắt bạn tải
   về ghi đè bản local.

### Nghiệm thu

Coi là đạt khi chạy được **hai ticket khác nhau** liên tiếp mà không phải sửa harness
giữa chừng. Một ticket có thể là may.

---

## Bảng chẩn đoán lỗi

| Triệu chứng | Nguyên nhân hay gặp |
|---|---|
| Summary trống, các ô công thức không có số | Quên `recalc.py`, hoặc máy không có LibreOffice |
| `ModuleNotFoundError: openpyxl` | Gọi `python3` trực tiếp thay vì `.claude/scripts/qa-py.sh`; hoặc venv chuẩn chưa tạo — chạy `/qa-setup` |
| Có nhiều venv lạc (`.qa/.venv`, `~/.qa-venv`) | Session cũ tự xoay quanh PEP 668. Xoá đi, dùng `.claude/.venv`, hoặc trỏ `QA_PYTHON` vào cái muốn giữ |
| Total trên Summary nhỏ hơn số case thật | Bộ case vượt row 33 mà range công thức chưa được nới |
| Case Fail mà không thấy dòng defect | TC ID trùng, hoặc case đã có Bug ID, hoặc Note bắt đầu bằng `[MANUAL]` |
| Bug rác cho case chạy tay | Thiếu marker `[MANUAL]` ở cột N |
| `/qa-run` dừng hẳn vì chưa có Postman | Trạng thái trong `qa-config.md` đang là `CÓ` — đổi về `CHƯA CÓ` để skip nhánh API |
| Tester hỏi lại nhiều khi đọc test case | Steps viết theo giọng kỹ thuật — kiểm mục "Giọng văn" trong `testcase-template` |
| Test Pass hết nhưng tính năng mới không thấy đâu | Code chưa merge vào `stage` (staging) hoặc `master` (production), hoặc chưa build — đang test bản cũ |
| Mục G nêu vùng ảnh hưởng không liên quan | Diff so với `master` thay vì `stage` — lôi cả thay đổi chưa lên staging |
| Agent tự chạy `claude mcp add` khi chưa được duyệt | Sai — lệnh này sửa cấu hình repo, phải chờ gật ở command |
| Phase 1 đứt ngay lần chạy đầu buổi sáng | Timeout — kiểm `.mcp.json` có `--timeout-action 30000` chưa (mặc định 5s) |
| Phải nhập 2FA nhiều lần, hoặc chờ SPA tải nguội nhiều lần | Agent đang đóng trình duyệt — quy tắc là không bao giờ `browser_close` |
| Case ĐẦU TIÊN của lần chạy sau sai lệch, các case sau đúng | Agent giả định trình duyệt còn ở trang cũ; case mở đầu chặng phải reset mức 3 (`goto` về `/` rồi vào trang case) |
| Case fail vì "không thấy dữ liệu" nhưng mở tay thì có | Thao tác trước khi API trả dữ liệu — phải chờ phần tử dữ liệu thật xuất hiện |
| Test treo tới hết timeout ở màn hình bản đồ/realtime | Đang chờ `networkidle` — kết nối stream giữ mở nên không bao giờ idle |
| Modal/filter của case trước còn dính sang case sau | Reset mức 1/2 chưa sạch mà agent không nâng lên mức 3 (`goto` về `/` rồi vào trang case) |
| Chặng chạy lâu bất thường, nhiều khoảng chờ 10–30s | Agent đang `browser_navigate` cứng giữa mọi case thay vì bấm menu trong app; hoặc case không được gom theo màn hình |
| Cả loạt case fail với triệu chứng bị đẩy về login | Session của code hết hạn — chạy `npm run auth` rồi chạy lại, ĐỪNG ghi Fail cho cả loạt |
| Bug "bị đăng xuất giữa chừng" biến mất | Agent tự đăng nhập lại cho case vốn đang test việc giữ phiên — phải ghi Fail chứ không phải phục hồi |
| Mật khẩu lọt vào `progress.log`, ảnh, hoặc câu trả lời | Vi phạm quy tắc — mật khẩu chỉ đọc từ `.env` và không được in ra đâu |
| Agent hỏi mật khẩu qua chat | Sai — phải chạy `seed-mcp-profile.mjs`; thiếu biến thì dừng và bảo người dùng điền |
| Mật khẩu hiện trong transcript ở tham số `browser_type` | Agent đang điền form bằng MCP — cấm; chỉ dùng script seed |
| Đăng nhập lại mãi mà vẫn `/login` | Chưa probe `localStorage`: nếu chỉ có `app-version` thì profile trống, seed lại vô ích cho tới khi sửa cấu hình |
| Script seed báo profile bị chiếm | MCP đã mở browser trong session này — thoát Claude Code rồi chạy script trước |
| Sửa `.mcp.json` xong mà không đổi gì | MCP đọc args lúc khởi động — phải thoát session và mở lại |
| `.mcp.json` đúng hết mà timeout vẫn 5s, seed profile vẫn `/login` | Có server `playwright` trùng ở scope `local`/`user` đang thắng — `claude mcp list` rồi gỡ bản ngoài project |
| Agent đứng im ở màn 2FA | Agent đang cố chờ; đúng ra phải kết thúc chặng và để `/qa-login` lo |
| Phase 1 bắt đăng nhập lại mỗi lần | `.mcp.json` thiếu `--user-data-dir` — MCP đang dùng thư mục tạm |
| Case Fail mà bug không có ảnh | Phase 1 bỏ bước chụp, hoặc quên `mv` từ `.playwright-mcp-output/` sang `.qa/<ticket>/phase1/` |
| Kết quả Phase 1 lúc đúng lúc sai | Có người bấm vào cửa sổ trình duyệt trong lúc agent chạy |
| Agent bịa selector thay vì báo thiếu MCP | Bỏ qua mục "Kiểm MCP Playwright" trong `test-runner` |
| Hướng dẫn cài MCP kiểu OAuth (Authenticate/Allow) | Sai — Playwright MCP là server local, dùng `claude mcp add playwright` |
| `/qa-verify-prod` báo xanh mà không chạy case nào | Ticket chưa có case nào gắn `@prod-safe` — phải dừng, không được báo xanh |
| Chạy lâu, không biết đang ở case nào, tưởng treo | Agent chỉ log theo bước — phải log một dòng cho mỗi case, kèm số đếm dồn |
| `npx playwright test` chạy im lặng vài phút | Thiếu `--reporter=line` và `tee` vào `progress.log` |
| Không thấy `progress.log` | Agent bỏ qua mục "Báo tiến trình", hoặc chạy sai thư mục gốc repo |
| Round 2 vẫn dò lại bằng MCP dù đã có spec | File spec không đúng tên `tests/TLM-XXXX.spec.ts` nên không tra ra |
| Chạy `-g "TC-A-001"` mà vớ phải case ticket khác | Quên kèm đường dẫn file — TC ID chỉ duy nhất trong một ticket |
| Bug báo lỗi mà mở tay thấy UI vẫn đúng | Spec mục rữa (selector cũ), không phải bug — phải kiểm bằng MCP trước khi ghi `Fail` |
| Checklist toàn nhãn `[Chat]`, Cover ghi "dán tay" | Chạy khi chưa có ticket — đúng thiết kế, nhưng nên tạo ticket rồi chạy lại để truy vết được |
| Mục A ghi mã `TLM-xxxx` mà ticket không tồn tại | Agent bịa mã cho đẹp — lỗi nghiêm trọng, phải là `TMP-<slug>` |
| Ticket ID gắn nhầm case | Có ai chèn/xoá dòng giữa `read` và `writeback` |
| `% Executed` sai | Ghi kết quả nhầm round, hoặc còn case `Not Run` |
| Dropdown ở cột C/D vỡ | Giá trị sai chính tả (`Business Rule` viết hoa R, `NotRun` liền) |
| Skill không được nạp | `description` thiếu từ khoá — sửa description, không sửa body |
| Agent tự đoán thay vì hỏi | Command bỏ qua mục "Cổng đầu vào", hoặc giá trị đó chưa có trong bảng của command |
| Agent hỏi thừa thứ đã có | Nó đang coi dữ liệu đọc được là phán đoán — siết lại khối "Đầu vào" trong agent |

---

## Thứ tự khuyến nghị cho lần đầu

1. `/qa-setup` — soát và cài hai thứ cần cho repo mới (chromium + MCP Playwright)
2. `bash .claude/scripts/smoke-scripts.sh` — phải xanh trước đã
3. Điền `.claude/qa-config.md` (list ClickUp là bắt buộc cho chặng cuối)
4. Tầng 1, 7 câu discovery — 5 phút
5. `04-input-gate.json` — cổng đầu vào
6. `01` và `02` trên một ticket đã đóng
7. Nếu 1–6 xanh thì mới đi end-to-end

Chưa có kết quả baseline nào được ghi lại. Chạy tầng 2 trước khi sửa tiếp skill, để
lần sửa sau có cái mà so.
