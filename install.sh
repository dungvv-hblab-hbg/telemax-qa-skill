#!/usr/bin/env bash
# install.sh — Cài harness QA vào một repo đích.
#
#   ./install.sh /đường/dẫn/repo-dich
#   ./install.sh /đường/dẫn/repo-dich --dry-run     # chỉ in ra sẽ làm gì
#   ./install.sh /đường/dẫn/repo-dich --force       # ghi đè .claude/ đang có
#
# Copy: .claude/  ·  .mcp.json  ·  telemax-e2e/
# Append: gitignore.snippet vào .gitignore của repo đích (bỏ qua nếu đã có)
#
# KHÔNG copy: evals/, docs/, CHANGELOG.md — tài liệu, không cần trong repo đích.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"
DRY=0; FORCE=0
for a in "${@:2}"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --force)   FORCE=1 ;;
    *) echo "Tham số không hiểu: $a" >&2; exit 2 ;;
  esac
done

if [ -z "$TARGET" ]; then
  sed -n '2,12p' "$SRC/install.sh" | sed 's/^# \{0,1\}//'
  exit 2
fi
[ -d "$TARGET" ] || { echo "Không thấy thư mục: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"
[ "$TARGET" != "$SRC" ] || { echo "Repo đích trùng với repo harness." >&2; exit 1; }

say()  { echo "  $*"; }
run()  { if [ "$DRY" = 1 ]; then say "[dry-run] $*"; else eval "$@"; fi; }

echo "Cài harness QA"
say "từ:  $SRC"
say "vào: $TARGET"
[ -d "$TARGET/.git" ] || say "CẢNH BÁO: $TARGET không phải repo git."
echo

# ── .claude/ ─────────────────────────────────────────────────────────────
if [ -d "$TARGET/.claude" ] && [ "$FORCE" != 1 ]; then
  echo "ĐÃ CÓ $TARGET/.claude — không ghi đè." >&2
  echo "Repo đích đã dùng Claude Code thì merge tay: copy .claude/{skills,agents,commands,scripts}," >&2
  echo "và .claude/qa-config.md. Hoặc chạy lại với --force nếu chắc chắn muốn ghi đè." >&2
  exit 1
fi
run "mkdir -p '$TARGET/.claude'"
run "cp -R '$SRC/.claude/.' '$TARGET/.claude/'"
say ".claude/ -> đã copy"

# ── .mcp.json ────────────────────────────────────────────────────────────
if [ -f "$TARGET/.mcp.json" ]; then
  say ".mcp.json ĐÃ CÓ — không đụng. Merge tay entry 'playwright' từ:"
  say "  $SRC/.mcp.json"
  say "  (giữ đủ --user-data-dir, --output-dir, --timeout-action 30000)"
else
  run "cp '$SRC/.mcp.json' '$TARGET/.mcp.json'"
  say ".mcp.json -> đã copy"
fi

# ── telemax-e2e/ ─────────────────────────────────────────────────────────
if [ -d "$TARGET/telemax-e2e" ]; then
  say "telemax-e2e/ ĐÃ CÓ — không đụng."
else
  run "cp -R '$SRC/telemax-e2e' '$TARGET/telemax-e2e'"
  run "rm -rf '$TARGET/telemax-e2e/node_modules' '$TARGET/telemax-e2e/.env'"
  say "telemax-e2e/ -> đã copy"
fi

# ── .gitignore ───────────────────────────────────────────────────────────
GI="$TARGET/.gitignore"
if [ -f "$GI" ] && grep -q "playwright-mcp-profile" "$GI" 2>/dev/null; then
  say ".gitignore đã có pattern của harness — bỏ qua"
else
  if [ "$DRY" = 1 ]; then
    say "[dry-run] append gitignore.snippet vào $GI"
  else
    { [ -f "$GI" ] && echo ""; cat "$SRC/gitignore.snippet"; } >> "$GI"
  fi
  say ".gitignore -> đã append"
fi

echo
echo "Xong. Bốn việc tiếp theo, theo thứ tự:"
echo
echo "  1. cd '$TARGET' && cp telemax-e2e/.env.example telemax-e2e/.env"
echo "     rồi điền BASE_URL / TELEMAX_USER / TELEMAX_PASS"
echo
echo "  2. Mở Claude Code trong '$TARGET' rồi chạy:  /qa-setup"
echo "     Nó soát Python+openpyxl, chromium, MCP, LibreOffice và xin duyệt trước khi cài."
echo
echo "  3. Điền .claude/qa-config.md — list/space ClickUp chứa bug (còn CHƯA ĐIỀN)."
echo
echo "  4. Kiểm nhanh:  bash .claude/scripts/smoke-scripts.sh"
echo
echo "  Sửa .mcp.json xong PHẢI thoát Claude Code và mở lại — MCP đọc args lúc khởi động."
