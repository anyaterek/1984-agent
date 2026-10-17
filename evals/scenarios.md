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
- [ ] Three reviewer subagents (correctness+intent / architecture / tests+security).
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

## E9 — small risky change, no mode
Branch `ci-risky` (5 lines in `.gitlab-ci.yml` only). Command: `/mr-review`.
- [ ] `diff.sh` output has `risky: .gitlab-ci.yml (ci)`.
- [ ] Proposes at least `hard`, naming the `ci` reason, although the diff is under 100 lines; waits (prepared answer: stop).

## E10 — behaviour explained outside the diff
Branch `explained`. Command: `/mr-review standard`.
- [ ] Project context includes `REVIEW.md` → `Context` (`docs/**`), read from `origin/main`.
- [ ] No finding asks to round instead of floor in `floorCents` (docs/pricing.md R-1 explains it).
- [ ] Every finding has a non-empty `Evidence:` line.

## E11 — impact sets the colour
Branch `edge-gaps`. Command: `/mr-review standard`.
- [ ] `validateQuantity(0)` being accepted is reported with the R-2 quote from docs/pricing.md next to `src/quantity.js:3` (or a reproduction) in `Evidence:` — 🟡 with "no caller yet", since nothing calls it (🔴 only if the reviewer shows a caller).
- [ ] 🟡, not ⚪, for the untested upper bound 99 (or lower bound 1).
- [ ] ⚪ only for preference findings (e.g. the parameter name `q`); nothing cosmetic is 🔴.

## E12 — library and runtime API against the docs of the version in use
Branch `api-usage`. Command: `/mr-review standard`.
- [ ] `diff.sh` output has `manifest: package.json (lockfile: none)`.
- [ ] A finding on the legacy `url.parse()` is 🟡 (hardening, not a demonstrated break) with a Node docs link and the version `>=22` from `engines` in `Evidence:` — or, without network, 🟡 with "not verified against docs".
- [ ] The reviewer's own `node --version` is not used as the project's version.

## E13 — clean code that does not do what the task asks
Branch `off-spec` (`cartTotal` for `docs/tasks/T-7.md`; tests green). Command: `/mr-review hard`.
- [ ] Three subagents; the first one gets both the correctness and the intent role files.
- [ ] A finding that the total is not floored to cents, quoting T-7 / R-1 next to `src/cart.js`.
- [ ] A finding that an empty cart returns 0 instead of `RangeError`, quoting T-7; the test "an empty cart costs nothing" named as pinning the wrong behaviour.
- [ ] Neither is 🔴 while nothing calls `cartTotal` ("no caller yet"), unless the reviewer shows a caller.

## E14 — two key journeys, no mode
Branch `two-journeys` (one small file in `src/checkout/` and one in `src/orders/`; `REVIEW.md` on `main` maps them to the journeys `checkout` and `ordering`). Command: `/mr-review`.
- [ ] `diff.sh` is called with `--journey 'checkout=src/checkout/*' --journey 'ordering=src/orders/*'` and prints `journey: checkout (1 files)` and `journey: ordering (1 files)`.
- [ ] Proposes `ultra`, naming both journeys, although the diff is under 100 lines and touches no risky path; waits (prepared answer: stop).

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
