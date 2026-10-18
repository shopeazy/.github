# ShopEazy CI

Shared GitHub Actions for every ShopEazy repo. Plan: Notion "CI/CD: PR → staging → full tests → promote to production" (Linear project Platform & CI).

## How a change ships (every repo)

```
feature branch ──PR──▶ staging ──Promote──▶ main
   PR checks           staging env        production
   (+ console e2e)     staging data       Vercel production deploy
```

- **`staging` is the default branch.** Branch off it, open the PR into it. A merge deploys to the staging environment on Vercel: `staging-app.shopeazy.co` (console), `*.staging.shopeazy.co` (storefronts), `staging-api`, `staging-admin`, `staging.shopeazy.co` (website), all on the `shopeazy-staging` Firebase project and behind Vercel login.
- **`main` is production.** Nothing pushes to it. The **Promote** workflow fast-forwards it to a commit on `staging` whose checks are all green, waits for Vercel's production deploy and requests a smoke URL; if that fails it rolls production back to the previous deployment.
- Promote from GitHub (Actions → Promote → Run workflow) or `scripts/promote.sh storefronts console`. Promote the storefront before the console when a shared contract changed.
- **Hotfix**: PR into `staging`, merge, promote. Only if staging is blocked: an admin merges a PR straight into `main`, then merges `main` back into `staging` the same day (Promote refuses while `main` has commits staging lacks).
- Repos with no deploy (mobile, core, client-sdk, brand) use the same branches; their Promote only moves `main`.
- **Firebase (console only):** Firestore rules, indexes and Cloud Functions deploy from the console's own `firebase-deploy.yml`, never by hand. A push to `staging` that touches `functions/`, `firestore.rules`, `firestore.indexes.json` or `firebase.json` deploys what changed to `shopeazy-staging`, then runs the functions' staging integration test. The console's Promote calls it after `main` moves (and after the smoke) and deploys what changed between the old and new `main` to `shopeazy-production`. Auth is Workload Identity Federation, no keys: a `firebase-deploy` service account per project, usable only by console jobs in the `staging` or `firebase-production` GitHub environment (the latter only from `staging`). Functions deploy by name, so a function missing from the source is never deleted; delete one by hand (`firebase functions:delete`).

## Reusable workflows

| Workflow | What it does |
|---|---|
| `.github/workflows/node-ci.yml` | `npm ci` (cached), lint, typecheck, unit tests, production build. Every step is an input; `''` skips it. Optional `sibling-repo` checks out the sibling repo beside this one for the byte-for-byte contract tests (same-named branch if it exists, else `main`). |
| `.github/workflows/promote.yml` | Promote staging → production: checks the commit is on `staging`, `main` can fast-forward to it and every check on it is green; waits on the `promote` environment (approval); moves `main`; waits for Vercel's production deploy; smoke URL; Vercel rollback on failure (needs `VERCEL_TOKEN`). Outputs `from`/`sha` (main before/after) for deploys the caller runs itself. |
| `.github/workflows/brand.yml` | The brand check (`scripts/brand-check.mjs`) on the lines a PR adds: the name ShopEazy, "Submit"/"Click here", emoji in the product, raw hex instead of tokens, and missing PRODUCT/DESIGN/AGENTS/CLAUDE.md. Input `surface` (marketing, product, api, tooling) and `mode` (warn, block). The `brand-override` label always passes. |
| `.github/workflows/security.yml` | gitleaks over the commits a PR/push adds; fails a PR that adds a high/critical production vulnerability (`npm audit` on the PR lockfile vs the base). |

Each repo has a thin `.github/workflows/ci.yml` that calls these with `@main`, plus `.github/dependabot.yml`.

## Secrets each repo needs

| Secret | Where | Why |
|---|---|---|
| `SIBLING_DEPLOY_KEY` or `SIBLING_TOKEN` | console, storefronts (Actions **and** Dependabot secrets) | read the other repo for the contract tests. Deploy keys are disabled in the org settings today, so this is a fine-grained PAT (Contents: read on console + storefronts) until they are allowed. Without one the contract tests skip with a warning. |
| `VERCEL_TOKEN` | repos that deploy on Vercel | Promote's automatic rollback. Without it a failed smoke fails the run and says to roll back by hand. |
| `firebase-production` environment | console | gates the production Firebase deploy (WIF subject `environment:firebase-production`, deployments from `staging` only). No secrets in it. |
| `staging` environment | console | e2e: every key from the console `.env.local` that points at shopeazy-staging (synced by `scripts/ci/sync-staging-secrets.sh` in the console) |

## Limits on the Free plan

- Required status checks and environment approvals need **GitHub Team** on private repos. Until then the checks report but cannot block a merge.
- Organisation secrets are not visible to private repos on Free, so secrets are set per repo.
- Private repos get 2,000 Actions minutes a month and 2-core / 7 GB runners.
- `actions/dependency-review-action` needs Advanced Security on private repos, so `security.yml` uses `npm audit` instead.

## Required checks

`scripts/rulesets.sh` puts two rulesets on every repo: **staging: PR + CI** (changes arrive by PR, the CI checks plus `e2e passed` on console must pass, no force-push or deletion; admins may override only when merging a PR) and **main: promote only** (only GitHub Actions may move `main`, forward only; an admin may merge an emergency hotfix PR). Needs GitHub Team (rulesets on private repos 403 on Free). Re-run it after adding a repo or renaming a check.

The `promote` environment in each repo should require Eamon as reviewer once on Team (Settings → Environments → promote), so production moves only on his approval.
