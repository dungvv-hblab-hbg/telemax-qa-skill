#!/usr/bin/env bash
# qa-log.sh — In tiến trình ra màn hình VÀ ghi vào .qa/<ticket>/progress.log
#
#   bash .claude/scripts/qa-log.sh <ticket> <chặng> <bước>/<tổng> "<đang làm gì>"
#
# Ví dụ:
#   bash .claude/scripts/qa-log.sh TLM-2899 qa-analyze 2/6 "lọc git diff theo ticket"
#   -> [14:32:05 +18s] TLM-2899 · qa-analyze · 2/6 · lọc git diff theo ticket
#
# Vì sao cần: subagent chạy kín, người dùng ngồi nhìn màn hình đứng yên vài phút.
# File log là kênh chắc chắn — mở terminal thứ hai và theo dõi:
#
#   tail -f .qa/TLM-2899/progress.log
#
# Log còn lại sau khi chạy xong, nên dùng được để truy lại chặng nào chậm, chặng nào
# dừng giữa chừng.

set -uo pipefail

TICKET="${1:-UNKNOWN}"
STAGE="${2:-?}"
STEP="${3:-?}"
MSG="${4:-}"

DIR=".qa/${TICKET}"
LOG="${DIR}/progress.log"
STAMP_FILE="${DIR}/.progress.start"

mkdir -p "$DIR" 2>/dev/null || true

NOW=$(date +%s)

# Bước đầu của một chặng thì reset mốc thời gian, để "+Ns" là thời gian của chặng
# này chứ không cộng dồn từ lần chạy trước.
if [[ "$STEP" == 1/* ]] || [ ! -f "$STAMP_FILE" ]; then
  echo "$NOW" > "$STAMP_FILE" 2>/dev/null || true
  ELAPSED=0
else
  START=$(cat "$STAMP_FILE" 2>/dev/null || echo "$NOW")
  ELAPSED=$(( NOW - START ))
fi

LINE="[$(date +%H:%M:%S) +${ELAPSED}s] ${TICKET} · ${STAGE} · ${STEP} · ${MSG}"

echo "$LINE"
echo "$LINE" >> "$LOG" 2>/dev/null || true
