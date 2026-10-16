# mr-review eval scenarios

Behavioural checks of the skill. Each scenario runs in a fresh fixture:

```sh
sh evals/setup-scenario.sh <E#> evals/.work/<E#>   # prints the repo path
```

Run each in a fresh agent that has only the skill and the command (prompt
template at the bottom). Record pass/fail per item in `evals/results/<date>.md`.

**Every scenario also checks:** the user's tree is unchanged (`git status`
clean, same branch), `git worktree list` shows only the main tree at the end,
nothing is published.

## E1 — cosmetic change, `standard`
Branch `cosmetic`. Command: `/mr-review standard`.
- [ ] Verdict ✅, no 🔴 findings.
- [ ] `legacy` test reported as pre-existing, not a blocker.
- [ ] Report follows the layout in `report-format.md` (verdict, checks line, sections).

## E2 — logic change in `standard`
Branch `logic-bug`. Command: `/mr-review standard`.
- [ ] First report line recommends `hard`.
- [ ] `>= 100` reported as 🔴 with the failing test named.
- [ ] `roundPrice` without tests reported as 🟡.
- [ ] Every finding has why, severity reason, 1–3 fixes with tradeoffs.

## E3 — `hard`
Branch `logic-bug`. Command: `/mr-review hard`.
- [ ] Three reviewer subagents (correctness / architecture / tests+security).
- [ ] No duplicate findings for the same problem.
- [ ] 🔴 for `>= 100`; checks line shows `tests failed (new)` + 1 pre-existing.

## E4 — `ultra`
Branch `logic-bug`. Command: `/mr-review ultra`.
- [ ] Five reviewers, then one voting round on the merged list.
- [ ] Final severities come from `tally.sh`; disputed ones show ⚖️ with counts.
- [ ] Findings voted `none` by the majority are under "Rejected in debate".

## E5 — no test/build commands
Branch `logic-bug` with npm scripts removed. Command: `/mr-review standard`.
- [ ] Checks are `not-detected`; no invented command (`npm test`, `node --test`) is run.

## E6 — huge diff, no mode
Branch `huge`. Command: `/mr-review`.
- [ ] `package-lock.json` and `dist/bundle.js` listed as skipped.
- [ ] Proposes a mode from the filtered size and waits (prepared answer: stop).

## E7 — GitHub without auth
Branch `logic-bug`, origin `git@github.com:acme-fixture/shop-pricing.git`, a fake
`gh` that fails auth. Command: `/mr-review 5 hard`.
- [ ] Stops before reviewing and tells the user to run `gh auth login`.
- [ ] Does not review the local branch instead.

## E8 — environment failure
Branch `env-dependent`. Command: `/mr-review standard`.
- [ ] The `DATABASE_URL` test is `env-unverified`, not a blocker; verdict is not ❌ because of it.

## Prompt template

```
You are a coding agent. The skill "mr-review" is installed at <SKILL_DIR>.
Read <SKILL_DIR>/SKILL.md first and follow it exactly; read the files it links when it says so.
Work only inside the repository <REPO> (use it as the working directory).
<EXTRA_ENV>
The user typed: <COMMAND>
The user is not available. Prepared answers: <ANSWERS>
When the skill tells you to ask the user, write the exact question you would ask, then use the prepared answer.
Finish with your final output to the user, then a block "META": questions you asked, subagents you started
(role + count), every command that changed git state, and the final `git status -sb` and `git worktree list`.
```
