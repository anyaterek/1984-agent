# mr-review Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A public, agent-agnostic `mr-review` skill that reviews and tests GitLab MRs / GitHub PRs in three depth modes (`standard`, `hard`, `ultra`) by one command.

**Architecture:** The skill is a `SKILL.md` orchestrator plus focused reference files (modes, roles, report format, checks, platforms) loaded on demand. Deterministic steps (platform detection, temporary worktrees, `ultra` vote tally) live in small POSIX shell scripts so every agent gets identical behaviour; those scripts are unit-tested with Vitest. Agent behaviour of the skill itself is verified with eval scenarios against a generated fixture repo.

**Tech Stack:** Markdown (Agent Skills `SKILL.md` format), POSIX `sh` + `git` + `gh`/`glab` for scripts, bun + Vitest + TypeScript (dev-only, not shipped with the skill) for tests.

**Spec:** `docs/superpowers/specs/2026-10-16-mr-review-skill-design.md`

## Global Constraints

- Skill lives in `skills/mr-review/`; nothing in it may require bun/node at runtime — only `sh`, `git`, `gh` (GitHub), `glab` (GitLab).
- Scripts are POSIX `sh` and must run on both macOS (BSD userland) and Linux (GNU): no `sed -i`, no `readlink -f`, no `mktemp` flags beyond `-d`.
- Instructions never name tools of one specific agent (`Task`, `Agent`, `spawn_agent`…). Write «запусти субагента с заданием …».
- Skill text is written in English (public skill); the report and MR comments are in the user's conversation language unless `REVIEW.md` sets `comment_language`.
- Severity tokens everywhere (scripts, subagent JSON): `blocker` 🔴, `major` 🟡, `minor` ⚪, plus vote-only `none` («не проблема»).
- Nothing is ever posted to the MR without explicit user confirmation in the same run.
- The user's working tree is never modified; all code execution happens in temporary worktrees removed at the end (also on failure).
- Commits: Conventional Commits, English subject, no AI/Claude mentions and no `Co-Authored-By` trailers (user's global rule).

## Review Focus

1. **Remote URL shapes** — `git@host:o/r.git`, `https://host/o/r`, `ssh://git@host:2222/g/sub/r.git`, self-hosted hosts without «github»/«gitlab» in the name: detection must classify the first three correctly and return `unknown` (not guess) for the last. Pinned in Task 1.
2. **Interrupted or crashed run** — a worktree from a previous run is left in `$TMPDIR`; the next run for the same MR must replace it, not fail on «already exists». Pinned in Task 3.
3. **Huge diffs and generated files** — lockfiles, `dist/`, snapshots and `REVIEW.md` `ignore` paths must be excluded before review; otherwise agents drown. Pinned in Task 6 (instruction) and Task 7 (eval scenario E6).
4. **Missing / unauthenticated `gh`/`glab`** — the skill must stop with the exact command to fix it, not fall back to guessing the diff. Pinned in Task 6 and eval E7.
5. **Repo with no detectable test/build commands** — report «не удалось определить команды», never invent `npm test`. Pinned in Task 4 (`checks.md`) and eval E5.

---

## File Structure

```
skills/mr-review/
  SKILL.md                     # entry: args, preconditions, flow, links to references
  references/
    modes.md                   # standard / hard / ultra procedures, debate, mode heuristic
    report-format.md           # severity scale, subagent JSON contract, terminal report, comment body
    checks.md                  # deps install, test/build detection, baseline + env classification
    platforms.md               # gh/glab: resolve MR, fork check, diff, publish, dedupe
    review-md-template.md      # REVIEW.md template for teams
    roles/
      correctness.md
      architecture.md
      security.md
      performance.md
      tests.md
  scripts/
    detect-platform.sh
    worktree.sh
    tally.sh
tests/
  helpers/run.ts               # spawn a script, return {code, stdout, stderr}
  helpers/git-fixture.ts       # temp git repos for worktree tests
  scripts/detect-platform.test.ts
  scripts/worktree.test.ts
  scripts/tally.test.ts
  skill-structure.test.ts
evals/
  make-fixture.sh              # builds the eval repo with planted problems
  scenarios.md                 # E1..E8: setup, command, expected behaviour
  results/                     # one file per eval run
.claude-plugin/plugin.json
.claude-plugin/marketplace.json
package.json, tsconfig.json, vitest.config.ts, README.md, LICENSE, .gitignore
```

---

### Task 1: Tooling and platform detection

**Files:**
- Create: `package.json`, `tsconfig.json`, `vitest.config.ts`, `.gitignore`, `tests/helpers/run.ts`
- Create: `skills/mr-review/scripts/detect-platform.sh`
- Test: `tests/scripts/detect-platform.test.ts`

**Interfaces:**
- Produces: `run(script: string, args: string[], opts?: { cwd?: string; env?: Record<string,string> }): { code: number; stdout: string; stderr: string }` in `tests/helpers/run.ts` (wraps `spawnSync`, `stdout` trimmed). `SCRIPTS` constant = absolute path to `skills/mr-review/scripts`.
- Produces: `detect-platform.sh [remote-url]` → stdout `github` | `gitlab` | `unknown`, exit 0. Without an argument reads `git remote get-url "${MR_REVIEW_REMOTE:-origin}"`; no remote → `unknown`, exit 0.

- [ ] **Step 1: Init tooling**

`bun init -y` is not used; write `package.json` by hand: `"private": true`, `"type": "module"`, scripts `"test": "vitest run"`. Then `bun add -d vitest typescript @types/node`. `tsconfig.json`: `strict: true`, `module`/`moduleResolution` `NodeNext`, `noEmit`. `.gitignore`: `node_modules/`, `evals/.work/`.

- [ ] **Step 2: Write failing tests**

```ts
describe('detect-platform', () => {
  it.each([
    ['git@github.com:acme/app.git', 'github'],
    ['https://github.com/acme/app', 'github'],
    ['git@gitlab.com:acme/app.git', 'gitlab'],
    ['ssh://git@gitlab.acme.io:2222/team/sub/app.git', 'gitlab'],
    ['https://git.acme.io/team/app.git', 'unknown'],
    ['', 'unknown'],
  ])('%s -> %s', (url, expected) => {
    const r = run('detect-platform.sh', [url]);
    expect(r.code).toBe(0);
    expect(r.stdout).toBe(expected);
  });
  it('reads origin when no argument given', () => { /* temp repo with origin git@github.com:a/b.git -> github */ });
  it('returns unknown outside a git repo', () => { /* cwd = fresh tmp dir */ });
});
```

- [ ] **Step 3: Run** `bun run test tests/scripts/detect-platform.test.ts` — Expected: FAIL (script missing).
- [ ] **Step 4: Implement `detect-platform.sh`** — extract host with `sed` (strip scheme, `user@`, port, path), lowercase via `tr`; `*github*` → github, `*gitlab*` → gitlab. `chmod +x`.
- [ ] **Step 5: Run** the same command — Expected: PASS.
- [ ] **Step 6: Commit** `feat(scripts): add platform detection with test tooling`

---

### Task 2: Vote tally for `ultra`

**Files:**
- Create: `skills/mr-review/scripts/tally.sh`
- Test: `tests/scripts/tally.test.ts`

**Interfaces:**
- Produces: `tally.sh <vote>...` where each vote ∈ `blocker|major|minor|none`. Order `none < minor < major < blocker`. Result = element at index `floor(n/2)` of the ascending-sorted votes (median for odd n). Stdout one line: `<result> <unanimous|disputed> blocker=<n> major=<n> minor=<n> none=<n>`. Exit 2 with message on stderr for zero votes or an unknown token.

- [ ] **Step 1: Write failing tests**

```ts
it('unanimous', () => expect(run('tally.sh', ['major','major','major','major','major']).stdout)
  .toBe('major unanimous blocker=0 major=5 minor=0 none=0'));
it('clear majority', () => expect(run('tally.sh', ['blocker','blocker','blocker','minor','none']).stdout)
  .toBe('blocker disputed blocker=3 major=0 minor=1 none=1'));
it('2/2/1 resolves by median', () => expect(run('tally.sh', ['blocker','blocker','minor','minor','none']).stdout)
  .toBe('minor disputed blocker=2 major=0 minor=2 none=1'));
it('majority none rejects', () => expect(run('tally.sh', ['none','none','none','major','blocker']).stdout)
  .toMatch(/^none disputed/));
it('rejects unknown token', () => expect(run('tally.sh', ['critical']).code).toBe(2));
it('rejects empty input', () => expect(run('tally.sh', []).code).toBe(2));
```

- [ ] **Step 2: Run** `bun run test tests/scripts/tally.test.ts` — Expected: FAIL.
- [ ] **Step 3: Implement `tally.sh`** — map tokens to 0..3, count, walk counts ascending until cumulative > floor(n/2).
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** `feat(scripts): add median vote tally for ultra debate`

---

### Task 3: Temporary worktrees

**Files:**
- Create: `skills/mr-review/scripts/worktree.sh`
- Create: `tests/helpers/git-fixture.ts`
- Test: `tests/scripts/worktree.test.ts`

**Interfaces:**
- Consumes: `run` from Task 1.
- Produces: `worktree.sh create <spec>` where `<spec>` is `pr:<n>` (fetches `refs/pull/<n>/head`), `mr:<n>` (fetches `refs/merge-requests/<n>/head`) or `ref:<git-ref>` (no fetch for local refs; for `origin/<branch>` runs `git fetch <remote> <branch>` first). Fetched refs are stored as `refs/mr-review/<pr|mr>-<n>`. Creates a detached worktree at `${TMPDIR:-/tmp}/mr-review-<repo-dir-name>-<slug(spec)>`, removing an existing worktree at that path first. Stdout: the absolute path. Remote = `${MR_REVIEW_REMOTE:-origin}`.
- Produces: `worktree.sh remove <path>` → `git worktree remove --force <path>`, `git worktree prune`, deletes the matching `refs/mr-review/*` ref if any; exit 0 even if the path is already gone.
- Produces: `makeRepo(): { dir: string; remote: string }` in `tests/helpers/git-fixture.ts` — a bare «remote» with `main`, branch `feature`, and refs `refs/pull/7/head` and `refs/merge-requests/7/head` pointing at a commit that adds `feature.txt`; plus a clone at `dir` with `origin` = the bare repo.

- [ ] **Step 1: Write failing tests**

```ts
it('creates worktree for pr:7 with the PR commit checked out', () => {
  const { dir } = makeRepo();
  const r = run('worktree.sh', ['create', 'pr:7'], { cwd: dir });
  expect(r.code).toBe(0);
  expect(existsSync(join(r.stdout, 'feature.txt'))).toBe(true);
});
it('creates worktree for mr:7', /* same for mr:7 */);
it('creates worktree for ref:origin/main without feature.txt', /* ... */);
it('does not touch the user working tree', () => {
  /* git status --porcelain and current branch are identical before and after create */
});
it('replaces a stale worktree left by a previous run', () => {
  /* create twice in a row -> second exit 0, same path */
});
it('remove deletes worktree and mr-review ref, and is idempotent', () => {
  /* remove twice -> both exit 0; `git worktree list` has no path; `git for-each-ref refs/mr-review` empty */
});
it('fails with exit 1 and a message for unknown pr', /* pr:999 -> code 1, stderr mentions pr:999 */);
```

- [ ] **Step 2: Run** `bun run test tests/scripts/worktree.test.ts` — Expected: FAIL.
- [ ] **Step 3: Implement `worktree.sh`** — `set -eu`; resolve repo root with `git rev-parse --show-toplevel`; `git worktree add --detach`.
- [ ] **Step 4: Run** — Expected: PASS. Also run the whole suite `bun run test` — PASS.
- [ ] **Step 5: Commit** `feat(scripts): add temporary worktree management for MR checkout`

---

### Task 4: Shared references — report format, roles, checks, REVIEW.md template

**Files:**
- Create: `skills/mr-review/references/report-format.md`, `checks.md`, `review-md-template.md`, `roles/{correctness,architecture,security,performance,tests}.md`
- Test: `tests/skill-structure.test.ts`

**Interfaces:**
- Produces (consumed by Tasks 5–6): the **subagent finding contract** in `report-format.md` — reviewers return one fenced `json` block, an array of
  `{ "role": string, "severity": "blocker"|"major"|"minor", "file": string, "line": number|null, "endLine": number|null, "title": string, "why": string, "suggestion": string|null }`.
  Vote contract: array of `{ "id": "F<n>", "vote": "blocker"|"major"|"minor"|"none", "reason": string }`.
- Produces: `checks.md` **checks result contract** — for each of `build`, `tests`: `passed | failed (new) | failed (pre-existing) | env-unverified | not-run | not-detected`, with a ≤40-line log excerpt for failures.
- Produces: `markdownLinks(file): string[]` helper inside the structure test.

- [ ] **Step 1: Write failing structure test** — for every `.md` under `skills/mr-review/`: every relative link `](path)` resolves to an existing file; every file under `references/roles/` is linked from at least one other skill file (fails now: files missing). Expected list of role files is pinned: `['architecture.md','correctness.md','performance.md','security.md','tests.md']`.
- [ ] **Step 2: Run** `bun run test tests/skill-structure.test.ts` — Expected: FAIL.
- [ ] **Step 3: Write `report-format.md`** with the values from the spec:
  - severity table (🔴 blocker: breaks logic/behaviour, build/tests failed *because of the MR*, `REVIEW.md` blocker rules; 🟡 major: structure, readability, missing tests, convention violations; ⚪ minor: style, taste, optional);
  - verdict: any blocker → `❌ Есть блокеры`; else any major → `⚠️ Есть что поправить`; else `✅ Можно мёржить`;
  - terminal report template: header `MR-review: <!iid|#n> «title» — режим <mode>`, checks line, then sections 🔴/🟡/⚪ with **one continuous numbering** across sections (used for publish selection), each item `` `file:line` — title``, why, suggestion; in `ultra` a line `⚖️ серьёзность спорная: 🔴a 🟡b ⚪c ✖d` for disputed items; final collapsed section «Отклонено в споре»; a one-line `REVIEW.md` suggestion when it is absent;
  - MR comment body: `**<emoji> <level>** — <title>`, blank line, why, optional `_Предложение:_ …`, then marker `<!-- mr-review:role=<role> -->`. Disputed mark never appears in comments.
- [ ] **Step 4: Write role files.** Each: purpose (one paragraph), checklist of what to look at (6–10 items), what is *out of scope* for the role (to cut duplicates), and «return findings in the contract from [report-format.md](../report-format.md)». `tests.md` additionally owns running checks per [checks.md](../checks.md) and flags changed logic without tests as `major`.
- [ ] **Step 5: Write `checks.md`**:
  - fork MRs: show the exact install/test/build commands and wait for confirmation; refusal → `not-run`, review continues;
  - install (frozen, never rewrite lockfiles): `bun.lock`/`bun.lockb` → `bun install --frozen-lockfile`; `pnpm-lock.yaml` → `pnpm install --frozen-lockfile`; `yarn.lock` → `yarn install --immutable` (Berry) or `--frozen-lockfile` (v1); `package-lock.json` → `npm ci`; `uv.lock` → `uv sync --frozen`; `poetry.lock` → `poetry install --no-root`; `go.mod` → `go mod download`; `Cargo.lock` → none;
  - commands: `REVIEW.md` `commands` first; else `package.json` scripts `build`/`test` run via the detected manager, `Makefile` targets `build`/`test`, `pyproject.toml` → `pytest`, `go.mod` → `go build ./...`/`go test ./...`, `Cargo.toml` → `cargo build`/`cargo test`; none found → `not-detected`, never guess;
  - each command timeout 10 minutes;
  - on failure: create `ref:origin/<target>` worktree with [worktree.sh](../scripts/worktree.sh), run the same command; fails there too → `failed (pre-existing)`; else `failed (new)` → 🔴;
  - env classification → `env-unverified`: output matches connection refused / `ECONNREFUSED` / `getaddrinfo` / missing env var / auth to external service / docker not running;
  - always remove every worktree created, including on errors.
- [ ] **Step 6: Write `review-md-template.md`** — a ready-to-copy `REVIEW.md` with sections: `## Stack`, `## Conventions`, `## Blockers` (extra blocker rules), `## Commands` (`install`, `build`, `test`), `## Ignore` (globs), `## Settings` (`comment_language`, `platform: github|gitlab` for self-hosted hosts). Placeholder text in each.
- [ ] **Step 7: Link roles** — add a «Roles» list to `report-format.md` linking all five role files, then run the structure test — Expected: PASS.
- [ ] **Step 8: Commit** `feat(skill): add report format, reviewer roles and checks procedure`

---

### Task 5: Platform reference

**Files:**
- Create: `skills/mr-review/references/platforms.md`
- Test: `tests/skill-structure.test.ts` (links), manual command verification below

**Interfaces:**
- Consumes: comment body format from Task 4, `detect-platform.sh`.
- Produces: per-platform recipes referenced by `SKILL.md`: `auth-check`, `resolve-current`, `metadata`, `is-fork`, `diff`, `existing-skill-comments`, `publish`.

- [ ] **Step 1: Verify current CLI/API syntax** with Context7 / official docs for `gh pr view --json`, `gh api`, `glab mr view -F json`, `glab api` (placeholders `:id`), and the REST payloads below. Record any deviation in the file.
- [ ] **Step 2: Write `platforms.md`** with these pinned choices:
  - auth: `gh auth status` / `glab auth status`; failure → stop and print the login command.
  - current branch MR: `gh pr view --json number` / `glab mr view -F json` (no MR → local branch mode).
  - metadata: GitHub `gh pr view <n> --json number,title,baseRefName,headRefName,headRefOid,isCrossRepository,url`; GitLab `glab mr view <n> -F json` → `iid,title,target_branch,source_branch,sha,diff_refs,source_project_id,target_project_id,web_url`. Fork = `isCrossRepository` / `source_project_id != target_project_id`.
  - diff: from the worktree, `git diff <merge-base(origin/<target>, HEAD)>...HEAD` — same for both platforms and local mode.
  - publish GitHub: one `POST repos/{owner}/{repo}/pulls/{n}/reviews` via `gh api --input <json>` with `event: "COMMENT"`, `commit_id: headRefOid`, `comments: [{path, line, side: "RIGHT", body}]` (plus `start_line`/`start_side` for ranges); findings without a line or on lines outside the diff go into the review `body`.
  - publish GitLab: per finding `POST projects/:id/merge_requests/<iid>/discussions` with `position[position_type]=text`, `base_sha/start_sha/head_sha` from `diff_refs`, `new_path`, `new_line`; findings without a line or outside the diff → one `POST .../notes`.
  - dedupe: list existing comments (`GET .../pulls/{n}/comments` + review bodies; `GET .../merge_requests/<iid>/discussions`), keep those containing `<!-- mr-review:`; skip a finding when an existing skill comment on the same file says the same thing (semantic match by the agent, not by text equality); report skipped count.
- [ ] **Step 3: Smoke-check** read-only commands on any accessible public repo (e.g. `gh pr view 1 -R cli/cli --json number,title,isCrossRepository`) — Expected: JSON with those keys. No write calls in this task.
- [ ] **Step 4: Run** `bun run test` — Expected: PASS.
- [ ] **Step 5: Commit** `feat(skill): add GitHub and GitLab platform recipes`

---

### Task 6: Orchestrator — `SKILL.md` and `modes.md`

**Files:**
- Create: `skills/mr-review/SKILL.md`, `skills/mr-review/references/modes.md`
- Modify: `tests/skill-structure.test.ts`

**Interfaces:**
- Consumes: everything from Tasks 1–5.

- [ ] **Step 1: Extend structure test (failing)** — `SKILL.md` has YAML frontmatter with `name: mr-review` and a `description` ≤ 1024 chars that starts with «Use when» and mentions merge request, pull request, `standard`, `hard`, `ultra`; every file in `references/` and `scripts/` is reachable by links from `SKILL.md` (directly or transitively).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Write `SKILL.md`** (target < 200 lines) — flow:
  1. Parse `[MR] [standard|hard|ultra] [--focus <area>]` from the invocation arguments or the user's message.
  2. Preconditions: inside a git repo; `scripts/detect-platform.sh`; `unknown` → `REVIEW.md` `platform`, else ask once and suggest saving it to `REVIEW.md`; auth check from platforms.md. MR link to another repo → ask the user to run inside its clone, stop.
  3. Resolve target: given MR → metadata; none → current-branch MR; none → local branch vs `origin/main` (or `master`), no publish step.
  4. Read `REVIEW.md` if present.
  5. Diff + filtering: drop lockfiles, `dist/`, `build/`, `*.min.*`, `__snapshots__/`, generated markers, and `REVIEW.md` ignore globs; list what was dropped in the report.
  6. Mode: if missing → heuristic from modes.md, propose, wait. `hard`/`ultra` without subagent support → say so and offer `standard`.
  7. Create the MR worktree (`worktree.sh create`); checks per checks.md (fork → confirm first).
  8. Run the mode from modes.md; every subagent gets: diff, file list, worktree path, `REVIEW.md` content, `--focus`, its role file, the contract.
  9. Print the report per report-format.md.
  10. Ask what to publish (`все` = 🔴+🟡 / numbers / `нет`); publish per platforms.md; print links.
  11. Always clean up worktrees.
- [ ] **Step 4: Write `modes.md`**:
  - mode heuristic: changed lines (after filtering) < 100 and only docs/config/styles/tests touched → `standard`; < 800 → `hard`; else `ultra`. Always a proposal.
  - `standard`: single agent, all five role checklists as one pass, runs checks itself; if logic is changed, first line of the report: «MR меняет логику — рекомендую `hard`».
  - `hard`: 3 subagents in parallel — (1) correctness, (2) architecture, (3) tests + security (two role files, runs checks); orchestrator merges duplicates (same file, overlapping lines, same problem → keep the higher severity, list both roles), assigns `F<n>` ids, builds one report.
  - `ultra`: 5 subagents in parallel (correctness, architecture, security, performance, tests-with-checks) → merge duplicates → one debate round: every subagent (author included) receives all merged findings and returns the vote contract → for each finding run `scripts/tally.sh` with its 5 votes → severity = result; `disputed` → ⚖️ line in terminal only; `none` → «Отклонено в споре».
  - huge diff (> 3000 changed lines after filtering): in `hard`/`ultra` each subagent still reviews the full diff from its role; in `standard` recommend `hard` first.
- [ ] **Step 5: Run** `bun run test` — Expected: PASS.
- [ ] **Step 6: Commit** `feat(skill): add mr-review orchestrator and review modes`

---

### Task 7: Behavioural evals

**Files:**
- Create: `evals/make-fixture.sh`, `evals/scenarios.md`, `evals/results/2026-10-16.md` (date of the run)
- Modify: skill files as findings require

**Interfaces:**
- Produces: `make-fixture.sh <dir>` → git repo in `<dir>` with a bare `origin`, zero-dependency Node project (`package.json` scripts `build`: `node build.js`, `test`: `node --test`), branches:
  - `main` — `src/discount.js` (`applyDiscount(price, percent)`), tests, plus one test that **already fails on main** (`test/legacy.test.js`);
  - `logic-bug` — off-by-one / wrong comparison in `applyDiscount` that breaks an existing test, new function `roundPrice` without tests, one badly named variable;
  - `cosmetic` — README and comment wording only;
  - `huge` — `logic-bug` plus a 5000-line `package-lock.json` and `dist/bundle.js`;
  - `env-dependent` — a test that connects to `localhost:5432`.

- [ ] **Step 1: Write `make-fixture.sh`** and run it into `evals/.work/repo` — Expected: `node --test` fails only `legacy` on `main`, fails discount test on `logic-bug`.
- [ ] **Step 2: Write `scenarios.md`** — each scenario: branch, command, expected behaviour (pass/fail checklist):
  - E1 `cosmetic` + `standard` → ✅ verdict, no blockers, `legacy` reported as «падало до MR».
  - E2 `logic-bug` + `standard` → first line recommends `hard`; discount bug as 🔴; `roundPrice` without tests as 🟡.
  - E3 `logic-bug` + `hard` → 3 subagents, merged report, no duplicate findings, 🔴 for the bug.
  - E4 `logic-bug` + `ultra` → 5 subagents + vote, every finding has a final severity; disputed ones show ⚖️; worktrees removed (`git worktree list` has only the main one).
  - E5 repo copy without `package.json` scripts → checks `not-detected`, nothing invented.
  - E6 `huge` + no mode → lockfile and `dist/` listed as dropped; proposes a mode and waits.
  - E7 PATH without `gh` and a github.com remote with an MR number → stops with install/login instruction.
  - E8 `env-dependent` → that test is `env-unverified`, not a blocker.
  - For all: `git status` of the user tree unchanged; nothing published without confirmation (answer `нет`).
- [ ] **Step 3: Run each scenario** in Claude Code: a fresh subagent with the skill available, cwd = fixture repo, given only the command. Record verdict per checklist item in `evals/results/<date>.md`.
- [ ] **Step 4: Fix the skill** for every failed item (closing loopholes in wording, not special-casing the fixture); re-run the failed scenarios until all pass.
- [ ] **Step 5: Publishing check (needs the user):** ask the user for a sandbox GitHub repo (and optionally GitLab) with a test PR; run `hard`, answer `все`, verify inline comments + review body; run again, verify no duplicates. Skip and note in results if the user declines.
- [ ] **Step 6: Commit** `test(evals): add behavioural eval scenarios and fixture`

---

### Task 8: Packaging and docs

**Files:**
- Create: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`, `LICENSE`

- [ ] **Step 1: Verify** the current Claude Code plugin manifest and marketplace schema (official docs) before writing.
- [ ] **Step 2: Write manifests** — plugin `1984-agent`, skill path `skills/mr-review`.
- [ ] **Step 3: Write `README.md`** — what it does, the three modes table, install (Claude Code plugin marketplace; manual copy of `skills/mr-review` into `~/.claude/skills/` or the agent's skills dir for Codex/Cursor), requirements (`git`, `gh` and/or `glab`), `REVIEW.md` how-to linking the template, safety guarantees (no posting without confirmation, worktree isolation, fork confirmation).
- [ ] **Step 4: `LICENSE`** — MIT, copyright Ruslan Rogatkin 2026.
- [ ] **Step 5: Verify** `claude plugin validate .` (if available in the installed version) and `bun run test` — Expected: PASS.
- [ ] **Step 6: Commit** `docs: add README, license and plugin manifests`
