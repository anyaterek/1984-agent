# Platforms: GitHub and GitLab

Detect the platform with `sh <skill>/scripts/detect-platform.sh` (see
[detect-platform.sh](../scripts/detect-platform.sh)). On `unknown` use
`platform:` from `REVIEW.md`; if that is missing, ask the user once and suggest
adding it to `REVIEW.md`.

**Remote.** Scripts use the `origin` remote. If `origin` is your fork and the
MR lives in another remote (often `upstream`), set `MR_REVIEW_REMOTE=<that remote>`
for every script call, and pass `-R <owner>/<repo>` to `gh`/`glab`.

All write calls send a JSON file with `--input` — write the payload to a temp
file first; never build JSON with string concatenation in the shell.

## Recipes

| Step | GitHub (`gh`) | GitLab (`glab`) |
|---|---|---|
| Auth check | `gh auth status` | `glab auth status` |
| Fix if it fails | `gh auth login` | `glab auth login` |
| MR of current branch | `gh pr view --json number` | `glab mr view -F json` → `iid` |
| Metadata | `gh pr view <n> --json number,title,body,url,baseRefName,headRefName,headRefOid,isCrossRepository` | `glab mr view <n> -F json` → `iid,title,description,web_url,target_branch,source_branch,sha,diff_refs,source_project_id,target_project_id` |
| From a fork? | `isCrossRepository == true` | `source_project_id != target_project_id` |
| Checkout spec for [worktree.sh](../scripts/worktree.sh) | `pr:<n>` | `mr:<n>` |

CLI missing or auth failing → stop and tell the user the exact command to run
(install `gh`/`glab`, then the login command). Do not fall back to guessing the diff.

## Diff

Same for both platforms and for local-branch mode: `diff.sh` inside the MR
worktree (SKILL.md step 6). Inline comments may only point at lines that are
inside a hunk of that diff.

## Existing comments from earlier runs

Skill comments end with `<!-- mr-review:role=<role> -->`. Before publishing,
fetch them and drop every new finding that an existing skill comment on the
same file already raises (same problem, even if worded differently). Report how
many were skipped.

- GitHub: `gh api --paginate repos/{owner}/{repo}/pulls/<n>/comments` and `gh api --paginate repos/{owner}/{repo}/pulls/<n>/reviews` (review bodies).
- GitLab: `glab api --paginate projects/:id/merge_requests/<iid>/discussions`.

## Publish — GitHub

One review per run, never `APPROVE` or `REQUEST_CHANGES`:

```sh
gh api --method POST repos/{owner}/{repo}/pulls/<n>/reviews --input review.json
```

```json
{
  "commit_id": "<headRefOid>",
  "event": "COMMENT",
  "body": "<summary line + findings that cannot be inline>",
  "comments": [
    { "path": "src/a.ts", "line": 42, "side": "RIGHT", "body": "<comment body>" },
    { "path": "src/b.ts", "start_line": 10, "start_side": "RIGHT", "line": 14, "side": "RIGHT", "body": "<comment body>" }
  ]
}
```

Before sending, check every inline comment against the hunks of
`git diff <base> HEAD -- <file>`: its `line` (and `start_line`) must be a `+`
or context line of the same hunk. Everything else (`line: null`, lines outside
hunks, deleted files) goes into `body`. Omit `start_line` when it equals `line`.
If GitHub still answers 422 (it does not say which comment failed),
move all inline comments into `body` and send once more.

## Publish — GitLab

Take `base_sha`, `start_sha`, `head_sha` from `diff_refs`. One thread per finding:

```sh
glab api --method POST -H 'Content-Type: application/json' \
  projects/:id/merge_requests/<iid>/discussions --input thread.json
```

```json
{
  "body": "<comment body>",
  "position": {
    "position_type": "text",
    "base_sha": "<diff_refs.base_sha>",
    "start_sha": "<diff_refs.start_sha>",
    "head_sha": "<diff_refs.head_sha>",
    "old_path": "src/a.ts",
    "new_path": "src/a.ts",
    "new_line": 42
  }
}
```

- Added line: `new_line` only. Unchanged (context) line: both `old_line` and `new_line`.
- Findings that cannot be inline go into one general note:
  `glab api --method POST -H 'Content-Type: application/json' projects/:id/merge_requests/<iid>/notes --input note.json` with `{ "body": "…" }`.
- If a thread is rejected for its position, post that finding in the general note instead.

## After publishing

Print the MR link and how many comments were posted inline, in the general
comment, and skipped as duplicates.
