---
description: Rà lại lượt chạy vừa xong của một ticket, hai agent review độc lập, đối chiếu rồi xuất báo cáo cải tiến harness
argument-hint: TLM-XXXX
---

Rà lại lượt chạy QA của ticket **$1** và đề xuất cải tiến **harness**.

Chặng này soi **harness**, không soi sản phẩm. Case Fail vì dev code sai là việc của
`/qa-file-bugs`. Ở đây chỉ tìm chỗ harness làm sai, làm thiếu, hoặc làm đúng luật mà
luật sai.

## Cổng đầu vào — làm TRƯỚC khi gọi agent

Ba mức: **Chặn** = không có mặc định an toàn, phải hỏi · **Xác nhận** = có mặc định
nhưng mặc định vẫn là phán đoán, nêu ra chờ tôi gật · **Tự quyết** = chuyên môn của
bạn, làm luôn nhưng liệt kê trong tổng kết. Gộp mọi câu hỏi vào MỘT lượt.

**Chặn:**

1. **Đã chạy test chưa** — `bash .claude/scripts/qa-state.sh get $1`. Chặng `run` chưa
   có (`done` hoặc `failed`) → **DỪNG**, hỏi tôi. Chưa chạy test thì không có lượt nào
   để rà.

   `run` là `failed` là ca **đáng rà nhất**, không phải lý do dừng — đi tiếp.

2. **File test case nào** — có nhiều `.xlsx` trong `.qa/$1/` thì hỏi tôi chọn, đúng một
   file thì nêu tên để tôi xác nhận. **Đừng tự lấy file mới nhất.**

**Xác nhận:** model cho hai bản review. Mặc định **bản A `opus`, bản B `fable`**. Hai
model khác nhau là chủ ý — xem "Vì sao hai bản" bên dưới. Muốn rẻ thì đổi B sang
`sonnet`; muốn chạy một bản thì nói rõ, tôi sẽ nêu mất gì.

## 1. Thu bằng chứng CƠ HỌC — chạy thẳng, không subagent

Chạy trước khi gọi agent, ghi vào `.qa/$1/retro-facts.md`.

**Vì sao command làm chứ không để agent tự mò:** hai agent phải đọc **cùng một bộ số**.
Để mỗi agent tự chạy lệnh thì chỗ chúng lệch nhau có thể chỉ vì agent này gọi trúng
lệnh còn agent kia thì không — mất sạch ý nghĩa của việc đối chiếu. Và số do lệnh sinh
ra thì không ai bịa được.

```bash
E2E=$(bash .claude/scripts/qa-config.sh playwright | grep -oE '[a-z0-9-]+/' | head -1)
E2E="${E2E%/}"          # bỏ dấu / cuối, nếu không mọi đường dẫn thành `<e2e>//...`

# Tiến trình: bước nào thiếu, thứ tự có đảo không, khoảng lặng dài nhất
cat .qa/$1/progress.log

# Trạng thái từng chặng + note (note hai chặng mâu thuẫn nhau là tín hiệu mạnh)
bash .claude/scripts/qa-state.sh get $1

# Số liệu Excel — đọc-only, không tạo .bak
bash .claude/scripts/qa-py.sh \
  .claude/skills/testcase-template/scripts/write_defects.py \
  --file .qa/$1/<file.xlsx> --mode status

# Ticket đã lên stage chưa, có chuỗi revert không
git fetch origin stage --quiet
git log --oneline --first-parent origin/stage --grep="$1"

# Secret của e2e có được ignore không (rò credential là mức High mặc định).
# PHẢI lặp từng file: `git check-ignore -q` chỉ nhận MỘT đường dẫn — truyền hai cái là
# `fatal: --quiet is only valid with a single pathname`, và nhánh `||` sẽ báo "chưa
# ignore" kể cả khi thật ra đã ignore đúng. Đó là báo động giả, không phải phát hiện.
for f in "$E2E/.env" "$E2E/playwright/.auth/user.json"; do
  git check-ignore -q "$f" || echo "SECRET CHƯA IGNORE: $f"
done

