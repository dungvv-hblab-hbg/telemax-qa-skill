# Telemax QA Harness — End-to-End Tutorial

*(Vietnamese version: [TUTORIAL.md](TUTORIAL.md))*

This guide is for **someone who just received the harness** — a QA engineer, or a dev
doing QA, who has never run a `/qa-*` command. It walks a ticket through its whole life:
from installing into a repo, to bugs filed on ClickUp and the production deploy verified.

Read alongside when needed: [README.md](../README.md) (overview + token budget) ·
[TESTING.md](TESTING.md) (testing the harness itself) · [DEAD-ENDS.md](DEAD-ENDS.md)
(paths already tried and abandoned — don't retry them).

> **Note on language.** The harness itself runs in Vietnamese: command prompts, the
> generated checklist, and the `Test Cases_VN` sheet are Vietnamese. Literal values you
> will see on screen — section names like `Phản hồi review`, config values like
> `CHƯA ĐIỀN` / `CÓ` / `KHÔNG DÙNG` — are quoted verbatim here with an English gloss,
> because that is exactly the text in the files.

---

## 0. What this harness does for you

A chain of 11 slash commands running inside **Claude Code**, turning one ClickUp ticket
into a complete set of QA artifacts:

```
ClickUp ticket
   │  /qa-analyze          → analysis checklist (.md)
   │  ▸ YOU REVIEW
   │  /qa-apply-feedback   → updated checklist
   │  /qa-write-cases      → test cases, Excel with 8 sheets
   │  ▸ YOU REVIEW
   │  /qa-run              → Pass/Fail results + Defects sheet
   │  ▸ YOU REVIEW
   │  /qa-file-bugs        → ClickUp bugs + file uploaded to Drive
   │  ▸ YOU APPROVE THE WHOLE BATCH
   ▼
 deploy to production
   │  /qa-verify-prod      → post-deploy verification report
```

**Five human checkpoints.** The harness never walks from ticket to bug on its own. Each
checkpoint is where you read an artifact, fix it, and only then run the next command.

**A ticket with no spec** (title only, or an old feature nobody ever filed a ticket for)
takes a different path — `/qa-analyze` stops and asks you instead of building a checklist
out of the code itself. See **step 1b**.

Three kinds of components, so you know where output comes from:

| Kind | What it is | Example |
|---|---|---|
| **Command** (`.claude/commands/`) | entry point, runs in the main session — **can ask you questions** | `/qa-run` |
| **Agent** (`.claude/agents/`) | subagent doing one stage then exiting — **cannot pause and wait for you** | `test-runner` |
| **Skill** (`.claude/skills/`) | static knowledge, loaded on demand | `common-validate` |

Every question comes from a **command**, always batched into **one round** before any
agent runs. Three levels: **Blocking** (no safe default → you must answer) ·
**Confirm** (there is a default, but the default is still a guess) · **Agent's call**
(the agent decides, but must list it in the summary).

---

## 1. Prerequisites

### 1.1 On your machine

| Needed | What for | Check |
|---|---|---|
| Claude Code | run commands + agents | `claude --version` |
| Python 3 | `build.py`, `write_defects.py` (generate/write Excel) | `python3 --version` |
| Node 20+ | Playwright project, MCP server | `node --version` |
| LibreOffice | `recalc.py` recalculates Excel formulas | `which soffice` |
| ClickUp connector | read ticket, create bugs | `/mcp` in Claude Code |
| Figma connector | read design (if the ticket links one) | `/mcp` |
| Google Drive connector | upload the test case file (optional) | `/mcp` |

**Missing LibreOffice does not block you** — the Excel file is still correct, the Summary
cells are just empty until you open it in Excel once.

### 1.2 What you need to know upfront

- **Ticket ID** in the form `TLM-XXXX`. With no ticket, `/qa-analyze` **stops** and tells
  you to create one first (or offers to create it, after you approve the content).
- **Environment ↔ branch** — the single most common mix-up:

  | Environment | Built from branch | Used in stage |
  |---|---|---|
  | **dashboard-stage** | `stage` | `/qa-run` — the main test pass |
  | **production** | `master` | `/qa-verify-prod` — post-deploy verification |

  Not `dev`. Testing a build that does not yet contain the ticket still produces Pass
  numbers, so that mistake **never surfaces on its own** — which is why `/qa-run` makes
  you confirm first.

---

## 2. Installing into your repo (once)

### Step 2.1 — run `install.sh`

```bash
git clone https://github.com/dungvv-hblab-hbg/telemax-qa-skill.git
cd telemax-qa-skill
./install.sh /path/to/your-repo --dry-run   # preview what it would do
./install.sh /path/to/your-repo             # do it
```

| Flag | When to use |
|---|---|
| `--dry-run` | print what would be copied, touch nothing |
| `--force` | target repo **already has** `.claude/` and you are sure you want to overwrite |
| `--with-e2e` | target repo is **another Telemax app with the same login form** → copy the existing Playwright project too |

**Output:** the target repo gets `.claude/`, `.mcp.json`, and `gitignore.snippet`
appended to its `.gitignore`.

**The e2e project is NOT copied by default.** It depends on the real app (URLs, login
form, environment variables). Carrying it over to a different repo makes every selector
wrong in a way a newcomer cannot explain — `/qa-setup` builds one that fits the target
repo instead.

### Step 2.2 — `/qa-setup` in the target repo

Open Claude Code **inside the target repo** and type:

```
/qa-setup
```

**Input:** none.
**What it does:** surveys first (Python + openpyxl, chromium, Playwright MCP,
LibreOffice, Postman collection), **probes the repo and asks you** before building the
e2e project, and **asks for approval once for the whole batch** before installing
anything.

Three branches for the e2e project:

| What it finds | What it does |
|---|---|
| A `playwright.config.*` already exists | **patches** the existing config to satisfy the harness's guardrails |
| Nothing yet, and it is a web app | scaffolds against that repo's real app |
| Not a web app / different framework | drops the UI branch — `qa-config` records `KHÔNG DÙNG` ("not used"), `/qa-run` still runs the API + manual branches |

**Output:** an installed environment plus an explicit list of **what you must do
yourself**.

### Step 2.3 — fill in credentials

```bash
cp <e2e project>/.env.example <e2e project>/.env
```

Then fill in: `TELEMAX_USER` / `TELEMAX_PASS`, the base URL, and (if you will verify
production) `PROD_BASE_URL` + `TELEMAX_PROD_USER` / `TELEMAX_PROD_PASS`.

> **Passwords live only in `.env`.** The harness never asks for a password in chat, and
> never fills the login form through MCP — `browser_type` would leak the password
> verbatim into the transcript. Login always goes through a separate Node script.

### Step 2.4 — fill in `.claude/qa-config.md`

This is the harness's **single declaration point**. Any entry still reading `CHƯA ĐIỀN`
("not filled in") blocks the stage that needs it — most notably the **ClickUp
List/Space for bugs**, where `/qa-file-bugs` will stop.

Read it **section by section**; don't `cat` the whole file:

```bash
bash .claude/scripts/qa-config.sh ticket       # ticket prefix, environment ↔ branch
bash .claude/scripts/qa-config.sh clickup      # bug list, tags, priority map, Drive
bash .claude/scripts/qa-config.sh playwright   # status, spec path, sessions, MCP args
bash .claude/scripts/qa-config.sh production   # prod URL, account, @prod-safe tag
bash .claude/scripts/qa-config.sh postman      # collection, environment, report
```

### Step 2.5 — quick check

```bash
bash .claude/scripts/smoke-scripts.sh
```

~30 seconds, no MCP needed. All green means the install is done.

### Three install-time traps

1. **After editing `.mcp.json` you must quit Claude Code and reopen it.** MCP reads its
   args at startup; editing mid-session **has no effect and gives no signal**.
2. **Keep exactly ONE Playwright MCP, at project scope.** `claude mcp list` — if there is
   a `local`/`user` entry, run `claude mcp remove playwright -s local`. With two
   registered only one wins, and the winner may lack `--user-data-dir` → you seed the
   profile and still land on `/login`, with no error anywhere.
3. **Don't run a bare `pip install openpyxl`** (PEP 668 on macOS Homebrew / Ubuntu 23+).
   Use a venv — `/qa-setup` creates one:
   ```bash
   python3 -m venv .claude/.venv && .claude/.venv/bin/python -m pip install openpyxl
   ```

---

## 3. Running one ticket — step by step

Running example: ticket **TLM-2901**.

General tip: open a **second terminal** to follow progress down to each case:

```bash
tail -f .qa/TLM-2901/progress.log
```

---

### Step 0 — `/qa-login` (when needed)

| | |
|---|---|
| **Purpose** | log into the dashboard once, keep the session for later `/qa-run` calls |
| **When** | first install, or when `/qa-run` reports you are sitting on the login page |
| **Input** | no argument · add `prod` to log into production. Credentials come from `.env` |
| **Output** | session stored in `.playwright-mcp-profile/` (gitignored) |

```
/qa-login
/qa-login prod
```

How it works: the command runs `node .claude/scripts/seed-mcp-profile.mjs` — the script
reads `.env` in a **separate process**, so the password never passes through context.
The script is **idempotent**: if a session is still alive it prints `ALREADY_LOGGED_IN`
and exits.

What you have to do:

- **`2FA_REQUIRED`** → type the code yourself in the browser window, then type **`ok`**.
  The harness will not take the code through chat. (The current QA account has 2FA off.)
- **Leave the browser window open** — `/qa-run` reuses that same window.

> Order matters: **seed BEFORE calling any MCP tool**. Once MCP opens the browser it
> holds a lock on the profile directory and the script can no longer open it. If that
> happens, quit Claude Code and reopen.

---

### Step 1 — `/qa-analyze TLM-2901`

| | |
|---|---|
| **Purpose** | turn the ticket into an **analysis checklist** for you to review, and expose where **spec and code disagree** |
| **Input** | ticket ID · (optional) Figma link · base branch for the diff |
| **Output** | `.qa/TLM-2901/checklist_TLM-2901.md` (plus `analysis-spec.md` + `analysis-code.md`) |
| **Requires** | ClickUp connector enabled; a commit/branch for the ticket if you want section G |

It will ask (in one round):

1. **Ticket ID** — even when inferred from the branch name it still asks you to confirm.
   **Pasting the spec straight into chat → it STOPS** and tells you to create a ticket
   first (or offers to create it, after you approve the content).
2. **Base branch for the diff** — defaults to `stage`.
3. **No commit/branch found for the ticket** — is the code not done yet, or does this
   ticket not touch code at all? Your answer decides whether the checklist gets a
   section G.

It runs three agents:

```
spec-analyst  (spec ONLY, forbidden to read code)  ─┐
                                                    ├─►  test-analyst  ─►  checklist
code-analyst  (code + git diff ONLY)               ─┘     (synthesis)
```

Splitting them is **deliberate**: a single agent reading both describes *what the code
does* instead of *what the spec demands*, and "code differs from spec" bugs become
invisible. Where the two sides disagree becomes section **D6** — the most valuable
output of this stage.

Checklist structure (A → H):

| Section | Content |
|---|---|
| A | Sources read (ticket, Figma, commits) |
| B | Feature overview |
| C | Detail per part, split by screen |
| D | Summary tables — D1 field constraints, D2 messages, **D6 spec ≠ code** |
| E / E2 | Conditional tables · **AC table** (the source for the Traceability sheet) |
| F | Assumptions & questions for BA/Dev, each with a **confidence** level High/Medium/Low |
| G | Impact from the git diff *(only when there is a diff)* |
| H | Test plan *(only when more than 15 cases are expected)* |

**What you do next:** open the file and read it.

- Something to fix → write it into the **"Phản hồi review"** ("review feedback") section
  at the bottom, referencing **by number**: `#4 sai — maxlength thật là 100`. Save, then
  go to step 2.
- Looks fine → **skip step 2** and run `/qa-write-cases` directly.

---

### Step 1b — when the ticket has **no spec**

Not every ticket comes with a description and acceptance criteria. Three common states:

1. Title only — `"Test Order Module"`, 0 AC, no Figma
2. An old feature nobody ever filed a ticket for, no commit carrying the ticket ID
3. A dev ticket where the description was never filled in

When `spec-analyst` counts 0 AC, a description under 30 words and no Figma,
**`/qa-analyze` stops and asks you** instead of producing a checklist that merely looks
real.

> **Why not let it reverse-engineer the spec from the code?** Tests derived from code
> only prove *"the code does what the code does"*. The code caps a field at 50 chars →
> the test "typing 51 chars must show an error" → **Pass**. But if the customer wanted
> 100, or the dev typed 50 instead of 500, the test is still green and the bug is still
> there. The whole suite goes green and says nothing.

What you'll be asked — **a single round**, scope and choice together:

```
TLM-3210 "Test Order Module": 0 AC, 3-word description, no Figma, no commit with the ID.
Can't build a test checklist — every line would be inferred from the code itself.

Scope I can see in the code:
[x] Create order   [x] List + filter   [x] Detail   [ ] Sync job (no UI)

a) Hunt bugs now, no spec needed — default
b) a + build a reverse-engineered spec for you to sign
c) You add the AC to the ticket, I rerun
```

Answer in one line: `a`, or `a, drop the detail screen` to adjust the scope.

#### Two speeds

| | You spend | You get |
|---|---|---|
| **a — hunt bugs** | one batch approval | bugs now. **No Excel test cases, no docs** |
| **b — plus a spec** | one extra signing pass | bugs + a spec for the module, reusable forever |

Path `a` costs you almost nothing. Run it first; if it pays off, spend the signing effort
afterwards — both paths share the same artifacts, nothing is recomputed.

#### What it runs

```
ui-explorer   (explores staging in a browser, STILL forbidden to read code)  ─┐
                                                                              ├─► test-analyst
code-analyst  (already finished above, reused)                               ─┘
```

It needs a live session — run `/qa-login` first if you don't have one.

It is still **two independent halves**, exactly like the normal flow; only the source of
the first half changes, from *the ticket* to *the running system*. So a mismatch still
means something — it just reads as "the UI does A, the code does B" (the frontend caps
input at 200 chars while the API accepts 5000; a button is visible but the API returns
403).

#### `findings_TLM-3210.md` — only what is wrong **regardless of intent**

Every finding must name **which standard it violates**. If it can't, it isn't a bug — it
is a question. Five valid sources of a standard:

| Standard | What it catches |
|---|---|
| UI ≠ code | frontend caps at 200 chars, the backend doesn't validate at all |
| `common-validate` | a required field shows no error when left empty |
| Consistency within the scope | screen A renders times in the user's timezone, screen B in UTC |
| Telematics domain rules | an offline device still shows live coordinates |
| Error / empty branches | API 500 → the spinner never stops |

**What you do next:** read the file, delete rows you disagree with, then
`/qa-file-bugs TLM-3210`. This branch produces **no Excel test cases** — by design.

#### `spec-draft_TLM-3210.md` — only if you picked `b`

It describes every observed behaviour with **the verdict pre-filled**, so you only fix
what's wrong:

```
✅ 12. The order list defaults to newest-created first. [U1]
❌ 13. The Notes field caps at 200 chars in the UI; the backend doesn't validate. → F-01
❓ 14. An order in Shipped state can still be cancelled, with no warning. [U4]
      Question: does the business allow cancelling after shipping?
```

- `✅` / `❌` — the agent is confident, so you skim
- `❓` — **only you know** (business numbers, domain rules, intent); this is where you
  actually think

`❓` usually accounts for 15–20%. In a 50-line file you genuinely weigh 8–10 lines.

**What you do next:** fix the leading marks, answer the `❓` lines, save, then
`/qa-apply-feedback TLM-3210`.

> **On your first run, pick ONE screen.** The bottleneck is you signing, not the agent
> running. One screen yields 30–60 lines; a whole module can yield 300, and by line 80
> your eyes glaze over. For a big module, run it several times, one screen per run — the
> artifacts all collect in the same folder.

---

### Step 2 — `/qa-apply-feedback TLM-2901` *(only if you wrote feedback)*

| | |
|---|---|
| **Purpose** | apply your feedback to the checklist without breaking any references |
| **Input** | the "Phản hồi review" section of the checklist |
| **Output** | updated checklist + a `## Đã xử lý (YYYY-MM-DD)` ("processed") section |

This stage runs **directly in the main session, with no subagent** — because ambiguous
feedback is exactly when you need to ask back, and a subagent cannot pause and wait for
a person.

**This command has two branches**, picked from whichever file exists in `.qa/TLM-2901/`:

| File | Branch |
|---|---|
| `checklist_*.md` | apply review feedback — the rest of this section |
| `spec-draft_*.md` | **sign off the reverse-engineered spec** (from step 1b): `✅` → the ticket's ClickUp description · `❌` → a finding awaiting bug filing · `❓` → a comment asking the BA. It writes a local copy first, **asks you to approve the whole batch**, and only then touches ClickUp. Afterwards run `/qa-analyze` again — the ticket now has a spec, so you get a normal checklist |

Rules it follows:

- **Numbers never change.** New items are appended with the next number at the **end**,
  never inserted in the middle (the Excel Note column points at these numbers). A dropped
  item becomes `~~#11 (đã bỏ)~~` and its number is never reused.
- Feedback pointing at a number that doesn't exist, or ambiguous feedback (`#4 sai` with
  no detail) → it **asks you right there**, it does not guess.
