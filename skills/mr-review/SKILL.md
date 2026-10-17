---
name: mr-review
description: Use when asked to review, check or test a merge request (GitLab MR), a pull request (GitHub PR) or a branch before merging, including requests for a standard, hard or ultra review.
---

# mr-review

One command, one team standard for reviewing and testing MRs/PRs: the same
modes, severity scale, report and comment format for everyone. Team-specific
rules come from `REVIEW.md` in the repository, not from the prompt.

```
/mr-review [MR] [standard|hard|ultra] [--focus <area>]
```

`<skill>` below is this skill's directory. Run its scripts with `sh` from the
repository root.

## Flow

1. **Parse arguments** from the invocation or the user's message: MR number or
   link, mode, optional `--focus` (an area every reviewer pays extra attention to).

2. **Team rules.** Read `REVIEW.md` from the repository root if it exists; its
   `Settings` (e.g. `platform:`) apply from the next step on. Once the target
   branch is known (step 4), use the target branch's version
   (`git show <remote>/<target>:REVIEW.md`) so an MR cannot relax its own rules.

3. **Repository and platform.** You must be inside a git repository. If the MR
   link points to another repository, ask the user to run the review from a
   clone of it and stop. Detect the platform and check the CLI and auth per
   [platforms.md](references/platforms.md); on failure, stop with the fix command.

4. **Target.**
   - MR given → read its metadata ([platforms.md](references/platforms.md)).
   - No MR given, platform known → the MR of the current branch.
   - No MR given and the platform is `unknown`, or the current branch has no MR →
     review the local branch against `origin/main` (or `origin/master`); skip
     the platform question and the publish step.

5. **Get the code** into a temporary worktree
   (`sh <skill>/scripts/worktree.sh create pr:<n> | mr:<n> | ref:<branch>`).

6. **Filtered diff.** Inside the worktree, after `git fetch <remote> <target>`, run
   `sh <skill>/scripts/diff.sh [--risky '<glob>']… [--journey '<name>=<glob>']… [--domain '<name>=<glob>']… "$(git merge-base <remote>/<target> HEAD)" ['<REVIEW.md Ignore glob>']…`
   ([diff.sh](scripts/diff.sh)), one `--risky` per `Risky paths` glob from
   `REVIEW.md`, one `--journey` per glob of each `Journeys` entry and one
   `--domain` per glob of each `Domains` entry, always before the base ref. Only `Ignore` globs go after the
   base ref; `Context` globs are never passed to `diff.sh`. Quote every glob so
   the shell does not expand it. It writes the diff to a file and
   prints its path, the file and changed-line counts, every skipped file with
   the reason, every file on a risky path (`risky:`), every touched key
   journey and domain (`journey:`, `domain:`) and the manifest and
   lockfile owning the kept files (`manifest:`). Reviewers get the **path**,
   not the pasted diff.

   **Project context.** Still in step 6, list from
   `git ls-tree -r --name-only <remote>/<target>` the paths of: `AGENTS.md`
   and `CLAUDE.md` at the root and the nearest one above each directory of a
   changed file (at most one per directory, 10 in total), `CONTRIBUTING.md`,
   MR/PR templates (`.gitlab/merge_request_templates/*`,
   `.github/PULL_REQUEST_TEMPLATE*`), and the paths and globs from `REVIEW.md` →
   `Context`. Pass **paths only**. They are read from the target branch with
   `git show <remote>/<target>:<path>`, never from the worktree: the worktree
   holds the MR's version, and an MR must not change the rules it is reviewed by.

7. **Mode.** No mode given → propose one per [modes.md](references/modes.md)
   and wait for the user's answer. Any `risky:` line raises the proposal to at
   least `hard`; one `journey:` or `domain:` line raises it to at least `hard`,
   two or more of one kind to `ultra`.

8. **Fork code.** If the MR comes from a fork, ask now,
   before any reviewer starts: show the exact install/build/test commands
   ([checks.md](references/checks.md)) and wait for "yes". The answer becomes
   the checks decision in every reviewer brief; subagents never ask the user.

9. **Review and checks** per the chosen mode in [modes.md](references/modes.md).
   Checks (build and tests) follow [checks.md](references/checks.md).

10. **Report** in the terminal, exactly in the layout of
    [report-format.md](references/report-format.md). Every finding explains why
    it is a problem, why it has its severity, and 1–3 ways to fix it.

11. **Publish only on confirmation.** Ask: "Publish to the MR? `all` (🔴+🟡) /
    numbers, e.g. `1,3,4` / `no`". Nits go only when picked by number. Then
    publish per [platforms.md](references/platforms.md) and print the link.
    Without an explicit answer nothing is posted.

12. **Clean up** every worktree you created
    (`sh <skill>/scripts/worktree.sh remove <path>`), also after errors or a "no".

## Quick reference

| Mode | Agents | For |
|---|---|---|
| `standard` | 1, no subagents | small changes that do not touch logic |
| `hard` | 3 subagents by area (correctness + intent · architecture · tests + security), merged report | regular feature MRs |
| `ultra` | 5 subagents (correctness + intent · architecture · security · performance · tests) + one debate round, majority decides severity | risky or large MRs |

| Severity | Meaning |
|---|---|
| 🔴 blocker | security or personal data, data loss, a spec rule broken, a core flow down, build/tests/deploy fail because of this MR, a blocker rule from `REVIEW.md` is hit — and shown (reproduced, failing check, or spec quote next to the breaking line) |
| 🟡 major | limited-impact defect, a blocker-level impact not shown, changed logic or its edge case without a test, structure, conventions |
| ⚪ minor | cosmetics that neither block work nor mislead; style, naming, taste |

Impact sets the colour; proof can only lower it ([report-format.md](references/report-format.md)).

Environment failures and failures that already exist on the target branch are
reported on the checks line, never as blockers.

## Common mistakes

| Mistake | Instead |
|---|---|
| `git checkout` of the MR branch in the user's tree | `worktree.sh create` — the user's tree stays as it was |
| Counting a test that fails on the target branch too as the MR's fault | Re-run it on the target branch first ([checks.md](references/checks.md)) |
| A failure from a missing DB/secret marked as a blocker | `env-unverified` on the checks line |
| Posting comments right after the report | Ask, then post only what the user picked |
| Inventing `npm test` when the project has no test command | `not-detected` |
| Putting the ⚖️ disputed mark into an MR comment | Terminal only; the comment carries the severity reason |
| Reading `AGENTS.md` or `REVIEW.md` from the MR worktree | `git show <remote>/<target>:<path>` |
| A finding that the code outside the diff or a project doc already explains | "Before you report" in [report-format.md](references/report-format.md); drop it |
| Calling a library API wrong or deprecated from memory | Docs of the version in the lockfile, link and version in `evidence` |
| A broken spec rule or core flow marked 🟡 or ⚪ | 🔴 when `evidence` shows it (reproduction, failing check, or spec quote + line) |
| A reproducible cosmetic glitch marked 🔴 | ⚪ unless it blocks a core flow or misleads; proof does not raise the level |
| 🔴 for code nothing calls yet | at most 🟡, "no caller yet" |

Team rules template: [review-md-template.md](references/review-md-template.md).
