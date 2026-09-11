#!/usr/bin/env bash
# install.sh — Cài harness QA vào một repo đích.
#
#   ./install.sh /đường/dẫn/repo-dich
#   ./install.sh /đường/dẫn/repo-dich --dry-run     # chỉ in ra sẽ làm gì
#   ./install.sh /đường/dẫn/repo-dich --force       # ghi đè .claude/ đang có
#   ./install.sh /đường/dẫn/repo-dich --with-e2e    # copy luôn telemax-e2e/ (xem dưới)
#
# Copy: .claude/  ·  .mcp.json
# KHÔNG copy project e2e (mặc định) — /qa-setup dò repo đích rồi hỏi. --with-e2e để
# copy nguyên bản Telemax, chỉ đúng khi repo đích là app Telemax cùng form login.
# Append: gitignore.snippet vào .gitignore của repo đích (bỏ qua nếu đã có)
#
# KHÔNG copy: evals/, docs/, CHANGELOG.md — tài liệu, không cần trong repo đích.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"
DRY=0; FORCE=0; WITH_E2E=0
for a in "${@:2}"; do
  case "$a" in
    --dry-run)  DRY=1 ;;
    --force)    FORCE=1 ;;
    --with-e2e) WITH_E2E=1 ;;
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
# settings.local.json là cấu hình riêng của MÁY người cài (plugin đang bật, server MCP
# đã duyệt). Copy sang là ép nó cho người khác, và repo đích chưa chắc gitignore nó.
run "rm -f '$TARGET/.claude/settings.local.json'"
say ".claude/ -> đã copy (bỏ settings.local.json)"

# ── .mcp.json ────────────────────────────────────────────────────────────
if [ -f "$TARGET/.mcp.json" ]; then
  say ".mcp.json ĐÃ CÓ — không đụng. Merge tay entry 'playwright' từ:"
  say "  $SRC/.mcp.json"
  say "  (giữ đủ --user-data-dir, --output-dir, --timeout-action 30000)"
else
  run "cp '$SRC/.mcp.json' '$TARGET/.mcp.json'"
  say ".mcp.json -> đã copy"
fi

# ── project e2e ──────────────────────────────────────────────────────────
# MẶC ĐỊNH KHÔNG COPY. Project e2e phụ thuộc app thật — URL, form đăng nhập, tên
# biến môi trường, dữ liệu mẫu. Bê nguyên project của app khác sang thì mọi selector
# đều sai và `npm run check` đỏ ngay từ phút đầu, mà người mới cài không biết vì sao.
#
# /qa-setup sẽ dò repo đích rồi hỏi, và đi một trong ba nhánh (skill e2e-scaffold):
#   A. repo đã có Playwright  -> vá config sẵn có cho đủ hàng rào, không dựng thêm
#   B. chưa có, là app web    -> scaffold theo app thật của repo đó
#   C. không phải app web     -> bỏ nhánh UI, qa-config ghi Trạng thái KHÔNG DÙNG
#
# --with-e2e để copy nguyên bản Telemax: chỉ đúng khi repo đích là một app Telemax
# khác, cùng form đăng nhập.
if [ "$WITH_E2E" = 1 ]; then
  if [ -d "$TARGET/telemax-e2e" ]; then
    say "telemax-e2e/ ĐÃ CÓ — không đụng."
  else
    run "cp -R '$SRC/telemax-e2e' '$TARGET/telemax-e2e'"
    run "rm -rf '$TARGET/telemax-e2e/node_modules' '$TARGET/telemax-e2e/.env'"
    say "telemax-e2e/ -> đã copy (--with-e2e)"
    say "  Chỉ đúng nếu repo đích là app Telemax cùng form đăng nhập."
  fi
else
  say "project e2e -> BỎ QUA (mặc định). /qa-setup sẽ dò repo rồi hỏi bạn."
  say "  Repo đích là app Telemax khác, cùng form login? Chạy lại với --with-e2e."
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
echo "  1. Mở Claude Code trong '$TARGET' rồi chạy:  /qa-setup"
echo "     Nó soát Python+openpyxl, chromium, MCP, LibreOffice, xin duyệt trước khi cài,"
echo "     và DỰNG PROJECT E2E theo repo này (dò trước, hỏi bạn, rồi mới làm)."
echo
echo "  2. Sau khi /qa-setup dựng xong project e2e: cp <project>/.env.example <project>/.env"
echo "     rồi điền URL + tài khoản test."
echo
echo "  3. Điền .claude/qa-config.md — list/space ClickUp chứa bug (còn CHƯA ĐIỀN)."
echo
echo "  4. Kiểm nhanh:  bash .claude/scripts/smoke-scripts.sh"
echo
echo "  Sửa .mcp.json xong PHẢI thoát Claude Code và mở lại — MCP đọc args lúc khởi động."
