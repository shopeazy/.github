#!/usr/bin/env bash
# Promote staging to production in one or more repos.
#
#   scripts/promote.sh storefronts console     # storefront first: it owns shared contracts
#   scripts/promote.sh console <sha>           # one repo, a specific staging commit
#
# Starts each repo's Promote workflow and prints the run link. Approve it in
# GitHub (environment `promote`) once required reviewers are on.
set -euo pipefail
[ $# -ge 1 ] || { sed -n '2,8p' "$0"; exit 1; }
sha=''
repos=()
for a in "$@"; do
  if [[ "$a" =~ ^[0-9a-f]{7,40}$ ]]; then sha="$a"; else repos+=("$a"); fi
done
for r in "${repos[@]}"; do
  case "$r" in shopeazy-*|.github) repo="$r";; website) repo=shopeazy-website-final;; *) repo="shopeazy-$r";; esac
  gh workflow run promote.yml -R "shopeazy/$repo" --ref staging ${sha:+-f sha="$sha"}
  sleep 3
  gh run list -R "shopeazy/$repo" --workflow promote.yml -L 1 --json url --jq '"'"$repo"': \(.[0].url)"'
done
