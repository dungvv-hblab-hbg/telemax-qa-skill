#!/usr/bin/env bash
# qa-state.sh — Trạng thái từng chặng của một ticket, để resume được.
#
#   bash .claude/scripts/qa-state.sh set  <ticket> <chặng> <trạng thái> ["ghi chú"]
#   bash .claude/scripts/qa-state.sh get  <ticket>
#   bash .claude/scripts/qa-state.sh list
#
# Chặng:      analyze · apply-feedback · write-cases · run · file-bugs · verify-prod · retro
#             (retro đứng cuối: nó rà lại các chặng trước, không chặn chặng nào)
# Trạng thái: in_progress · done · failed · skipped
#
# File: .qa/<ticket>/state.json  (mỗi ticket một thư mục, đã có sẵn quy ước đó)
#
# ─────────────────────────────────────────────────────────────────────────────
# ĐÂY LÀ NHẬT KÝ, KHÔNG PHẢI NGUỒN CHÂN LÝ.
#
# Artifact trên đĩa mới là sự thật. `state.json` chỉ ghi lại "chặng nào đã chạy,
# lúc nào, kết quả ra sao" — nó KHÔNG chứng minh file còn tồn tại. Người dùng xoá
# tay một file .xlsx thì journal vẫn nói "done".
#
# Nên `get` và `list` LUÔN dò artifact thật rồi trả cả hai, để /qa-status đối chiếu
# và báo khi lệch. Đừng bao giờ quyết định dựa trên journal mà không nhìn artifact.
# ─────────────────────────────────────────────────────────────────────────────
#
# `.qa/` đã gitignore → trạng thái là CỤC BỘ THEO MÁY, không chia sẻ giữa người.
# Đúng cho working state; đừng dùng nó làm nơi báo cáo tiến độ cho team.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="${1:-}"

STAGES="analyze apply-feedback write-cases run file-bugs verify-prod retro"
STATUSES="in_progress done failed skipped"

usage() {
  sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

# Dò artifact thật của một ticket. In ra JSON object.
probe() {
  local t="$1" d="$ROOT/.qa/$1"
  python3 - "$d" "$t" <<'PY'
import json, os, sys, glob
d, t = sys.argv[1], sys.argv[2]
g = lambda p: sorted(glob.glob(os.path.join(d, p)))
print(json.dumps({
    "analysis_spec":  bool(g("analysis-spec.md")),
    "analysis_code":  bool(g("analysis-code.md")),
    "analysis_ui":    bool(g("analysis-ui.md")),
    "checklist":      bool(g(f"checklist_{t}.md")),
    "findings":       bool(g(f"findings_{t}.md")),
    "spec_draft":     bool(g(f"spec-draft_{t}.md")),
    "spec_signed":    bool(g(f"spec-signed_{t}.md")),
    "testcase_xlsx":  [os.path.basename(x) for x in g("*.xlsx")],
    "bugs_proposed":  bool(g("bugs-proposed.json")),
    "phase1_shots":   len(g("phase1/*.png")),
    "prod_reports":   [os.path.basename(x) for x in g("prod-verify-*.md")],
    "progress_log":   bool(g("progress.log")),
}, ensure_ascii=False))
PY
}

case "$CMD" in
  set)
    TICKET="${2:-}"; STAGE="${3:-}"; STATUS="${4:-}"; NOTE="${5:-}"
    [ -n "$TICKET" ] && [ -n "$STAGE" ] && [ -n "$STATUS" ] || usage
    grep -qw -- "$STAGE"  <<<"$STAGES"   || { echo "Chặng không hợp lệ: $STAGE (hợp lệ: $STAGES)" >&2; exit 2; }
    grep -qw -- "$STATUS" <<<"$STATUSES" || { echo "Trạng thái không hợp lệ: $STATUS (hợp lệ: $STATUSES)" >&2; exit 2; }

    DIR="$ROOT/.qa/$TICKET"
    mkdir -p "$DIR" 2>/dev/null || true
    python3 - "$DIR/state.json" "$TICKET" "$STAGE" "$STATUS" "$NOTE" <<'PY'
import json, os, sys, tempfile, datetime
path, ticket, stage, status, note = sys.argv[1:6]
STAGES = ["analyze", "apply-feedback", "write-cases", "run", "file-bugs", "verify-prod", "retro"]

data = {"ticket": ticket, "stages": {}}
if os.path.exists(path):
    try:
        data = json.load(open(path, encoding="utf-8"))
    except Exception:
        # File hỏng thì dựng lại, đừng chết — journal không được phép chặn công việc.
        data = {"ticket": ticket, "stages": {}, "recovered_from_corrupt": True}
data.setdefault("ticket", ticket)
data.setdefault("stages", {})

now = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
e = data["stages"].setdefault(stage, {})
e["status"] = status
e["at"] = now
if note:
    e["note"] = note
if status == "in_progress":
    e["started_at"] = now
data["updated"] = now
data["last_stage"] = stage
data["stage_order"] = STAGES

# Ghi nguyên tử: tmp cùng thư mục rồi replace. Đứt điện giữa chừng vẫn còn bản cũ
# nguyên vẹn, thay vì một file JSON cụt.
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".", suffix=".tmp")
with os.fdopen(fd, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
print(f"{ticket} · {stage} · {status}" + (f" · {note}" if note else ""))
PY
    ;;

  get)
    TICKET="${2:-}"; [ -n "$TICKET" ] || usage
    SJ="$ROOT/.qa/$TICKET/state.json"
    ART="$(probe "$TICKET")"
    python3 - "$SJ" "$TICKET" "$ART" <<'PY'
import json, os, sys
sj, ticket, art = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
state = {}
if os.path.exists(sj):
    try:
        state = json.load(open(sj, encoding="utf-8"))
    except Exception:
        state = {"_error": "state.json hỏng, không parse được"}
print(json.dumps({"ticket": ticket, "state": state, "artifacts": art},
                 ensure_ascii=False, indent=2))
PY
    ;;

  list)
    QA="$ROOT/.qa"
    if [ ! -d "$QA" ]; then
      echo '{"tickets": [], "note": "chưa có thư mục .qa/ — chưa chạy ticket nào"}'
      exit 0
    fi
    # Đưa qua FILE TẠM, không qua stdin: `python3 - <<PY` đã dùng stdin để nạp chính
    # script, nên pipe vào đó thì `sys.stdin.read()` trả rỗng và list luôn ra 0 ticket.
    TMP="$(mktemp)"
    trap 'rm -f "$TMP"' EXIT
    for d in "$QA"/*/; do
      [ -d "$d" ] || continue
      t="$(basename "$d")"
      printf '%s\t%s\n' "$t" "$(probe "$t")" >> "$TMP"
    done
    python3 - "$QA" "$TMP" <<'PY'
import json, os, sys
qa, tmp = sys.argv[1], sys.argv[2]
rows = []
for line in open(tmp, encoding="utf-8").read().splitlines():
    if not line.strip():
        continue
    t, art = line.split("\t", 1)
    sj = os.path.join(qa, t, "state.json")
    st = {}
    if os.path.exists(sj):
        try:
            st = json.load(open(sj, encoding="utf-8"))
        except Exception:
            st = {"_error": "state.json hỏng"}
    rows.append({"ticket": t, "updated": st.get("updated"),
                 "last_stage": st.get("last_stage"),
                 "stages": st.get("stages", {}), "artifacts": json.loads(art)})
rows.sort(key=lambda r: (r["updated"] or ""), reverse=True)
print(json.dumps({"tickets": rows, "count": len(rows)}, ensure_ascii=False, indent=2))
PY
    ;;

  *) usage ;;
esac
