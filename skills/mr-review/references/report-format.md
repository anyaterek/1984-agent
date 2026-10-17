# Report format

Every mode produces findings in one shape, one severity scale and one report
layout. Write the report and MR comments in the user's conversation language
(or `comment_language` from `REVIEW.md` for comments); the templates below show
the structure, translate the labels.

## Severity scale

| Token | Shown as | Use when |
|---|---|---|
| `blocker` | 🔴 Blocker | Security or personal data; data loss or corruption; a business rule from the spec or a contract is broken; a core user flow does not work; build, tests or deploy fail **because of this MR**; a blocker rule from `REVIEW.md` is hit |
| `major` | 🟡 Should fix | A defect with limited impact (a secondary flow, a workaround exists, a visible error that corrupts nothing); changed logic or an edge case of it without a test; structure, readability, convention violations |
| `minor` | ⚪ Nit | Cosmetics that neither block work nor mislead (a border, spacing, a colour); style, naming, taste |
| `none` | ✖ Not a problem | Vote-only (ultra debate) |

Two separate questions decide the level:

1. **Impact sets the colour** — the table above: what breaks, not how sure you
   are. A core user flow is one without which the user cannot reach their goal;
   `REVIEW.md` → `Blockers` may list the project's own. A wrong border that
   reproduces every time is still `minor`; the same border covering the submit
   button is `blocker`. The impact must be reachable today: code that nothing
   calls yet (no caller, route, job or public entry point in the codebase)
   breaks nothing yet → at most `major`, with "no caller yet" in
   `severityReason`.
2. **Proof can only lower it.** `blocker` needs the impact shown in `evidence`
   by one of: a reproduction (a throwaway test or script run in the worktree,
   with its output), an existing test or build that fails, or the exact quote of
   the spec or contract rule next to the `path:line` that breaks it. Otherwise
   at most `major`, with "not demonstrated" in `severityReason`. Proof never
   raises a finding above its impact.

Also: a scenario that the spec or `REVIEW.md` explicitly rules out → at most
`major`, with that exclusion named; an edge case of the changed logic without a
test is `major`, never `minor`.

Environment failures (missing DB, secrets, network) and failures that already
happen on the target branch are **not** findings by themselves — they go to
the checks line (see [checks.md](checks.md)). The quality of a test or setup
that needs the environment can still be a finding.

## Finding contract (what every reviewer returns)

**Before you report** each finding, check it against the code outside the
diff: the owning folder, the callers, an analogous implementation, the nearby
tests, and the project context from your brief (read from the target branch).
If code or a document refutes the finding — the behaviour is intended, handled
elsewhere, or already tested — do not return it. "Looks intended" without a
`path:line` does not refute anything.

**Library, framework and runtime APIs.** A finding that calls a use wrong,
deprecated or not idiomatic needs, in `evidence`, a docs link and the version
in use: libraries from the lockfile in the `manifest:` line (or the manifest
if there is none), runtimes from `engines`, `.nvmrc`, `.node-version`,
`.tool-versions`, `requires-python`, the `go` directive or `rust-toolchain`.
The version on your own machine is not the project's. Not verified → at most
`major`, with "not verified against docs" in `severityReason`; a pure
preference without a source → `minor` or no finding. A vulnerable dependency
needs the advisory link and the affected version.

One fenced `json` block with an array; nothing else is parsed.

```json
[
  {
    "role": "correctness",
    "severity": "blocker",
    "file": "src/discount.js",
    "line": 3,
    "endLine": null,
    "title": "100% discount now throws",
    "why": "`percent >= 100` rejects 100, so applyDiscount(50, 100) throws RangeError; the existing test '100% discount makes the price zero' fails.",
    "evidence": "Existing test fails: test/discount.test.js:6 '100% discount makes the price zero' — applyDiscount(50, 100) throws RangeError, expected 0.",
    "severityReason": "Breaks a pricing rule and a passing test; shown by the failing test → blocker.",
    "fixes": [
      { "option": "Restore `percent > 100`.", "tradeoff": "None; matches the error message 0..100." },
      { "option": "If 100% must be forbidden, change the message and the test, and say so in the MR.", "tradeoff": "Behaviour change for callers." }
    ]
  }
]
```

- `line`/`endLine`: line numbers in the **new** version of the file; `line: null` when the finding is about the whole file or MR.
- `why`: a concrete scenario — input, what happens, what breaks. Not "this is bad".
- `evidence`: what makes the finding actionable — `path:line` of a repository
  rule, an analogous implementation, a contract, a spec or a test, a docs link
  with the version, or the reproducible scenario. Required; an empty
  `evidence` means there is no finding.
- `severityReason`: which row of the scale applies and why.
- `fixes`: 1–3 options, first is the recommended one, each with its tradeoff.
- An empty array `[]` means "nothing found in my area".

The `tests` role returns a second fenced block tagged `checks` after the json:

```checks
build: passed
tests: failed (new) — test/discount.test.js "100% discount makes the price zero"
pre-existing: test/legacy.test.js "legacy format keeps two decimals"
log: <at most 40 relevant lines>
```

Statuses are the ones from [checks.md](checks.md).

## Vote contract (ultra debate)

```json
[{ "id": "F3", "vote": "major", "reason": "One sentence." }]
```

## Terminal report

Numbering is continuous across sections — the user picks findings to publish by these numbers.

```
[This MR touches key journeys (<names>) and domains (<names>) — `<mode>` is recommended.]   ← when the chosen mode is below what journeys and domains ask for
[This MR touches risky paths (<reasons>) — `hard` is recommended.]   ← only in standard with risky paths
[This MR changes logic — `hard` is recommended.]                     ← only in standard when logic changed
MR-review: <!iid | #number | branch> «<title>» — mode <mode>
Verdict: ❌ Blockers found | ⚠️ Needs fixes | ✅ Ready to merge
Checks: build <status> · tests <status> · pre-existing failures: <n> · not verified: <reason or —>
Skipped from review: <lockfiles, dist/, … or —>
Risky paths: <reason: files, … or —>

🔴 Blockers
1. `src/discount.js:3` — 100% discount now throws
   Why: …
   Evidence: …
   Severity: …
   ⚖️ disputed: 🔴3 🟡1 ⚪0 ✖1          ← ultra only, only when not unanimous
   Fixes:
   a) (recommended) … — tradeoff: …
   b) … — tradeoff: …

🟡 Should fix
2. …

⚪ Nits
3. …

Rejected in debate (ultra only): <one line per finding: title — majority reason>
```

Verdict: any blocker → ❌; else any `major` → ⚠️; else ✅. A ✅ whose build or
tests are `not-run`, `not-detected` or `env-unverified` reads
"✅ No findings — checks not verified: <which>", never plain "Ready to merge".
If `REVIEW.md` is absent, add one last line suggesting to create it from
[review-md-template.md](review-md-template.md).

## MR comment body

```
**🔴 Blocker** — 100% discount now throws

**Why:** …

**Evidence:** …

**Severity:** …

**Fixes:**
1. (recommended) … — *tradeoff:* …
2. … — *tradeoff:* …

<!-- mr-review:role=correctness -->
```

The ⚖️ dispute line never goes into a comment; the severity reason does.

## Roles

Reviewer roles and what each one owns:
[correctness](roles/correctness.md) ·
[intent](roles/intent.md) ·
[architecture](roles/architecture.md) ·
[security](roles/security.md) ·
[performance](roles/performance.md) ·
[tests](roles/tests.md)
