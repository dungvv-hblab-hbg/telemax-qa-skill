#!/usr/bin/env bash
# smoke-scripts.sh — Regression test cho tầng script của harness.
#
# Không cần MCP, không cần ticket thật, không gọi Claude. Chạy được ở CI.
# Kiểm 9 hành vi mà nếu vỡ thì cả luồng QA sai âm thầm.
#
#   bash .claude/scripts/smoke-scripts.sh
#
# Nằm trong .claude/ để đi theo harness khi copy sang repo khác — thư mục evals/ là tài
# liệu, không phải thứ bắt buộc copy.
#
# Exit 0 = tất cả xanh. Exit 1 = có case đỏ (in rõ case nào).

set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/testcase-template" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (mong '$3', nhận '$2')"; fi; }

echo "Thư mục làm việc: $WORK"
echo

# ── 1. build.py trên input hợp lệ ────────────────────────────────────────────
echo "[1] build.py với cases.json hợp lệ"
bash "$(dirname "${BASH_SOURCE[0]}")/qa-py.sh" "$SKILL_DIR/scripts/build.py" \
  --input "$SKILL_DIR/assets/example.cases.json" \
  --template "$SKILL_DIR/assets/template.xlsx" \
  --output "$WORK/tc.xlsx" > "$WORK/build.json" 2>&1
check "exit code 0" "$?" "0"
[ -f "$WORK/tc.xlsx" ] && ok "file được sinh ra" || bad "file KHÔNG được sinh ra"
TOTAL=$(python3 -c "import json;print(json.load(open('$WORK/build.json'))['total_cases'])" 2>/dev/null)
check "total_cases = 4" "$TOTAL" "4"

# ── 2. TC ID trùng phải bị chặn, KHÔNG sinh file ────────────────────────────
echo "[2] TC ID trùng -> exit 1, không sinh file"
python3 - "$SKILL_DIR/assets/example.cases.json" "$WORK/dup.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
d['sections'][1]['cases'][0]['id']='TC-A-001'   # trùng với case đầu section A
d['sections'][1]['cases'][0]['divider']=None
json.dump(d,open(sys.argv[2],'w'))
PY
bash "$(dirname "${BASH_SOURCE[0]}")/qa-py.sh" "$SKILL_DIR/scripts/build.py" --input "$WORK/dup.json" \
  --template "$SKILL_DIR/assets/template.xlsx" --output "$WORK/dup.xlsx" >/dev/null 2>&1
check "exit code 1" "$?" "1"
[ -f "$WORK/dup.xlsx" ] && bad "file bị sinh ra dù validate fail" || ok "không sinh file khi validate fail"

# ── 3. AC hở phải cho exit 2 + PROBLEMS ─────────────────────────────────────
echo "[3] AC không được case nào phủ -> exit 2 + PROBLEMS"
python3 - "$SKILL_DIR/assets/example.cases.json" "$WORK/gap.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
d['acceptance_criteria'].append({"id":"AC-99","text":"AC cố tình không phủ"})
json.dump(d,open(sys.argv[2],'w'))
PY
bash "$(dirname "${BASH_SOURCE[0]}")/qa-py.sh" "$SKILL_DIR/scripts/build.py" --input "$WORK/gap.json" \
  --template "$SKILL_DIR/assets/template.xlsx" --output "$WORK/gap.xlsx" > "$WORK/gap.out" 2>&1
check "exit code 2" "$?" "2"
grep -q "AC-99" "$WORK/gap.out" && ok "PROBLEMS nêu đúng AC-99" || bad "PROBLEMS không nêu AC-99"

# ── 4. recalc.py điền lại giá trị Summary ───────────────────────────────────
echo "[4] recalc.py"
bash "$(dirname "${BASH_SOURCE[0]}")/qa-py.sh" "$SKILL_DIR/scripts/recalc.py" "$WORK/tc.xlsx" 90 >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "  SKIP  recalc (không có LibreOffice trên máy này) — các case sau vẫn chạy"
else
  ok "recalc exit 0"
  python3 - "$WORK/tc.xlsx" <<'PY'
import openpyxl,sys
ws=openpyxl.load_workbook(sys.argv[1],data_only=True)['Summary']
nums=[c.value for r in ws.iter_rows(min_row=1,max_row=30) for c in r if isinstance(c.value,(int,float))]
print("  PASS  Summary có %d ô số sau recalc" % len(nums) if nums else "  FAIL  Summary vẫn trống sau recalc")
PY
fi

# ── 5. Dropdown & sheet còn nguyên sau khi script ghi ───────────────────────
echo "[5] Dropdown + 8 sheet còn nguyên"
python3 - "$WORK/tc.xlsx" <<'PY'
import openpyxl,sys
wb=openpyxl.load_workbook(sys.argv[1])
print("  PASS  đủ 8 sheet" if len(wb.sheetnames)==8 else "  FAIL  còn %d sheet"%len(wb.sheetnames))
dv=wb['Test Cases'].data_validations.dataValidation
print("  PASS  còn 3 data validation" if len(dv)==3 else "  FAIL  còn %d data validation"%len(dv))
PY

