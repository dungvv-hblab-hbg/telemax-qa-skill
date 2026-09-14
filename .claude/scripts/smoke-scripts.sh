#!/usr/bin/env bash
# smoke-scripts.sh — Regression test cho tầng script của harness.
#
# Không cần MCP, không cần ticket thật, không gọi Claude. Chạy được ở CI.
# Kiểm 12 nhóm hành vi mà nếu vỡ thì cả luồng QA sai âm thầm.
#
#   bash .claude/scripts/smoke-scripts.sh
#
# Nằm trong .claude/ để đi theo harness khi copy sang repo khác — thư mục evals/ là tài
# liệu, không phải thứ bắt buộc copy.
#
# Exit 0 = tất cả xanh. Exit 1 = có case đỏ (in rõ case nào).

set -uo pipefail

# Phần lớn assertion nằm trong heredoc Python và chỉ in "  FAIL ..." — chúng không
# cộng vào $FAIL nên trước đây CI xanh dù hàng rào đã thủng. Chạy lại chính mình một
# lần, tee ra log, rồi soi log: tiến trình con đã thoát hẳn nên không có race.
if [ -z "${SMOKE_TEED:-}" ]; then
  _log="$(mktemp)"
  SMOKE_TEED=1 bash "$0" "$@" 2>&1 | tee "$_log"
  _rc=${PIPESTATUS[0]}
  if grep -q '^  FAIL' "$_log"; then
    echo "CÓ DÒNG FAIL IN TRỰC TIẾP (xem ở trên) — $(grep -c '^  FAIL' "$_log") dòng"
    _rc=1
  fi
  rm -f "$_log"
  exit $_rc
fi

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

# ── 3b. sheet Assumptions & Questions ───────────────────────────────────────
echo "[3b] assumptions -> sheet Assumptions & Questions"
python3 - "$SKILL_DIR/assets/example.cases.json" "$WORK/assum.json" "$WORK/dang.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
# case trỏ [GĐ #72] VÀ trích D2 #17 — chỉ cái đầu là tham chiếu giả định
d['sections'][0]['cases'][0]['note']='Expected theo [GĐ #72]; message lấy từ D2 #17'
json.dump(d,open(sys.argv[3],'w'))                       # dangling: chưa có assumptions
d['assumptions']=[{"ref":"#72","topic":"Report Period format",
                   "assumption":"12-hour with AM/PM","answer":"confirmed by reviewer",
                   "date_closed":"2026-09-14"}]
json.dump(d,open(sys.argv[2],'w'))                       # đủ dòng -> phải sạch
PY
bash "$(dirname "${BASH_SOURCE[0]}")/qa-py.sh" "$SKILL_DIR/scripts/build.py" --input "$WORK/dang.json" \
  --template "$SKILL_DIR/assets/template.xlsx" --output "$WORK/dang.xlsx" > "$WORK/dang.out" 2>&1
check "[GĐ #NN] không có dòng -> exit 2" "$?" "2"
grep -q "#72" "$WORK/dang.out" && ok "PROBLEMS nêu đúng #72" || bad "PROBLEMS không nêu #72"
grep -q "#17" "$WORK/dang.out" && bad "báo nhầm D2 #17 (quét #NN trần)" || ok "không báo nhầm D2 #17"

bash "$(dirname "${BASH_SOURCE[0]}")/qa-py.sh" "$SKILL_DIR/scripts/build.py" --input "$WORK/assum.json" \
  --template "$SKILL_DIR/assets/template.xlsx" --output "$WORK/assum.xlsx" > "$WORK/assum.out" 2>&1
check "có đủ dòng assumptions -> exit 0" "$?" "0"
python3 - "$WORK/assum.xlsx" <<'PY' && ok "sheet Assumptions ghi đúng row 4" || bad "sheet Assumptions KHÔNG có data"
import sys,openpyxl
ws=openpyxl.load_workbook(sys.argv[1])['Assumptions & Questions']
vals=[ws.cell(4,c).value for c in range(1,8)]
sys.exit(0 if vals[0]=='#72' and vals[5]=='confirmed by reviewer' else 1)
PY

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

