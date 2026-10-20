#!/usr/bin/env bash
# Public-safety scan. Fails closed if no term list is provided.
#
# The term list is NOT stored in this repo, so the repo does not reveal what it excludes.
# Provide it with DENYLIST_FILE (one term per line, case-insensitive). Only file names are
# printed on a hit, never the term or the matching line, so CI logs stay clean.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${DENYLIST_FILE:=$HOME/.config/ai-toolkit/denylist.txt}"
if [[ ! -r "$DENYLIST_FILE" ]]; then
  echo "check-public: no term list found. Set DENYLIST_FILE to a readable file." >&2
  exit 2
fi

status=0
while IFS= read -r term; do
  [[ -z "$term" || "$term" == \#* ]] && continue
  files=$(grep -rliF --exclude-dir=.git --exclude=check-public.sh -- "$term" . || true)
  if [[ -n "$files" ]]; then
    echo "Term hit in:"; echo "$files"; status=1
  fi
done < "$DENYLIST_FILE"

secret_files=$(grep -rlE --exclude-dir=.git "(api[_-]?key|secret|token)[\"' :=]+[A-Za-z0-9_-]{20,}" . || true)
if [[ -n "$secret_files" ]]; then
  echo "Possible secret in:"; echo "$secret_files"; status=1
fi

[[ $status -eq 0 ]] && echo "check-public: clean"
exit $status
