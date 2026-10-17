#!/bin/sh
# Filtered diff of HEAD against a base, so every agent reviews the same files.
#
# Usage (inside the MR worktree):
#   diff.sh [--risky <glob>]... [--journey <name>=<glob>]... [--domain <name>=<glob>]...
#           <base-ref> [ignore-glob...]
#   ignore globs come from REVIEW.md → Ignore, --risky globs from Risky paths,
#   --journey / --domain pairs from Journeys / Domains; in all of them `*`
#   also matches `/`. Names are trimmed and may hold spaces and any letters.
#
# Writes the diff of the kept files to the worktree's git admin dir (never into
# the working tree) and prints:
#   diff: <path>
#   files: <kept file count>
#   changed: <added + deleted lines in kept files>
#   skipped: <file> (<reason>)      one line per skipped file
#   risky: <file> (<reason>)        one line per changed file on a risky path,
#                                   skipped files included
#   journey: <name> (<n> files)     one line per touched journey, n = changed
#                                   files matching any of its globs (skipped
#                                   files included), in argument order
#   domain: <name> (<n> files)      the same for domains
#   manifest: <path> (lockfile: <path>|none)
#                                   one line per manifest owning a kept file
#
# Skipped: lockfiles, build output, minified files, snapshots, generated files
# (linguist-generated attribute, or "@generated" / "DO NOT EDIT" in the first 5
# lines), REVIEW.md ignore globs, and files with more than 1000 changed lines.
#
# Risky reasons, first match wins:
#   ci           *.gitlab-ci.yml  .gitlab/ci/*  .github/workflows/*
#   deploy       *Dockerfile*  *Containerfile*  *compose*.yml  *compose*.yaml  *deploy*
#   migration    *migrations/*  *migration/*
#   auth         *auth/*
#   review-rules REVIEW.md  AGENTS.md  */AGENTS.md  CLAUDE.md  */CLAUDE.md
#   REVIEW.md    any --risky glob
#
# Manifest: the nearest package.json, pyproject.toml, go.mod, Cargo.toml,
# Gemfile or composer.json above a kept file. Its lockfile is the first one of
# the same ecosystem found next to it, then in each parent up to the root:
#   package.json   pnpm-lock.yaml bun.lock bun.lockb yarn.lock package-lock.json
#   pyproject.toml uv.lock poetry.lock
#   go.mod go.sum · Cargo.toml Cargo.lock · Gemfile Gemfile.lock
#   composer.json composer.lock
set -eu

max_lines=1000

usage() {
  echo "usage: diff.sh [--risky <glob>]... [--journey <name>=<glob>]... [--domain <name>=<glob>]... <base-ref> [ignore-glob...]" >&2
  exit 2
}

trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

# Journey and domain specs, one "<kind><TAB><name><TAB><glob>" per line.
tab=$(printf '\t')
area_specs=""
add_area() {
  case "$2" in *=*) ;; *) echo "diff.sh: $1 needs <name>=<glob>" >&2; usage ;; esac
  name=$(trim "${2%%=*}") glob=$(trim "${2#*=}")
  [ -n "$name" ] && [ -n "$glob" ] || { echo "diff.sh: $1 needs a non-empty <name>=<glob>" >&2; usage; }
  case "$name$glob" in *"$tab"*|*"
"*) echo "diff.sh: $1 must not contain a tab or a newline" >&2; usage ;; esac
  area_specs="$area_specs${1#--}$tab$name$tab$glob
"
}

# Risky globs, one per line (a glob never holds a newline).
risky_globs=""
while [ $# -gt 0 ]; do
  case "$1" in
    --risky)
      [ $# -ge 2 ] && [ -n "$2" ] || { echo "diff.sh: --risky needs a glob" >&2; usage; }
      risky_globs="$risky_globs$2
"
      shift 2 ;;
    --journey|--domain)
      [ $# -ge 2 ] || { echo "diff.sh: $1 needs <name>=<glob>" >&2; usage; }
      add_area "$1" "$2"
      shift 2 ;;
    *) break ;;
  esac
done
[ $# -ge 1 ] || usage
base=$1
shift
for arg in "$@"; do
  case "$arg" in
    --risky|--journey|--domain) echo "diff.sh: $arg must come before <base-ref>" >&2; usage ;;
  esac
done
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

# Prints the risky-path reason of a changed file, or nothing.
risk_reason() {
  file=$1
  case "$file" in
    *.gitlab-ci.yml|.gitlab/ci/*|.github/workflows/*) echo ci; return ;;
    *Dockerfile*|*Containerfile*|*compose*.yml|*compose*.yaml|*deploy*) echo deploy; return ;;
    *migrations/*|*migration/*) echo migration; return ;;
    *auth/*) echo auth; return ;;
    REVIEW.md|AGENTS.md|*/AGENTS.md|CLAUDE.md|*/CLAUDE.md) echo review-rules; return ;;
  esac
  [ -n "$risky_globs" ] || return 0
  printf '%s' "$risky_globs" | while IFS= read -r glob; do
    # shellcheck disable=SC2254 — the glob is meant to be expanded as a pattern
    case "$file" in $glob) echo REVIEW.md; break ;; esac
  done
}