# ── 10. --mode status: cổng /qa-run đọc số bằng MỘT lệnh ───────────────────
echo "[10] write_defects.py --mode status"
bash "$(dirname "${BASH_SOURCE[0]}")/qa-py.sh" "$SKILL_DIR/scripts/write_defects.py" \
  --file "$WORK/tc.xlsx" --mode status > "$WORK/status.json" 2>&1
check "status exit 0" "$?" "0"
python3 - "$WORK/status.json" "$WORK/tc.xlsx" <<'PY'
import json, sys, os
d = json.load(open(sys.argv[1]))
for k in ("total_cases","round1","round2","already_run","suggest_round",
          "resume_hint","defect_rows","data_req","manual","ac_missing"):
    print(f"  PASS  status có key {k}" if k in d else f"  FAIL  status THIẾU key {k}")
# Case [MANUAL] phải hiện ở nhóm manual — đây là nhãn mà /qa-run đếm trước khi chạy.
ok = any(m["count"] >= 1 for m in d["manual"])
print("  PASS  status gom được case [MANUAL]" if ok else "  FAIL  status không thấy case [MANUAL]")
# Đọc-only: không được đẻ .bak
print("  PASS  status không tạo .bak (đọc-only)" if not os.path.exists(sys.argv[2] + ".bak.status")
      else "  FAIL  status tạo backup — nó phải là đọc-only")
PY

# ── 11. --mode cases: nguồn duy nhất của test-runner ───────────────────────
echo "[11] write_defects.py --mode cases"
bash "$(dirname "${BASH_SOURCE[0]}")/qa-py.sh" "$SKILL_DIR/scripts/write_defects.py" \
  --file "$WORK/tc.xlsx" --mode cases > "$WORK/cases.json" 2>&1
check "cases exit 0" "$?" "0"
bash "$(dirname "${BASH_SOURCE[0]}")/qa-py.sh" "$SKILL_DIR/scripts/write_defects.py" \
  --file "$WORK/tc.xlsx" --mode cases --round 1 --not-run-only > "$WORK/cases_resume.json" 2>&1
check "cases --not-run-only exit 0" "$?" "0"
python3 - "$WORK/cases.json" "$WORK/cases_resume.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
# Ba cột mà load_testcases TRƯỚC ĐÂY không đọc — thiếu chúng thì test-runner phải
# tự chế script openpyxl tạm mỗi lần chạy.
need = ("type", "precondition", "data", "expected", "manual", "data_req", "r1", "r2")
missing = [k for k in need if d["cases"] and k not in d["cases"][0]]
print("  PASS  case có đủ trường cho test-runner" if not missing
      else f"  FAIL  case THIẾU trường: {missing}")
print("  PASS  có case đọc được Type" if any(c["type"] for c in d["cases"])
      else "  FAIL  không case nào đọc được Type (cột C)")
print("  PASS  nhận diện được case [MANUAL]" if any(c["manual"] for c in d["cases"])
      else "  FAIL  không nhận diện được [MANUAL]")
# RESUME phải LOẠI BỚT, không được trả nhiều hơn
r = json.load(open(sys.argv[2]))
print("  PASS  --not-run-only lọc bớt case đã có kết quả" if r["count"] < d["count"]
      else f"  FAIL  --not-run-only không lọc gì ({r['count']} vs {d['count']})")
PY