- Processed feedback is **moved down** into "Đã xử lý", never deleted.
- Empty section → it says plainly that the checklist is unchanged and stops, rather than
  pretending it updated something.

**What you do next:** review again. If section F still has unanswered **Low** confidence
questions, you should **not** write test cases yet — those are the questions to put to
the BA or the customer.

---

### Step 3 — `/qa-write-cases TLM-2901`

| | |
|---|---|
| **Purpose** | turn the checklist into an **Excel test case suite** in the Telemax template |
| **Input** | the reviewed `.qa/TLM-2901/checklist_TLM-2901.md` |
| **Output** | `.qa/TLM-2901/TCs_<Module>_v<ver>.xlsx` — 8 sheets |
| **Requires** | Python + openpyxl (via `.claude/scripts/qa-py.sh`) |

It **blocks and asks** when:

1. The checklist still has unprocessed feedback, or section F still has **Low**
   confidence questions.
2. A field needs a real constraint (maxlength, min/max, format) that D1 doesn't have and
   F doesn't cover with a High-confidence assumption **backed by readable evidence**. A
   bare "High" label doesn't count. **Never treat 255, or any other "standard" number, as
   fact.**
3. An Expected Result needs a message that D2 doesn't have.

It **asks you to confirm** (defaults offered): `cover.module` · `cover.version` ·
`cover.source` · `cover.create_date` · output filename.

