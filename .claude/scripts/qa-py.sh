#!/usr/bin/env bash
# qa-py.sh — Chạy script Python của harness bằng ĐÚNG interpreter có openpyxl.
#
#   bash .claude/scripts/qa-py.sh <đường-dẫn-script.py> [tham số...]
#
# Ví dụ:
#   bash .claude/scripts/qa-py.sh .claude/skills/testcase-template/scripts/build.py \
#        --input cases.json --template <template> --output <out.xlsx>
#
# Vì sao cần: `pip install openpyxl` THẤT BẠI trên macOS (Homebrew) và Ubuntu 23+ với
# `externally-managed-environment` (PEP 668). Không có điểm phân giải chung thì mỗi
# session tự xoay một kiểu — đã từng dẫn tới hai venv lạc (`.qa/.venv`, `~/.qa-venv`)
# mà session sau không biết đường tìm.
#
# Thứ tự ưu tiên:
#   1. .claude/.venv/bin/python          (venv chuẩn của harness, do /qa-setup tạo)
#   2. $QA_PYTHON                        (người dùng chỉ định thủ công)
#   3. python3 hệ thống, NẾU import được openpyxl
#   4. thất bại, in đúng ba cách cài
#
# Exit code: giữ nguyên exit code của script Python (build.py dùng 0/1/2 làm tín hiệu,
# không được nuốt).

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENV_PY="$ROOT/.claude/.venv/bin/python"

if [ $# -lt 1 ]; then
  echo "Cách dùng: bash .claude/scripts/qa-py.sh <script.py> [tham số...]" >&2
  exit 2
fi

pick() {
  # 1. venv chuẩn
  if [ -x "$VENV_PY" ] && "$VENV_PY" -c "import openpyxl" 2>/dev/null; then
    echo "$VENV_PY"; return 0
  fi
  # 2. người dùng chỉ định
  if [ -n "${QA_PYTHON:-}" ] && "$QA_PYTHON" -c "import openpyxl" 2>/dev/null; then
    echo "$QA_PYTHON"; return 0
  fi
  # 2b. venv cũ ở .qa/.venv — một số repo đã dựng trước khi có quy ước .claude/.venv.
  #     Nhận để không bắt dựng lại, nhưng .qa/ là thư mục KẾT QUẢ theo ticket: dọn .qa/
  #     là mất venv. Nên chuyển sang .claude/.venv khi tiện.
  if [ -x "$ROOT/.qa/.venv/bin/python" ] && "$ROOT/.qa/.venv/bin/python" -c "import openpyxl" 2>/dev/null; then
    echo "$ROOT/.qa/.venv/bin/python"; return 0
  fi
  # 3. python3 hệ thống — chỉ nhận khi thực sự có openpyxl
  if command -v python3 >/dev/null && python3 -c "import openpyxl" 2>/dev/null; then
    command -v python3; return 0
  fi
  return 1
}

PY="$(pick)" || {
  cat >&2 <<'MSG'
Không tìm thấy Python nào có openpyxl.

Cách chuẩn của harness (chạy một lần, /qa-setup cũng làm bước này):

    python3 -m venv .claude/.venv
    .claude/.venv/bin/python -m pip install openpyxl

Hai cách thay thế:
    export QA_PYTHON=/đường/dẫn/python      # nếu bạn đã có venv riêng
    python3 -m pip install --break-system-packages openpyxl

Đừng chạy `pip install openpyxl` trần: trên macOS (Homebrew) và Ubuntu 23+ nó thất bại
với `externally-managed-environment` (PEP 668). Cũng đừng tự dựng venv ở chỗ khác —
session sau sẽ không biết đường tìm.
MSG
  exit 1
}

exec "$PY" "$@"
