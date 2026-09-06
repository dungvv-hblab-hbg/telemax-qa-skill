#!/usr/bin/env bash
# Kiểm gitignore.snippet thật sự ignore — comment cuối dòng từng làm hỏng cả file.
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$T" && git init -q . && cp "$SRC/gitignore.snippet" .gitignore
mkdir -p .qa playwright/.auth .playwright-mcp-profile
touch .qa/a.md playwright/.auth/user.json .playwright-mcp-profile/p \
      x.xlsx.bak result.json staging.postman_environment.json .env
FAIL=0
for f in .qa/a.md playwright/.auth/user.json .playwright-mcp-profile/p \
         x.xlsx.bak result.json staging.postman_environment.json .env; do
  if git check-ignore -q "$f"; then echo "  ok   $f"; else echo "  FAIL $f không được ignore"; FAIL=1; fi
done
touch demo.example.postman_environment.json
if git check-ignore -q demo.example.postman_environment.json; then
  echo "  FAIL negation !*.example.postman_environment.json không hoạt động"; FAIL=1
else echo "  ok   negation cho file .example"; fi
exit $FAIL
