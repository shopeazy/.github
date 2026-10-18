#!/usr/bin/env bash
# Branch rulesets on every ShopEazy repo (needs GitHub Team on private repos).
#
#   "staging: PR + CI"   the default branch (staging): changes arrive by PR and
#                        the CI checks (plus `e2e passed` on console) must pass;
#                        no force-push or deletion. Admins may override only
#                        when merging a PR.
#   "main: promote only" production: only GitHub Actions (the Promote
#                        workflow) may move it, and only forward. An admin can
#                        still merge a hotfix PR straight into main in an
#                        emergency; merge main back into staging afterwards.
set -euo pipefail
common='"checks / Lint · types · unit","checks / Build","security / Secret scan","security / New vulnerable dependencies"'
ACTIONS_APP=15368   # GitHub Actions
put() { # repo name body
  local existing
  existing=$(gh api "repos/shopeazy/$1/rulesets" --jq ".[]|select(.name==\"$2\")|.id" 2>/dev/null || true)
  if [ -n "$existing" ]; then
    echo "$3" | gh api -X PUT "repos/shopeazy/$1/rulesets/$existing" --input - --jq '"updated \(.name) on '"$1"'"'
  else
    echo "$3" | gh api -X POST "repos/shopeazy/$1/rulesets" --input - --jq '"created \(.name) on '"$1"'"'
  fi
}
for repo in shopeazy-console shopeazy-storefronts shopeazy-admin shopeazy-website-final shopeazy-mobile shopeazy-api shopeazy-core shopeazy-client-sdk shopeazy-brand; do
  checks="$common"
  [ "$repo" = shopeazy-console ] && checks="$checks,\"e2e passed\""
  ctx=$(python3 -c "import json,sys;print(json.dumps([{'context':c,'integration_id':$ACTIONS_APP} for c in json.loads('['+sys.argv[1]+']')]))" "$checks")
  # The old name, from before the staging branch.
  old=$(gh api "repos/shopeazy/$repo/rulesets" --jq '.[]|select(.name=="main: PR + CI")|.id' 2>/dev/null || true)
  [ -n "$old" ] && gh api -X DELETE "repos/shopeazy/$repo/rulesets/$old" && echo "removed main: PR + CI on $repo"
  put "$repo" "staging: PR + CI" "$(cat <<JSON
{"name":"staging: PR + CI","target":"branch","enforcement":"active",
 "conditions":{"ref_name":{"include":["refs/heads/staging"],"exclude":[]}},
 "bypass_actors":[{"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"pull_request"}],
 "rules":[
  {"type":"deletion"},{"type":"non_fast_forward"},
  {"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}},
  {"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":false,"do_not_enforce_on_create":true,"required_status_checks":$ctx}}
 ]}
JSON
)"
  put "$repo" "main: promote only" "$(cat <<JSON
{"name":"main: promote only","target":"branch","enforcement":"active",
 "conditions":{"ref_name":{"include":["refs/heads/main"],"exclude":[]}},
 "bypass_actors":[
  {"actor_id":$ACTIONS_APP,"actor_type":"Integration","bypass_mode":"always"},
  {"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"pull_request"}],
 "rules":[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"update"}]}
JSON
)"
done