Excel structure:

```
Cover · Summary · Test Cases · Test Cases_VN · Common Validate ·
Defects & Follow-ups · Traceability · Assumptions & Questions
```

- The **"Test Cases" (EN) sheet is the source of truth**; `Test Cases_VN` is the
  translation. All Summary formulas count on the EN sheet.
- **Rows 1–5 are header; data starts at row 6.** 14 columns A→N: ID · Section · Type ·
  Priority · Title · Precondition · Steps · Data · Expected · Round 1 (Result, Bug ID) ·
  Round 2 (Result, Bug ID) · Note.
- IDs **reset per section**: `TC-A-001`, `TC-B-001`… (different from the checklist's own
  numbering).
- Two machine-readable markers, placed at the **start** of the Note cell:
  `[MANUAL] <reason>` (must be run by hand) and `[DATA-REQ] <condition>` (automatable but
  needs specific environment data).
- The **Traceability** sheet maps AC → TC. A remaining `MISSING` row means **an AC is not
  covered** — a real gap, not a decorative warning.

**What you do next:** open the file, add/edit/remove cases. If you change the checklist
and want to regenerate, rerun this same command. Happy with it → go to step 4.

---

### Step 4 — `/qa-run TLM-2901`

| | |
|---|---|
| **Purpose** | run UI tests (Playwright) + API tests (newman), write results into Excel, fill the Defects sheet |
| **Input** | the reviewed `.xlsx` · a live login session · Playwright MCP |
| **Output** | Excel with Result filled in (Bug ID empty), the **Defects & Follow-ups** sheet, exported `.ts` specs, newman's `result.json`, Phase 1 screenshots in `.qa/TLM-2901/phase1/` |

