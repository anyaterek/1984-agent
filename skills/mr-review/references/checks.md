# Checks: build and tests

Run the project's **existing** build and tests on the MR code. Never write or
change tests, never modify lockfiles, never touch the user's working tree.

`<skill>` below is this skill's directory. Run the scripts with `sh` from the
repository root (they use the repository's git state).

## 1. Get the code

If your brief gives you a worktree path, use it: do not create or remove it,
other reviewers are reading it. Otherwise create one:

```sh
sh <skill>/scripts/worktree.sh create pr:<n>      # GitHub PR
sh <skill>/scripts/worktree.sh create mr:<n>      # GitLab MR
sh <skill>/scripts/worktree.sh create ref:<branch> # local branch mode
```

The script prints the worktree path; run everything below inside it.
[worktree.sh](../scripts/worktree.sh) replaces a leftover from an earlier run by itself.

**MR from a fork:** the orchestrating agent asks before any reviewer starts
(SKILL.md step 8): it shows the user the exact install/build/test commands and
waits for "yes". On "no" every check is `not-run` and the review continues on
the diff alone. A subagent never asks the user — it follows the checks decision
in its brief.

## 2. Install dependencies

Use `REVIEW.md` → `Commands` → `install` if set. Otherwise by lockfile, always frozen:

| Lockfile | Command |
|---|---|
| `bun.lock`, `bun.lockb` | `bun install --frozen-lockfile` |
| `pnpm-lock.yaml` | `pnpm install --frozen-lockfile` |
| `yarn.lock` | `yarn install --immutable` (Yarn 2+) / `yarn install --frozen-lockfile` (Yarn 1) |
| `package-lock.json` | `npm ci` |
| `uv.lock` | `uv sync --frozen` |
| `poetry.lock` | `poetry install --no-root` |
| `go.mod` | `go mod download` |
| `Cargo.lock` | — (cargo fetches on build) |

No lockfile and no declared dependencies → skip install.

## 3. Find build and test commands

First match wins, per command:

1. `REVIEW.md` → `Commands` → `build` / `test`.
2. `package.json` scripts `build` / `test`, run with the package manager from step 2.
   The npm placeholder (`echo "Error: no test specified" && exit 1`) counts as no command.
3. `Makefile` targets `build` / `test`.
4. `pyproject.toml` → `pytest` only if pytest is configured there (`[tool.pytest…]` or a pytest dependency); `go.mod` → `go build ./...` / `go test ./...`; `Cargo.toml` → `cargo build` / `cargo test`.

Nothing found → that check is `not-detected`. Do not guess a command.

Each command gets a 10-minute timeout.

## 4. Classify failures

For every failing command, in this order:

1. **Environment?** The output shows a missing service or setting — connection
   refused / `ECONNREFUSED`, `getaddrinfo`/DNS errors, a missing env var
   (`… is not set`, `KeyError: 'DATABASE_URL'`), auth to an external service,
   Docker not running → `env-unverified`, with the reason. Not a blocker.
2. **Pre-existing?** Create a baseline worktree for the target branch
   (`sh <skill>/scripts/worktree.sh create ref:origin/<target>`), install, run the same
   command. The same tests fail there too → `failed (pre-existing)`. Not a blocker.
3. Otherwise → `failed (new)`: a 🔴 blocker finding that names the failing
   test/step and the changed code that causes it.

A single command can mix these: classify per failing test where the output allows.

## 5. Clean up

Remove every worktree you created (never one you were given), also when
something failed on the way:

```sh
sh <skill>/scripts/worktree.sh remove <path>
```

## Checks result (what you hand back)

For `build` and `tests`, one status each:

`passed` · `failed (new)` · `failed (pre-existing)` · `env-unverified` · `not-run` · `not-detected`

Plus, for anything not `passed`: the command, the failing test names, and at
most 40 lines of the relevant output.
