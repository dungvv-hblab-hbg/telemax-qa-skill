#!/usr/bin/env python3
"""
lint-harness.py — Kiểm cấu trúc harness. Chạy trong CI, cũng chạy được tay:

    python3 scripts/lint-harness.py

Kiểm 6 thứ, mỗi thứ ứng với một lỗi đã từng xảy ra thật:

1. Frontmatter của skill/agent/command: parse được, có `name`/`description`, tên hợp lệ.
2. `description` của skill ≤ 1024 ký tự (giới hạn cứng) và SKILL.md ≤ 500 dòng.
3. Link tương đối trong .md không trỏ vào hư không.
4. Mọi file .json parse được (evals + .mcp.json).
5. Script shell qua `bash -n`, script Node qua `node --check`.
6. `.mcp.json` không được có `--isolated`/`--storage-state` (đã thử, không nạp được
   session), và phải có `--user-data-dir` + `--timeout-action`.

Exit 0 = sạch, 1 = có lỗi.
"""
import glob
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
errors = []
checked = {"frontmatter": 0, "link": 0, "json": 0, "script": 0}


def err(msg):
    errors.append(msg)


# ── 1 & 2. Frontmatter ────────────────────────────────────────────────────
try:
    import yaml
except ImportError:
    sys.exit("Cần pyyaml: pip install pyyaml")

NAME_RE = re.compile(r"^[a-z0-9-]{1,64}$")

for path in sorted(glob.glob(".claude/skills/*/SKILL.md")):
    text = open(path, encoding="utf-8").read()
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    if not m:
        err(f"{path}: thiếu frontmatter")
        continue
    try:
        data = yaml.safe_load(m.group(1))
    except Exception as e:
        err(f"{path}: frontmatter không parse được — {e}")
        continue
    checked["frontmatter"] += 1
    name = str(data.get("name", ""))
    desc = str(data.get("description", ""))
    if not NAME_RE.match(name):
        err(f"{path}: name không hợp lệ: {name!r}")
    if name != os.path.basename(os.path.dirname(path)):
        err(f"{path}: name {name!r} khác tên thư mục")
    if not desc:
        err(f"{path}: thiếu description")
    if len(desc) > 1024:
        err(f"{path}: description {len(desc)} ký tự, vượt giới hạn 1024")
    body_lines = text[m.end():].count("\n")
    if body_lines > 500:
        err(f"{path}: body {body_lines} dòng, vượt 500 — tách sang reference/")

for path in sorted(glob.glob(".claude/agents/*.md") + glob.glob(".claude/commands/*.md")):
    text = open(path, encoding="utf-8").read()
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    if not m:
        err(f"{path}: thiếu frontmatter")
        continue
    try:
        # agent file có comment `#` trong frontmatter — bỏ trước khi parse
        yaml.safe_load(re.sub(r"^#.*$", "", m.group(1), flags=re.M))
        checked["frontmatter"] += 1
    except Exception as e:
        err(f"{path}: frontmatter không parse được — {e}")

# ── 3. Link tương đối ─────────────────────────────────────────────────────
md_files = glob.glob("**/*.md", recursive=True)
for path in md_files:
    if "node_modules" in path:
        continue
    for link in re.findall(r"\]\(([^)]+)\)", open(path, encoding="utf-8").read()):
        if link.startswith(("http://", "https://", "#", "mailto:")):
            continue
        target = os.path.normpath(os.path.join(os.path.dirname(path), link.split("#")[0]))
        checked["link"] += 1
        if not os.path.exists(target):
            err(f"{path}: link gãy -> {link}")

# ── 4. JSON ───────────────────────────────────────────────────────────────
for path in glob.glob("evals/*.json") + [".mcp.json"] + glob.glob(
    ".claude/skills/*/assets/*.json"
):
    try:
        json.load(open(path, encoding="utf-8"))
        checked["json"] += 1
    except Exception as e:
        err(f"{path}: JSON lỗi — {e}")

# ── 5. Cú pháp script ─────────────────────────────────────────────────────
for path in glob.glob(".claude/scripts/*.sh") + glob.glob("scripts/*.sh") + ["install.sh"]:
    if subprocess.run(["bash", "-n", path], capture_output=True).returncode:
        err(f"{path}: cú pháp bash lỗi")
    else:
        checked["script"] += 1

for path in glob.glob(".claude/scripts/*.mjs"):
    r = subprocess.run(["node", "--check", path], capture_output=True)
    if r.returncode:
        err(f"{path}: cú pháp JS lỗi — {r.stderr.decode()[:120]}")
    else:
        checked["script"] += 1

for path in glob.glob(".claude/skills/*/scripts/*.py") + glob.glob("scripts/*.py"):
    r = subprocess.run([sys.executable, "-m", "py_compile", path], capture_output=True)
    if r.returncode:
        err(f"{path}: cú pháp Python lỗi")
    else:
        checked["script"] += 1

# ── 6. .mcp.json ──────────────────────────────────────────────────────────
try:
    args = json.load(open(".mcp.json", encoding="utf-8"))["mcpServers"]["playwright"]["args"]
    for banned in ("--isolated", "--storage-state"):
        if banned in args:
            err(f".mcp.json: có {banned} — không nạp được session Telemax "
                "(localStorage, 0 cookie). Xem qa-config.md.")
    for need in ("--user-data-dir", "--output-dir", "--timeout-action"):
        if need not in args:
            err(f".mcp.json: thiếu {need}")
except Exception as e:
    err(f".mcp.json: không đọc được entry playwright — {e}")

# ── Kết ───────────────────────────────────────────────────────────────────
print(f"frontmatter: {checked['frontmatter']} file · link: {checked['link']} · "
      f"json: {checked['json']} · script: {checked['script']}")
if errors:
    print(f"\n{len(errors)} lỗi:")
    for e in errors:
        print(f"  {e}")
    sys.exit(1)
print("Sạch.")
