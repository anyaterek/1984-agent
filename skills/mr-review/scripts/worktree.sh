#!/bin/sh
# Temporary, detached worktrees for running an MR's code without touching the
# user's working tree.
#
# Usage:
#   worktree.sh create <spec>   prints the absolute worktree path
#   worktree.sh remove <path>   removes a worktree made by `create` (idempotent)
#
# <spec>:
#   pr:<n>    GitHub pull request      (fetches refs/pull/<n>/head)
#   mr:<n>    GitLab merge request     (fetches refs/merge-requests/<n>/head)
#   ref:<r>   any git ref; for <remote>/<branch> the branch is fetched first
#
# Remote: $MR_REVIEW_REMOTE (default: origin).
# Worktrees live in ${TMPDIR:-/tmp}/mr-review-<repo>-<spec-slug>; a leftover
# from an interrupted run at that path is replaced.
set -eu

remote=${MR_REVIEW_REMOTE:-origin}
prefix=mr-review-
ref_marker=mr-review-ref

die() { code=$1; shift; echo "worktree.sh: $*" >&2; exit "$code"; }

# Succeeds only for a directory this script could have made: directly inside
# $TMPDIR, named mr-review-*, and not a repository of its own (a worktree has a
# .git file, a real repository has a .git directory). Everything else is refused
# so a wrong path can never reach `rm -rf`.
is_own_dir() {
  real=$(cd "$1" 2>/dev/null && pwd -P) || return 1
  tmp_real=$(cd "${TMPDIR:-/tmp}" && pwd -P)
  case "$real" in
    "$tmp_real/$prefix"*) ;;
    *) return 1 ;;
  esac
  case "${real#"$tmp_real/"}" in */*) return 1 ;; esac
  [ ! -d "$real/.git" ]
}

# Removes the worktree at $1 (if any) plus its directory, and the fetched ref
# recorded in the worktree's admin dir.
drop_worktree() {
  path=$1
  if [ -e "$path" ]; then
    is_own_dir "$path" || die 2 "refusing to remove '$path': not a temporary $prefix* worktree in ${TMPDIR:-/tmp}"
    admin=$(git -C "$path" rev-parse --absolute-git-dir 2>/dev/null) || admin=""
    if [ -n "$admin" ] && [ -f "$admin/$ref_marker" ]; then
      git -C "$path" update-ref -d "$(cat "$admin/$ref_marker")" 2>/dev/null || true
    fi
    git worktree remove --force "$path" 2>/dev/null || rm -rf "$path"
  fi
  git worktree prune
}

create() {
  spec=$1
  repo_root=$(git rev-parse --show-toplevel) || die 2 "not inside a git repository"
  tmp=${TMPDIR:-/tmp}
  slug=$(printf '%s' "$spec" | tr -c 'A-Za-z0-9._' '-')
  # The checksum of the repo path keeps two clones with the same folder name apart.
  repo_id=$(printf '%s' "$repo_root" | cksum | cut -d' ' -f1)
  path="${tmp%/}/$prefix$(basename "$repo_root")-$repo_id-$slug"

  # Drop a leftover first: it owns the ref we are about to fetch into.
  drop_worktree "$path"

  fetched_ref=""
  case "$spec" in
    pr:*[!0-9]*|mr:*[!0-9]*|pr:|mr:) die 2 "invalid number in '$spec'" ;;
    pr:*) fetched_ref="refs/mr-review/pr-${spec#pr:}"; source="refs/pull/${spec#pr:}/head" ;;
    mr:*) fetched_ref="refs/mr-review/mr-${spec#mr:}"; source="refs/merge-requests/${spec#mr:}/head" ;;
    ref:?*) target=${spec#ref:} ;;
    *) die 2 "unknown spec '$spec' (expected pr:<n>, mr:<n> or ref:<git-ref>)" ;;
  esac

  if [ -n "$fetched_ref" ]; then
    git fetch -q "$remote" "+$source:$fetched_ref" 2>/dev/null \
      || die 1 "cannot fetch $spec from '$remote' ($source)"
    target=$fetched_ref
  else
    case "$target" in
      "$remote"/*) git fetch -q "$remote" "${target#"$remote"/}" 2>/dev/null \
        || die 1 "cannot fetch $spec from '$remote'" ;;
    esac
  fi

  git worktree add -q --detach "$path" "$target" >/dev/null \
    || die 1 "cannot create worktree for $spec at $path"

  if [ -n "$fetched_ref" ]; then
    echo "$fetched_ref" > "$(git -C "$path" rev-parse --absolute-git-dir)/$ref_marker"
  fi
  (cd "$path" && pwd -P)
}

remove() {
  [ -e "$1" ] || { git worktree prune; return 0; }
  drop_worktree "$1"
}

[ $# -eq 2 ] || die 2 "usage: worktree.sh create <spec> | remove <path>"
case "$1" in
  create) create "$2" ;;
  remove) remove "$2" ;;
  *) die 2 "unknown command '$1' (expected create or remove)" ;;
esac
