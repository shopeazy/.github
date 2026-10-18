# shopeazy/.github: what this repo is

The shared GitHub setup for every ShopEazy repo. Nobody uses it directly; every other repo's CI calls it.

- **Reusable workflows** (`.github/workflows/`): `node-ci` (lint, types, unit, build), `security` (gitleaks, new vulnerabilities), `promote` (staging to production) and `brand` (the brand check).
- **Scripts** (`scripts/`): `promote.sh`, `rulesets.sh`, `brand-check.mjs`.
- **Org profile** (`profile/README.md`): the public face of the GitHub organisation.

Who it's for: the engineers and agents working in any ShopEazy repo. Scope: CI and org-wide GitHub config only, no product code.
