# Report format

Every mode produces findings in one shape, one severity scale and one report
layout. Write the report and MR comments in the user's conversation language
(or `comment_language` from `REVIEW.md` for comments); the templates below show
the structure, translate the labels.

## Severity scale

| Token | Shown as | Use when |
|---|---|---|
| `blocker` | 🔴 Blocker | The change breaks logic or existing behaviour; build or tests fail **because of this MR**; a blocker rule from `REVIEW.md` is hit |
| `major` | 🟡 Should fix | Structure, readability, changed logic without tests, convention violations |
| `minor` | ⚪ Nit | Style, taste, optional improvements |
| `none` | ✖ Not a problem | Vote-only (ultra debate) |

Environment failures (missing DB, secrets, network) and failures that already
happen on the target branch are **not** findings by themselves — they go to
the checks line (see [checks.md](checks.md)). The quality of a test or setup
that needs the environment can still be a finding.

## Finding contract (what every reviewer returns)

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
    "severityReason": "Breaks existing behaviour and a passing test → blocker.",
    "fixes": [
      { "option": "Restore `percent > 100`.", "tradeoff": "None; matches the error message 0..100." },
      { "option": "If 100% must be forbidden, change the message and the test, and say so in the MR.", "tradeoff": "Behaviour change for callers." }
    ]
  }
]
```

- `line`/`endLine`: line numbers in the **new** version of the file; `line: null` when the finding is about the whole file or MR.
- `why`: a concrete scenario — input, what happens, what breaks. Not "this is bad".
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
MR-review: <!iid | #number | branch> «<title>» — mode <mode>
Verdict: ❌ Blockers found | ⚠️ Needs fixes | ✅ Ready to merge
Checks: build <status> · tests <status> · pre-existing failures: <n> · not verified: <reason or —>
Skipped from review: <lockfiles, dist/, … or —>

🔴 Blockers
1. `src/discount.js:3` — 100% discount now throws
   Why: …
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
[architecture](roles/architecture.md) ·
[security](roles/security.md) ·
[performance](roles/performance.md) ·
[tests](roles/tests.md)
