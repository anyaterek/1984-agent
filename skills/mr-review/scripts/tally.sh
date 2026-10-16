#!/bin/sh
# Final severity of one finding from the ultra-mode debate votes.
#
# Usage: tally.sh <vote>...   where vote is blocker | major | minor | none
# Prints: <result> <unanimous|disputed> blocker=<n> major=<n> minor=<n> none=<n>
#
# Votes are ordered none < minor < major < blocker and the result is the median
# (index floor(n/2) of the ascending order). With 3+ of 5 votes for one option
# the median is that option, i.e. plain majority; for splits like 2/2/1 the
# median still gives a single answer, so there is no separate tie rule.

if [ $# -eq 0 ]; then
  echo "tally.sh: no votes given" >&2
  exit 2
fi

blocker=0 major=0 minor=0 none=0
for vote in "$@"; do
  case "$vote" in
    blocker) blocker=$((blocker + 1)) ;;
    major) major=$((major + 1)) ;;
    minor) minor=$((minor + 1)) ;;
    none) none=$((none + 1)) ;;
    *) echo "tally.sh: unknown vote '$vote' (expected blocker|major|minor|none)" >&2; exit 2 ;;
  esac
done

median_index=$(($# / 2))
seen=0
for level in none minor major blocker; do
  eval "count=\$$level"
  seen=$((seen + count))
  if [ "$seen" -gt "$median_index" ]; then
    result=$level
    break
  fi
done

eval "result_count=\$$result"
if [ "$result_count" -eq $# ]; then agreement=unanimous; else agreement=disputed; fi

echo "$result $agreement blocker=$blocker major=$major minor=$minor none=$none"
