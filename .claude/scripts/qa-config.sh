#!/usr/bin/env bash
# qa-config.sh — In ra ĐÚNG MỘT mục của .claude/qa-config.md.
#
#   bash .claude/scripts/qa-config.sh <mục>
#
# Mục hợp lệ: ticket · clickup · playwright · production · postman · all
#
# Vì sao cần: qa-config.md là điểm khai báo duy nhất nên nó dài, và mọi chặng đều
# trỏ tới nó. Đọc nguyên file để lấy một bảng là trả tiền cho bốn bảng không dùng —
# riêng mục Playwright đã chiếm hơn nửa file và chẳng liên quan gì tới /qa-file-bugs.
#
# Giữ MỘT file (không tách thành năm) là có chủ đích: tách ra là mở đường cho hai
# bản trôi lệch nhau, đúng thứ mà "điểm khai báo duy nhất" đang phòng.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CFG="$ROOT/.claude/qa-config.md"

[ -f "$CFG" ] || { echo "Không thấy $CFG" >&2; exit 1; }

case "${1:-}" in
  ticket)     H='^## Ticket & môi trường' ;;
  clickup)    H='^## ClickUp' ;;
  playwright) H='^## Playwright' ;;
  production) H='^## Production' ;;
  postman)    H='^## Postman' ;;
  all)        cat "$CFG"; exit 0 ;;
  *)
    echo "Dùng: bash .claude/scripts/qa-config.sh <ticket|clickup|playwright|production|postman|all>" >&2
    echo "Các mục có trong file:" >&2
    grep -n '^## ' "$CFG" >&2
    exit 2 ;;
esac

# In từ heading tới ngay trước heading `## ` kế tiếp.
awk -v h="$H" '
  $0 ~ h        { inside=1 }
  inside && /^## / && $0 !~ h { exit }
  inside        { print }
' "$CFG"
