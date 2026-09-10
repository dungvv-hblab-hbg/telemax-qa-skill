# telemax-qa-skill

## Agent skills

### Issue tracker

GitHub Issues on `dungvv-hblab-hbg/telemax-qa-skill`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary, label strings unchanged. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context. `CONTEXT.md` và `docs/adr/` **chưa tồn tại** — chúng được tạo lười
bởi `/domain-modeling` khi có thuật ngữ hoặc quyết định thật cần chốt. Thiếu thì đi
tiếp, đừng báo. Quy ước đọc: `docs/agents/domain.md`.

## Repo này là gì

Không phải repo sản phẩm — đây là **gói phát hành của harness QA**. `.claude/` vừa là
thứ `install.sh` copy sang repo đích, vừa là thứ đang chạy ở chính đây.

Đọc trước khi sửa `.claude/`:

- [README.md](README.md) — luồng 8 command / 5 agent / 7 skill, và mục **Ngân sách
  token** với bốn quy tắc chi phối mọi thứ thêm vào `.claude/`
- [.claude/qa-config.md](.claude/qa-config.md) — điểm khai báo duy nhất. Đọc **theo
  mục**: `bash .claude/scripts/qa-config.sh <ticket|clickup|playwright|production|postman>`
- [docs/DEAD-ENDS.md](docs/DEAD-ENDS.md) — những thứ đã thử và không dùng được
- [docs/TESTING.md](docs/TESTING.md) — 4 tầng test + bảng chẩn đoán

Trước khi commit thay đổi trong `.claude/`:

```bash
bash .claude/scripts/smoke-scripts.sh     # tầng script, ~30s, không cần MCP
python3 scripts/lint-harness.py           # frontmatter, link, JSON, --project
bash scripts/check-gitignore.sh
```
