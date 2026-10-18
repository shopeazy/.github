#!/usr/bin/env bash
# Branch ruleset "main: PR + CI" on every ShopEazy repo (needs GitHub Team).
set -euo pipefail
common='"checks / Lint · types · unit","checks / Build","security / Secret scan","security / New vulnerable dependencies"'
for repo in shopeazy-console shopeazy-storefronts shopeazy-admin shopeazy-website-final shopeazy-mobile shopeazy-api shopeazy-core shopeazy-client-sdk; do
  checks="$common"
  [ "$repo" = shopeazy-console ] && checks="$checks,\"e2e passed\""
  ctx=$(python3 -c "import json,sys;print(json.dumps([{'context':c,'integration_id':15368} for c in json.loads('['+sys.argv[1]+']')]))" "$checks")
  body=$(cat <<JSON
{"name":"main: PR + CI","target":"branch","enforcement":"active",
 "conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},
 "bypass_actors":[{"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"pull_request"}],
 "rules":[
  {"type":"deletion"},{"type":"non_fast_forward"},
  {"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}},
  {"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":false,"do_not_enforce_on_create":true,"required_status_checks":$ctx}}
 ]}
JSON
)
  existing=$(gh api "repos/shopeazy/$repo/rulesets" --jq '.[]|select(.name=="main: PR + CI")|.id' 2>/dev/null || true)
  if [ -n "$existing" ]; then
    echo "$body" | gh api -X PUT "repos/shopeazy/$repo/rulesets/$existing" --input - --jq '"updated \(.name) on '"$repo"'"'
  else
    echo "$body" | gh api -X POST "repos/shopeazy/$repo/rulesets" --input - --jq '"created \(.name) on '"$repo"'"'
  fi
done