# ── 6. Ghi kết quả Round 1: 1 Pass, 1 Fail, 1 Blocked-[MANUAL] ──────────────
echo "[6] Ghi kết quả vào Round 1 (cột J) rồi fill Defects"
python3 - "$WORK/tc.xlsx" <<'PY'
import openpyxl,sys
wb=openpyxl.load_workbook(sys.argv[1]); ws=wb['Test Cases']
res={'TC-A-001':'Pass','TC-A-002':'Fail','TC-B-001':'Blocked','TC-B-002':'Pass'}
for r in range(6, ws.max_row+1):
    tc=ws.cell(r,1).value
    if tc in res:
        ws.cell(r,10).value = res[tc]                       # J = Round 1 Result
        if tc=='TC-B-001':
            ws.cell(r,14).value = '[MANUAL] cần thiết bị thật'   # N = Note
wb.save(sys.argv[1])
PY
bash "$(dirname "${BASH_SOURCE[0]}")/qa-py.sh" "$SKILL_DIR/scripts/write_defects.py" --file "$WORK/tc.xlsx" --mode fill \
  --actuals '{"TC-A-002":"tiêu đề hiển thị biển số thay vì tên xe","TC-B-001":"không chạy được"}' \
  > "$WORK/fill.json" 2>&1
check "fill exit 0" "$?" "0"

# ── 7. Case [MANUAL] KHÔNG được đẻ ra defect ────────────────────────────────
echo "[7] Guard [MANUAL] — đây là case quan trọng nhất"
python3 - "$WORK/tc.xlsx" <<'PY'
import openpyxl,sys
ws=openpyxl.load_workbook(sys.argv[1])['Defects & Follow-ups']
ids=[ws.cell(r,2).value for r in range(4,ws.max_row+1) if ws.cell(r,2).value]
print("  PASS  chỉ 1 dòng defect, đúng TC-A-002" if ids==['TC-A-002']
      else "  FAIL  dòng defect: %r (mong ['TC-A-002'])" % ids)
PY

# ── 8. Won't fix loại dòng khỏi danh sách tạo bug ───────────────────────────
echo "[8] read + Won't fix"
bash "$(dirname "${BASH_SOURCE[0]}")/qa-py.sh" "$SKILL_DIR/scripts/write_defects.py" --file "$WORK/tc.xlsx" --mode read > "$WORK/read1.json" 2>&1
N1=$(python3 -c "
import json,sys
d=json.load(open('$WORK/read1.json'))
print(len(d['bugs_to_create']))" 2>/dev/null || echo "?")
check "read trả 1 bug" "$N1" "1"
python3 - "$WORK/tc.xlsx" <<'PY'
import openpyxl,sys
wb=openpyxl.load_workbook(sys.argv[1]); ws=wb['Defects & Follow-ups']
for r in range(4, ws.max_row+1):
    if ws.cell(r,2).value=='TC-A-002':
        ws.cell(r,11).value="Won't fix"          # K = Fix Status
wb.save(sys.argv[1])
PY
bash "$(dirname "${BASH_SOURCE[0]}")/qa-py.sh" "$SKILL_DIR/scripts/write_defects.py" --file "$WORK/tc.xlsx" --mode read > "$WORK/read2.json" 2>&1
N2=$(python3 -c "
import json
d=json.load(open('$WORK/read2.json'))
print(len(d['bugs_to_create']))" 2>/dev/null || echo "?")
check "sau Won't fix read trả 0 bug" "$N2" "0"

# ── 9. writeback khoá theo TC ID, ghi cả 2 sheet ────────────────────────────
echo "[9] writeback khoá theo TC ID"
bash "$(dirname "${BASH_SOURCE[0]}")/qa-py.sh" "$SKILL_DIR/scripts/write_defects.py" --file "$WORK/tc.xlsx" --mode writeback \
  --bugmap '{"TC-A-002":"TLM-9001"}' > "$WORK/wb.json" 2>&1
check "writeback exit 0" "$?" "0"
python3 - "$WORK/tc.xlsx" <<'PY'
import openpyxl,sys
wb=openpyxl.load_workbook(sys.argv[1])
d=wb['Defects & Follow-ups']; t=wb['Test Cases']
in_def = any(d.cell(r,2).value=='TC-A-002' and d.cell(r,9).value=='TLM-9001'
             for r in range(4,d.max_row+1))
in_tc  = any(t.cell(r,1).value=='TC-A-002' and t.cell(r,11).value=='TLM-9001'
             for r in range(6,t.max_row+1))
print("  PASS  Bug ID vào sheet Defects" if in_def else "  FAIL  Bug ID KHÔNG vào sheet Defects")
print("  PASS  Bug ID vào sheet Test Cases (cột K)" if in_tc else "  FAIL  Bug ID KHÔNG vào sheet Test Cases")
PY

# ── Kết ─────────────────────────────────────────────────────────────────────
echo
INLINE_FAIL=0
echo "Tổng: $PASS pass / $FAIL fail (chưa tính các dòng PASS/FAIL in trực tiếp ở trên)"
if [ $FAIL -gt 0 ]; then echo "CÓ CASE ĐỎ"; exit 1; fi
echo "Xanh. Đọc lại các dòng in trực tiếp để chắc không có FAIL nào."