# Spec .ts: số test, số TC- duy nhất, số @prod-safe
test -f "$E2E/tests/$1.spec.ts" && \
  grep -c "test(" "$E2E/tests/$1.spec.ts" && \
  grep -oE "TC-[A-Z0-9]+-[0-9]{3}" "$E2E/tests/$1.spec.ts" | sort -u | wc -l && \
  grep -c "@prod-safe" "$E2E/tests/$1.spec.ts"

# Harness có đổi gì kể từ lượt chạy không (đổi giữa chừng làm sai lệch kết luận)
git log --oneline -5 -- .claude/
```

Thêm một lượt đọc Excel cho các số mà `--mode status` không trả — gộp **một** lệnh,
đừng rải nhiều đoạn openpyxl tạm:

```bash
bash .claude/scripts/qa-py.sh -c "
import openpyxl, sys
wb = openpyxl.load_workbook('.qa/$1/<file.xlsx>')
a = wb['Assumptions & Questions']
rows = sum(1 for r in range(4, a.max_row+1) if a.cell(r,1).value)
print('Assumptions rows:', rows)
t = wb['Traceability']
print('Traceability MISSING:', sum(1 for r in range(4, t.max_row+1) if t.cell(r,5).value=='MISSING'))
"
```

Ghi `retro-facts.md` gồm: tiến trình (nêu rõ **bước thiếu**, **thứ tự đảo**, **khoảng
lặng > 5 phút**), trạng thái + note từng chặng, số P/F/B, lý do `[MANUAL]` **gom theo
nhóm kèm số lượng**, AC hở, số dòng Assumptions, số liệu spec `.ts`, kết quả kiểm
secret, ticket trên `stage` + có revert không.

**Chỉ ghi số đọc được. Không diễn giải, không kết luận** — diễn giải là việc của agent,
và facts phải trung lập với cả hai bản.

## 2. Hai bản review SONG SONG — không lẫn context

```
retro-facts.md ─┬─► retro-analyst (bản A, opus)  ─► .qa/$1/retro-A.md ─┐
                │                                                      ├─► bạn đối chiếu
                └─► retro-analyst (bản B, fable) ─► .qa/$1/retro-B.md ─┘
```

**Vì sao hai bản:** chỗ hai bản **cùng thấy** là tín hiệu mạnh · chỗ **chỉ một bản
thấy** là chỗ cần soi kỹ · chỗ hai bản **mâu thuẫn** thường là một bên bịa. Một bản thì
không có cái nào trong ba.

**Gọi cả hai trong CÙNG MỘT message** để chúng chạy song song, và **truyền `model` khác
nhau** — cùng một file agent, hai model. Chúng không phụ thuộc nhau.

`retro-analyst` (bản A, `model: opus`):
```
TICKET: $1
FACTS: .qa/$1/retro-facts.md
SLOT: A
OUTPUT: .qa/$1/retro-A.md
```

`retro-analyst` (bản B, `model: fable`):
```
TICKET: $1
FACTS: .qa/$1/retro-facts.md
SLOT: B
OUTPUT: .qa/$1/retro-B.md
```

Một bản dừng giữa chừng → **vẫn đi tiếp** với bản còn lại, và ghi rõ trong báo cáo là
chỉ có một bản (mất khả năng đối chiếu, nên mọi phát hiện đều phải verify chặt hơn).
Cả hai dừng → dừng chặng, ghi state `failed`.

Agent trả về mà **không ghi file** → coi là thất bại, **không gọi lại agent**. Ghi state
`failed`, báo tôi, hỏi có chạy lại không.

## 3. Đối chiếu + VERIFY — phần quan trọng nhất, bạn làm, không giao agent

Đọc `retro-A.md` và `retro-B.md`. Gộp phát hiện trùng (cùng nguyên nhân gốc = một dòng,
dù hai bản đặt tên khác nhau).

**Rồi chạy `Lệnh kiểm` của TỪNG phát hiện.** Không phát hiện nào vào báo cáo mà chưa
chạy lệnh của nó.

| Kết quả chạy lệnh | Xử |
|---|---|
| Khớp `Mong đợi nếu đúng` | vào **bảng phát hiện** |
| Không khớp | xuống mục **"Đã bác bỏ"**, kèm lệnh + output thật |
| Lệnh không chạy được / agent không đưa lệnh | xuống **"Chưa kiểm được"**, ghi rõ cần gì |

Đây không phải thủ tục cho đẹp. Ở bản review harness gần nhất, cổng này bác được một
phát hiện mức Low nghe rất hợp lý ("5 tham chiếu chết tới `docs/DEAD-ENDS.md`") — chạy
lệnh ra file tồn tại và cả 5 link resolve. **Hai agent không có cổng verify thì chỉ
nhân đôi số phát hiện ảo.**

Phát hiện **chỉ một bản thấy** không bị loại vì lý do đó — nó vẫn phải qua đúng cổng
lệnh như mọi phát hiện khác. Cột "Hai bản" chỉ để tôi biết soi chỗ nào kỹ hơn.

## 4. Xuất báo cáo markdown

Ghi **`.qa/$1/retro-<YYYY-MM-DD>.md`**:

```markdown
# Retro — <TICKET>