# ── 12. qa-state.sh — nhật ký trạng thái để resume ─────────────────────────
echo "[12] qa-state.sh"
SROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_SH="$(dirname "${BASH_SOURCE[0]}")/qa-state.sh"
# Chạy trong sandbox riêng để KHÔNG đụng .qa/ thật của người dùng.
SBOX="$WORK/sbox"; mkdir -p "$SBOX/.claude/scripts"
cp "$STATE_SH" "$SBOX/.claude/scripts/"
( cd "$SBOX"
  bash .claude/scripts/qa-state.sh list > l0.json 2>&1
  bash .claude/scripts/qa-state.sh set TLM-0001 analyze done "12 AC" > /dev/null 2>&1
  sleep 1
  bash .claude/scripts/qa-state.sh set TLM-0002 analyze done "cũ hơn" > /dev/null 2>&1
  bash .claude/scripts/qa-state.sh set TLM-0002 run in_progress "case 30/45" > /dev/null 2>&1
  touch .qa/TLM-0002/checklist_TLM-0002.md
  bash .claude/scripts/qa-state.sh get TLM-0002 > g.json 2>&1
  bash .claude/scripts/qa-state.sh list > l.json 2>&1
  printf '{ hỏng' > .qa/TLM-0001/state.json
  bash .claude/scripts/qa-state.sh set TLM-0001 run done "sau khi hỏng" > /dev/null 2>&1
  echo $? > corrupt_rc.txt
  bash .claude/scripts/qa-state.sh set TLM-0001 khong-ton-tai done > /dev/null 2>&1
  echo $? > badstage_rc.txt
  # chặng retro (/qa-retro) — thêm sau, dễ quên một trong hai chỗ khai STAGES
  bash .claude/scripts/qa-state.sh set TLM-0002 retro done "3 phát hiện" > /dev/null 2>&1
  echo $? > retro_rc.txt
  bash .claude/scripts/qa-state.sh get TLM-0002 > g2.json 2>&1 )
python3 - "$SBOX" <<'PY'
import json, os, sys
s = sys.argv[1]
j = lambda f: json.load(open(os.path.join(s, f), encoding="utf-8"))
def ck(ok, msg): print(("  PASS  " if ok else "  FAIL  ") + msg)

ck(j("l0.json")["tickets"] == [], "list khi chưa có .qa/ trả rỗng, không lỗi")
# Hồi quy: bản đầu dùng stdin cho cả heredoc lẫn dữ liệu -> list luôn ra 0 ticket.
ck(j("l.json")["count"] == 2, "list thấy đủ 2 ticket (hồi quy lỗi stdin/heredoc)")
ck(j("l.json")["tickets"][0]["ticket"] == "TLM-0002", "list sắp mới nhất lên đầu")
g = j("g.json")
ck(g["state"]["stages"]["run"]["status"] == "in_progress", "get đọc đúng trạng thái chặng")
ck("started_at" in g["state"]["stages"]["run"], "in_progress có started_at (để phát hiện đứt)")
# Journal và artifact PHẢI tách biệt — /qa-status dựa vào đó để bắt lệch.
ck(g["artifacts"]["checklist"] is True, "get dò được artifact thật")
ck(g["artifacts"]["testcase_xlsx"] == [], "artifact không có thì báo không có")
ck(open(os.path.join(s, "corrupt_rc.txt")).read().strip() == "0",
   "state.json hỏng vẫn set được (tự dựng lại, không chặn công việc)")
ck(open(os.path.join(s, "badstage_rc.txt")).read().strip() != "0", "chặng sai bị từ chối")
# Hai chỗ khai STAGES (bash + python trong cùng file) phải khớp nhau. Khai thiếu một
# chỗ thì `set` qua được nhưng stage_order sai, và /qa-status hiển thị lệch.
ck(open(os.path.join(s, "retro_rc.txt")).read().strip() == "0", "chặng retro được chấp nhận")
g2 = j("g2.json")
ck(g2["state"]["stages"].get("retro", {}).get("status") == "done", "retro ghi được vào state.json")
ck("retro" in g2["state"].get("stage_order", []), "retro có trong stage_order (khai đủ CẢ HAI chỗ)")
PY

# ── Kết ─────────────────────────────────────────────────────────────────────
echo
echo "Tổng (đếm bằng bash): $PASS pass / $FAIL fail — các dòng FAIL in trực tiếp được soi ở lượt ngoài"
if [ $FAIL -gt 0 ]; then echo "CÓ CASE ĐỎ"; exit 1; fi
