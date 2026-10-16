#!/bin/sh
# Filtered diff of HEAD against a base, so every agent reviews the same files.
#
# Usage (inside the MR worktree): diff.sh <base-ref> [ignore-glob...]
#   ignore globs come from REVIEW.md → Ignore; `*` also matches `/`.
#
# Writes the diff of the kept files to the worktree's git admin dir (never into
# the working tree) and prints:
#   diff: <path>
#   files: <kept file count>
#   changed: <added + deleted lines in kept files>
#   skipped: <file> (<reason>)      one line per skipped file
#
# Skipped: lockfiles, build output, minified files, snapshots, generated files
# (linguist-generated attribute, or "@generated" / "DO NOT EDIT" in the first 5
# lines), REVIEW.md ignore globs, and files with more than 1000 changed lines.
set -eu

max_lines=1000

[ $# -ge 1 ] || { echo "usage: diff.sh <base-ref> [ignore-glob...]" >&2; exit 2; }
base=$1
shift
git rev-parse -q --verify "$base^{commit}" >/dev/null || { echo "diff.sh: unknown base '$base'" >&2; exit 1; }

# Prints the reason a file is skipped, or nothing when it is reviewed.
skip_reason() {
  file=$1 changed=$2
  shift 2
  name=${file##*/}
  case "$name" in
    package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|bun.lock|bun.lockb|\
    poetry.lock|uv.lock|Pipfile.lock|Cargo.lock|go.sum|composer.lock|Gemfile.lock)
      echo lockfile; return ;;
    *.min.js|*.min.css|*.map) echo minified; return ;;
    *.snap) echo snapshot; return ;;
  esac
  case "/$file" in
    */dist/*|*/build/*|*/out/*|*/.next/*|*/coverage/*|*/vendor/*|*/node_modules/*)
      echo "build output"; return ;;
    */__snapshots__/*) echo snapshot; return ;;
  esac
  for glob in "$@"; do
    # shellcheck disable=SC2254 — the glob is meant to be expanded as a pattern
    case "$file" in $glob) echo "ignored by REVIEW.md"; return ;; esac
  done
  if [ "$(git check-attr linguist-generated -- "$file" | sed 's/.*: //')" = "true" ] \
    || git show "HEAD:$file" 2>/dev/null | head -n 5 | grep -qE '@generated|DO NOT EDIT'; then
    echo generated; return
  fi
  if [ "$changed" -gt "$max_lines" ]; then
    echo "too large: $changed changed lines"; return
  fi
}

out="$(git rev-parse --absolute-git-dir)/mr-review.diff"
list="$out.files"
: > "$list"
files=0 total=0

git -c core.quotePath=false diff --no-renames --numstat "$base" HEAD > "$out.numstat"
while IFS="$(printf '\t')" read -r added deleted file; do
  # Binary files show "-" instead of counts.
  case "$added" in -) added=0 ;; esac
  case "$deleted" in -) deleted=0 ;; esac
  changed=$((added + deleted))
  reason=$(skip_reason "$file" "$changed" "$@")
  if [ -n "$reason" ]; then
    echo "skipped: $file ($reason)"
  else
    echo "$file" >> "$list"
    files=$((files + 1))
    total=$((total + changed))
  fi
done < "$out.numstat"

# Rebuild the argument list from the kept files to diff exactly those.
set --
while IFS= read -r file; do set -- "$@" "$file"; done < "$list"
if [ $# -gt 0 ]; then
  git --literal-pathspecs -c core.quotePath=false diff --no-renames "$base" HEAD -- "$@" > "$out"
else
  : > "$out"
fi
rm -f "$list" "$out.numstat"

echo "diff: $out"
echo "files: $files"
echo "changed: $total"
