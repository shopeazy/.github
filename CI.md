# ShopEazy CI

Shared GitHub Actions for every ShopEazy repo. Plan: Notion "CI/CD: PR → staging → full tests → promote to production" (Linear project Platform & CI).

## Reusable workflows

| Workflow | What it does |
|---|---|
| `.github/workflows/node-ci.yml` | `npm ci` (cached), lint, typecheck, unit tests, production build. Every step is an input; `''` skips it. Optional `sibling-repo` checks out the sibling repo beside this one for the byte-for-byte contract tests (same-named branch if it exists, else `main`). |
| `.github/workflows/security.yml` | gitleaks over the commits a PR/push adds; fails a PR that adds a high/critical production vulnerability (`npm audit` on the PR lockfile vs the base). |

Each repo has a thin `.github/workflows/ci.yml` that calls these with `@main`, plus `.github/dependabot.yml`.

## Secrets each repo needs

| Secret | Where | Why |
|---|---|---|
| `SIBLING_DEPLOY_KEY` or `SIBLING_TOKEN` | console, storefronts (Actions **and** Dependabot secrets) | read the other repo for the contract tests. Deploy keys are disabled in the org settings today, so this is a fine-grained PAT (Contents: read on console + storefronts) until they are allowed. Without one the contract tests skip with a warning. |
| `staging` environment | console | e2e: every key from the console `.env.local` that points at shopeazy-staging (synced by `scripts/ci/sync-staging-secrets.sh` in the console) |

## Limits on the Free plan

- Required status checks and environment approvals need **GitHub Team** on private repos. Until then the checks report but cannot block a merge.
- Organisation secrets are not visible to private repos on Free, so secrets are set per repo.
- Private repos get 2,000 Actions minutes a month and 2-core / 7 GB runners.
- `actions/dependency-review-action` needs Advanced Security on private repos, so `security.yml` uses `npm audit` instead.