This is the stage with the most gates. It **blocks** on:

| # | Gate | Why |
|---|---|---|
| 1 | **Is the code on `stage` yet?** (`git log origin/stage --grep=TLM-2901`) | running before the code lands measures the old build and records it against the new ticket — it still produces Pass numbers, so the error never surfaces |
| 2 | **Which `.xlsx`** | it will not silently pick the newest file |
| 3 | **Write into Round 1 or Round 2** | the wrong round makes `% Executed` wrong |
| 4 | **Special test data** (`[DATA-REQ]`) | it will not invent data or assume it exists |
| 5 | **Playwright MCP present, and exactly one** | more than one fails silently |
| 6 | **Login session** — seed first, never probe via MCP | calling MCP first locks you out of the profile |
| 7 | **The e2e project's `.env`** | missing → stop; it will not ask for a password in chat |
| 8 | **Postman** | `CHƯA CÓ` ("not available") → skip the API branch and say how many cases are skipped, rather than stopping the stage |

On **Round** — it distinguishes three states, not two:

| Round 1 currently holds | Proposal |
|---|---|
| completely empty | write Round 1 |
| only `Blocked` / `Not Run`, Defects sheet empty | **overwrite Round 1** |
| real `Pass`/`Fail` results | write Round 2 |

**Resume:** if the previous run was cut short (session expired, you stopped it, the
machine died) it reports the numbers — *"Round 1 has results for 30/45 cases. Continue
from case 31, or rerun all 45?"* — defaulting to **continue**.

