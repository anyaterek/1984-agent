#!/bin/sh
# Prints the hosting platform of a git remote: github | gitlab | unknown.
#
# Usage: detect-platform.sh [remote-url]
# Without an argument reads the URL of $MR_REVIEW_REMOTE (default: origin).
# Only the host is inspected, so a path like /github-mirror/ does not count.
# Self-hosted instances without "github"/"gitlab" in the host are "unknown" on
# purpose: the caller asks the user once instead of guessing.

url=${1-}
if [ $# -eq 0 ]; then
  url=$(git remote get-url "${MR_REVIEW_REMOTE:-origin}" 2>/dev/null) || url=""
fi

# Strip scheme, user@, then everything from the first ":" or "/" (port, path).
host=$(printf '%s\n' "$url" \
  | sed -e 's#^[A-Za-z][A-Za-z0-9+.-]*://##' -e 's#^[^@/]*@##' -e 's#[:/].*$##' \
  | tr '[:upper:]' '[:lower:]')

case "$host" in
  *github*) echo github ;;
  *gitlab*) echo gitlab ;;
  *) echo unknown ;;
esac