# Reads "T <path>" lines (the HEAD file list) and "D <dir>" lines (kept-file
# directories) and prints one "<manifest> (lockfile: <path>|none)" per owning
# manifest, in first-seen order. The prefix keeps a file name from passing for
# a directory line. One awk pass instead of a git call per probe.
manifest_lines() {
  awk '
    function parent(d) { return d ~ /\// ? substr(d, 1, match(d, /\/[^\/]*$/) - 1) : "." }
    function at(d, n) { return d == "." ? n : d "/" n }
    function lockfile(m,   d, n, i, k) {
      n = m; sub(/.*\//, "", n)
      k = split(locks[n], names, " ")
      for (d = parent(m); ; d = parent(d)) {
        for (i = 1; i <= k; i++) if (at(d, names[i]) in tree) return at(d, names[i])
        if (d == ".") return "none"
      }
    }
    BEGIN {
      nm = split("package.json pyproject.toml go.mod Cargo.toml Gemfile composer.json", manifests, " ")
      locks["package.json"] = "pnpm-lock.yaml bun.lock bun.lockb yarn.lock package-lock.json"
      locks["pyproject.toml"] = "uv.lock poetry.lock"
      locks["go.mod"] = "go.sum"; locks["Cargo.toml"] = "Cargo.lock"
      locks["Gemfile"] = "Gemfile.lock"; locks["composer.json"] = "composer.lock"
    }
    substr($0, 1, 2) == "T " { tree[substr($0, 3)] = 1; next }
    substr($0, 1, 2) != "D " { next }
    {
      for (d = substr($0, 3); ; d = parent(d)) {
        for (i = 1; i <= nm; i++) {
          m = at(d, manifests[i])
          if (m in tree) {
            if (!(m in seen)) { seen[m] = 1; print m " (lockfile: " lockfile(m) ")" }
            next
          }
        }
        if (d == ".") next
      }
    }
  '
}

parent_dir() { case "$1" in */*) echo "${1%/*}" ;; *) echo . ;; esac; }

out="$(git rev-parse --absolute-git-dir)/mr-review.diff"
list="$out.files"
risky="$out.risky"
areas="$out.areas"
: > "$list"
: > "$risky"
: > "$areas"
files=0 total=0

git -c core.quotePath=false diff --no-renames --numstat "$base" HEAD > "$out.numstat"
while IFS="$(printf '\t')" read -r added deleted file; do
  # Binary files show "-" instead of counts.
  case "$added" in -) added=0 ;; esac
  case "$deleted" in -) deleted=0 ;; esac
  changed=$((added + deleted))
  risk=$(risk_reason "$file")
  [ -z "$risk" ] || echo "risky: $file ($risk)" >> "$risky"
  if [ -n "$area_specs" ]; then
    printf '%s' "$area_specs" | while IFS="$tab" read -r kind name glob; do
      # shellcheck disable=SC2254 — the glob is meant to be expanded as a pattern
      case "$file" in $glob) printf '%s\t%s\t%s\n' "$kind" "$name" "$file" ;; esac
    done >> "$areas"
  fi
  reason=$(skip_reason "$file" "$changed" "$@")
  if [ -n "$reason" ]; then
    echo "skipped: $file ($reason)"
  else
    echo "$file" >> "$list"
    files=$((files + 1))
    total=$((total + changed))
  fi
done < "$out.numstat"
cat "$risky"

# Journeys, then domains, each in argument order, with distinct matched files.
{ printf '%s' "$area_specs" | sed "s/^/S$tab/"; sed "s/^/M$tab/" "$areas"; } | awk -F '\t' '
  $1 == "S" { key = $2 FS $3; if (!(key in known)) { known[key] = 1; order[++n] = key }; next }
  $1 == "M" { key = $2 FS $3; if (!((key FS $4) in seen)) { seen[key FS $4] = 1; count[key]++ } }
  END {
    for (pass = 1; pass <= 2; pass++)
      for (i = 1; i <= n; i++) {
        split(order[i], part, FS)
        if (part[1] != (pass == 1 ? "journey" : "domain") || !(order[i] in count)) continue
        print part[1] ": " part[2] " (" count[order[i]] " files)"
      }
  }'

# One manifest line per manifest owning a kept file, in first-seen order.
{
  git -c core.quotePath=false ls-tree -r --name-only HEAD | sed 's/^/T /'
  while IFS= read -r file; do echo "D $(parent_dir "$file")"; done < "$list"
} | manifest_lines > "$out.manifests"

# Rebuild the argument list from the kept files to diff exactly those.
set --
while IFS= read -r file; do set -- "$@" "$file"; done < "$list"
if [ $# -gt 0 ]; then
  git --literal-pathspecs -c core.quotePath=false diff --no-renames "$base" HEAD -- "$@" > "$out"
else
  : > "$out"
fi
rm -f "$list" "$out.numstat" "$risky" "$areas"

echo "diff: $out"
echo "files: $files"
echo "changed: $total"
sed 's/^/manifest: /' "$out.manifests"
rm -f "$out.manifests"
