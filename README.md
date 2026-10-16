# 1984-agent

Agent skills for team workflows. Currently: **mr-review**: a single, team-wide
standard for reviewing and testing GitLab merge requests and GitHub pull requests.

## mr-review

```
/mr-review [MR] [standard|hard|ultra] [--focus <area>]
```

No more re-explaining the context for every review. The command picks the MR, the
depth and the review areas, runs the project's existing build and tests, and
prints one report in a fixed format. It posts comments to the MR only after
you confirm.

| Mode | How it works | For |
|---|---|---|
| `standard` | One agent goes through the whole diff | Small changes that do not touch logic |
| `hard` | 3 subagents (correctness · architecture · tests + security), merged report | Regular feature MRs |
| `ultra` | 5 subagents (+ security, performance), then one voting round; the majority sets each finding's severity | Risky or large MRs |

Every finding states **why** it is a problem, **why** it has its severity
(🔴 blocker · 🟡 should fix · ⚪ nit), and **1–3 ways to fix it** with tradeoffs.

### Guarantees

- **Your working tree is never touched.** The MR code runs in a temporary `git worktree`, which is removed afterwards.
- **Only failures caused by the MR are blockers.** A test that also fails on the target branch is reported as pre-existing. A failure from a missing DB, secret or network is reported as "not verified".
- **MRs from forks:** the commands are shown before any of the fork's code runs, and nothing runs until you confirm.
- **Nothing is posted without an explicit answer.** You choose `all` / finding numbers / `no`. Re-runs do not duplicate earlier comments.

### Requirements

- `git`, plus `gh` (GitHub) and/or `glab` (GitLab), logged in.
- `hard` and `ultra` need an agent with subagents: Claude Code, Codex, Cursor, … `standard` works everywhere.

### Install

**Claude Code (plugin):**

```
/plugin marketplace add tru3ty/1984-agent
/plugin install 1984-agent@1984-agent
```

**Any agent supporting Agent Skills:** copy `skills/mr-review` into the agent's skills folder, e.g.
`~/.claude/skills/mr-review` (Claude Code) or `~/.agents/skills/mr-review` (Codex and other agents).

### Team rules: `REVIEW.md`

Put a `REVIEW.md` in the repository root to give every review the same context:
stack, conventions, extra blocker rules, build/test commands, ignored paths and
the language of MR comments. Start from
[the template](skills/mr-review/references/review-md-template.md).

## Development

```sh
bun install
bun run test                                  # script unit tests + skill structure checks
sh evals/setup-scenario.sh E2 evals/.work/E2   # behavioural eval fixture, see evals/scenarios.md
```

## License

MIT