Cases are split three ways: **UI** (Playwright), **API** (newman/Postman), and **Manual**
(recorded as `Blocked` + `[MANUAL]`). UI cases with no spec yet go through **Phase 1** —
the agent explores elements through MCP (the window is visible, you watch it work), then
exports `telemax-e2e/tests/TLM-2901.spec.ts` so later runs are pure code.

**What you do next:** open the **LOCAL file** (not the copy on Drive) and go to the
**Defects & Follow-ups** sheet:

- Fix **Actual** wherever the agent described it inaccurately.
- For a case you don't want a bug for, set **Fix Status = `Won't fix`**. **DO NOT DELETE
  THE ROW** — deletion doesn't record intent; the case is still Fail with no Bug ID, so
  it comes back on the next fill.

---

### Step 5 — `/qa-file-bugs TLM-2901`

| | |
|---|---|
| **Purpose** | create ClickUp bugs from the reviewed Defects sheet, write Bug IDs back into Excel, upload the file to Drive |
| **Input** | the reviewed LOCAL `.xlsx` · ClickUp list/space · Drive folder |
| **Output** | bugs on ClickUp · Bug IDs in Excel · file on Drive · `.qa/TLM-2901/bugs-proposed.json` |

This stage runs in **two halves with an approval stop in between**:

```
bug-proposer  ->  YOU APPROVE THE BATCH  ->  bug-filer
(read, draft, dedupe)                       (create, write back, upload)
```

The approval lives in the **command**, not in an agent — a subagent cannot pause for a
human, so a guardrail placed inside an agent is a broken guardrail.

It asks (one round):

1. Did you review the Defects sheet **locally or on Drive**? On Drive → it stops; the
   script only reads the local copy.
2. Which file, if `.qa/TLM-2901/` holds more than one.
3. **Target ClickUp list/space** (`qa-config.sh clickup`). Still `CHƯA ĐIỀN` → it asks
   you and will not guess a list.
4. **Target Google Drive folder** — asked in this same round. Giving a folder means
   consenting to the upload.

At the stop it presents a table:

| TC ID | Bug title | Priority | Suggested assignee | Duplicate? |
|---|---|---|---|---|

plus the rows it excluded and why (`Won't fix`, already has a Bug ID, `[MANUAL]`), and
**every suspected duplicate** of an open bug — for each one it asks whether to **reuse
the existing ID** or **create a new bug**.