**Ngày:** YYYY-MM-DD · **Lượt chạy:** <ngày chạy test, lấy từ state.json>
**Model:** bản A <model> · bản B <model>
**Đã verify:** <n>/<tổng> phát hiện chạy được Lệnh kiểm

## Tóm tắt
<2-4 dòng: lượt chạy có ra kết quả dùng được không, bao nhiêu phát hiện theo mức,
phát hiện nặng nhất là gì>

## Phát hiện

| # | Mức | Vấn đề | Lớp | File cần sửa | Hai bản |
|---|---|---|---|---|---|

(`Hai bản`: `A+B` cùng thấy · `A` hoặc `B` chỉ một bên thấy)

### <mỗi phát hiện một mục: triệu chứng · bằng chứng đã verify · đề xuất cụ thể>

## Đã bác bỏ
<phát hiện không qua được Lệnh kiểm — kèm lệnh và output thật. Mục này giữ cho lượt
retro sau không đề xuất lại>

## Chưa kiểm được
<nghi ngờ không dựng được lệnh — ghi rõ cần gì để kiểm>

## Đã cân nhắc, KHÔNG sửa
<thứ trông như lỗi nhưng đang chạy đúng thiết kế, kèm lý do>
```

Rồi báo tôi bằng tiếng Việt:
1. Đường dẫn file báo cáo
2. Số phát hiện theo mức, và **bao nhiêu cái cả hai bản cùng thấy**
3. Phát hiện mức **High** — nêu thẳng từng cái, đây là thứ tôi cần nhìn trước tiên
4. Số phát hiện **bị bác bỏ** ở cổng verify (0 thì nói rõ là 0 — đó là tín hiệu tốt về
   chất lượng hai bản, không phải chuyện bỏ qua)
5. Khối tổng kết đầu vào: tôi xác nhận gì, bạn tự quyết gì, còn treo gì

**KẾT THÚC ở đây.** Không sửa `.claude/`, không commit, không tạo PR — sửa harness là
lượt làm việc riêng, có review riêng. Báo cáo đã xếp hạng sẵn để bắt đầu lượt đó.

## Ranh giới

- KHÔNG sửa harness, KHÔNG commit, KHÔNG tạo PR.
- KHÔNG chạy lại test, KHÔNG gọi MCP Playwright.
- KHÔNG ghi đè artifact của lượt chạy (`.xlsx`, checklist, spec `.ts`).
- KHÔNG tạo bug ClickUp.

## Ghi trạng thái (bắt buộc — để `/qa-status` và resume dùng được)

**Ngay trước khi gọi agent:**
```bash
bash .claude/scripts/qa-state.sh set $1 retro in_progress "rà lượt chạy, 2 bản review"
```

**Ngay sau khi hai agent kết thúc**, kể cả khi hỏng — command vẫn sống sau agent, nên
đây là chỗ duy nhất ghi được cả trường hợp thất bại:
```bash
bash .claude/scripts/qa-state.sh set $1 retro done   "<n phát hiện: x High, y Medium, z Low; b bị bác>"
bash .claude/scripts/qa-state.sh set $1 retro failed "<lý do dừng>"
```

Journal này là **nhật ký, không phải nguồn chân lý** — artifact trên đĩa mới là sự thật.