**What you do next:** approve **once for the whole batch**. In that same reply you can
drop rows, change assignees, or change priorities.

An empty list (clean ticket) still runs the **upload** step. A ticket that ran clean and
never got uploaded loses exactly the thing most worth sharing.

> Write-back is **keyed by TC ID, not by row number**, and **appends after the last row
> that has a TC ID** rather than filling the first blank. That is what makes a failed bug
> creation safe to rerun.

---

### Step 6 — `/qa-verify-prod TLM-2901` *(after the fix is deployed)*

| | |
|---|---|
| **Purpose** | rerun the ticket's spec against production and catch regressions |
| **Input** | `telemax-e2e/tests/TLM-2901.spec.ts` · `.env` with `PROD_BASE_URL` + prod account |
| **Output** | `.qa/TLM-2901/prod-verify-<date>.md` |

It runs from **reviewed code, NOT through MCP**, and **only cases tagged `@prod-safe`**
(read-only cases that write no data). The guardrail leans toward skipping: a skipped case
can be fixed later, corrupted customer data cannot.

It **blocks** when:

1. No commit for the ticket on `master` — and even when there is one it **still asks**
   whether the build/deploy has actually finished (merging and deploying are two
   different things).
2. `qa-config` records Playwright as `KHÔNG DÙNG` → there is no spec to verify, so it has
   to be done by hand.
3. No spec file yet → it tells you to run `/qa-run` against staging first.
4. **No case tagged `@prod-safe`** → stop, and tell you to tag the read-only cases first.
   It will not run nothing and report green.
5. `.env` missing `PROD_BASE_URL` or the prod account.

Before running it tells you **how many of the total cases will run** and which ones are
excluded for lack of a tag — so you never assume full coverage.

The report calls out **regressions** (Pass on staging, Fail on prod) explicitly — that is
a production incident. It **never files bugs itself**; it only proposes them.

---

## 4. Two support commands — used constantly

### `/qa-status` — where am I

```
/qa-status              # every ticket, newest first
/qa-status TLM-2901     # the six stages of one ticket in detail
```

Read-only. Each finished stage appends a line to `.qa/<ticket>/state.json`. That file is
a **journal, not the source of truth** — the artifacts on disk are. So `/qa-status`
compares both and reports mismatches (e.g. the journal says test cases were generated but
the `.xlsx` has been deleted).

Stage → next command:

| State | What to run next |
|---|---|
| nothing yet | `/qa-analyze TLM-2901` |
| `analyze: done` | review the checklist → `/qa-apply-feedback` (if you edited it) or `/qa-write-cases` (if not) |
| `apply-feedback: done` | `/qa-write-cases TLM-2901` |
| `write-cases: done` | review the Excel → `/qa-run TLM-2901` |
| `run: in_progress` | `/qa-run TLM-2901` — the gate will propose `RESUME: có` (yes) |
| `run: done` | review the Defects sheet (LOCAL copy) → `/qa-file-bugs TLM-2901` |
| `file-bugs: done` | staging is finished; after deploy → `/qa-verify-prod TLM-2901` |
| any stage `failed` | rerun that exact stage |

`.qa/` is gitignored, so this state is **local to your machine** and not shared.

### `/qa-doctor` — run it whenever something feels off

Read-only: **installs nothing, edits nothing** (that's `/qa-setup`'s job). It reports
three columns — **Item · Status · What to do** — split into *blocking* / *non-blocking
but worth knowing* / *things you must do yourself*.

The three conditions it diagnoses:

| Condition | Symptom | Fix |
|---|---|---|
| **a. Duplicate MCP scopes** | `.mcp.json` behaves as if it doesn't exist, **with no error at all** | `claude mcp remove playwright -s local` (or `-s user`), then **quit Claude Code and reopen** |
| **b. `.mcp.json` out of sync with `qa-config`** | `browser_wait_for` dies with `TimeoutError: Timeout 5000ms exceeded` (the default is only 5s) | add `--timeout-action 30000`, `--timeout-navigation 120000`, `--user-data-dir`, `--output-dir`; make sure `--isolated` / `--storage-state` are **absent**. Then reopen the session |
| **c. Stuck on `/login` forever** | seeding succeeds but you're still on the login page | stop re-logging-in — if the profile is `LOCKED` and `localStorage` only holds `app-version`, this is condition (a) or (b) and reseeding is pointless |

---

## 5. Where the artifacts land

```
.qa/TLM-2901/
├─ analysis-spec.md            spec-only analysis (spec-analyst)
├─ analysis-code.md            code+diff-only analysis (code-analyst)
├─ checklist_TLM-2901.md       ★ you review this at checkpoints 1 and 2
│
│  — no-spec branch only (step 1b) —
├─ analysis-ui.md              what the running UI does (ui-explorer)
├─ findings_TLM-2901.md        ★ wrong regardless of intent — delete rows you disagree with
├─ spec-draft_TLM-2901.md      ★ you sign every line ✅/❌/❓
├─ spec-signed_TLM-2901.md     the signed ✅ set, before it goes to ClickUp
├─ explore/                    screenshots taken while exploring the UI
│
├─ TCs_<Module>_v1.0.xlsx      ★ you review this at checkpoints 3 and 4
├─ bugs-proposed.json          PROPOSED bug list, awaiting your approval
├─ prod-verify-<date>.md       production verification report
├─ result.json                 newman report (API branch)
├─ phase1/                     screenshots taken while exploring via MCP
├─ progress.log                per-case progress — `tail -f` it
└─ state.json                  stage journal, for /qa-status and resume

telemax-e2e/tests/TLM-2901.spec.ts    spec exported from Phase 1, one file per ticket
.playwright-mcp-profile/              MCP's session (Phase 1)
telemax-e2e/playwright/.auth/         the code session (running specs) — SEPARATE
```

**Two separate sessions is the design, not a bug.** Merging them into one was tried and
doesn't work — see [DEAD-ENDS.md](DEAD-ENDS.md) §1. Don't retry it.

---

## 6. Three traps already paid for — don't remove the guardrails

**Append; never fill blanks.** A new Defects row is written after the *last* row holding
a TC ID. Filling the first empty cell means one deleted row in the middle causes the next
fill to overwrite the rows below it — including the Actual text you already reviewed.

**Key by TC ID, never by row number.** If you insert or delete a row between `read` and
`writeback`, the indices shift and Bug IDs attach to the wrong cases.

**Never use "delete the row" as a rejection signal.** To say "no bug for this case", set
Fix Status = `Won't fix`.

---

## 7. Common problems

| Symptom | Usual cause | Fix |
|---|---|---|
| `/qa-analyze` stops, asks for a ticket | you pasted the spec into chat instead of giving an ID | create the ClickUp ticket, or let the harness create it after you approve the content |
| `/qa-analyze` stops and offers a/b/c | the ticket has no AC, no description, no Figma | this is **step 1b**, not a failure. Pick `a` for bugs only, `b` if you also want a spec |
| No `checklist_*.md` but `/qa-status` says analyze is done | the ticket took the no-spec branch | by design — that branch produces `findings_*.md`, not a checklist |
| `ui-explorer` stops immediately, reports a redirect to `/login` | the session expired | `/qa-login`, then rerun |
| `QA-EXPLORE-*` records left on staging | the screen has no delete action | `ui-explorer` reports it in section A of `analysis-ui.md` — clean up by hand |
| `/qa-run` stops at gate 1 | no commit for the ticket on `stage` yet | merge + build to dashboard-stage, then rerun |
| `browser_wait_for` times out at 5000ms | `.mcp.json` missing `--timeout-action`, or an MCP at another scope is winning | `/qa-doctor` → condition (a)/(b), fix, then **reopen Claude Code** |
| Seeded, still on `/login` | the profile isn't being loaded (duplicate MCP scope) — not an expired session | `/qa-doctor`; don't re-login in a loop |
| Seed script says the profile is taken | this session already called an MCP tool, which holds the lock | quit Claude Code, reopen, run `/qa-login` **as the very first thing** |
| Summary cells in Excel are empty | LibreOffice missing, so no recalc happened | open the file in Excel once, or install LibreOffice |
| `pip install openpyxl` fails with `externally-managed-environment` | PEP 668 | use the `.claude/.venv` virtualenv |
| `/qa-file-bugs` stops on the ClickUp list | `qa-config.md` still says `CHƯA ĐIỀN` | fill in the `clickup` section of `.claude/qa-config.md` |
| The API branch is skipped | `qa-config`'s `postman` section says `CHƯA CÓ` | that's by design — add the collection when the team has one |
| Traceability still shows `MISSING` | an AC has no test case covering it | add cases, or state explicitly why it isn't covered |
| Editing `.mcp.json` changes nothing | MCP reads its args at startup | quit Claude Code and reopen |

Full diagnostic table (~25 symptoms): [TESTING.md](TESTING.md).

---

## 8. One-page summary

```bash
# Install (once per repo)
./install.sh /path/to/your-repo
# inside the target repo:
/qa-setup
cp <e2e project>/.env.example <e2e project>/.env   # fill in URL + test account
#   fill in .claude/qa-config.md (ClickUp list)
bash .claude/scripts/smoke-scripts.sh
```

```
# One ticket, end to end
/qa-login                      # whenever you need a session
/qa-analyze TLM-2901           ▸ review the checklist
/qa-apply-feedback TLM-2901    ▸ review again (skip if you changed nothing)
/qa-write-cases TLM-2901       ▸ review the Excel file
/qa-run TLM-2901               ▸ review the Defects sheet (LOCAL copy; use Won't fix, never delete rows)
/qa-file-bugs TLM-2901         ▸ approve the whole bug batch
# --- after the production deploy ---
/qa-verify-prod TLM-2901

# Any time
/qa-status [TLM-2901]          # where am I
/qa-doctor                     # something feels off
tail -f .qa/TLM-2901/progress.log
```

```
# Ticket with NO spec (step 1b) — /qa-analyze will offer a/b/c itself
/qa-login                      # a session is needed to explore the UI
/qa-analyze TLM-3210           ▸ answer a or b, and confirm the scope

# picked a — hunt bugs
                               ▸ delete rows you disagree with in findings_TLM-3210.md
/qa-file-bugs TLM-3210         ▸ approve the batch.  DONE (no Excel test cases)

# picked b — plus a reverse-engineered spec
                               ▸ sign ✅/❌/❓ in spec-draft_TLM-3210.md
/qa-apply-feedback TLM-3210    ▸ approve one batch: spec → ticket · ❌ → bugs · ❓ → comment
/qa-file-bugs TLM-3210         ▸ approve the batch
/qa-analyze TLM-3210           # rerun — the ticket has a spec now, so you get a checklist
```
