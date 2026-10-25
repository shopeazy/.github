# shopeazy/.github: agent rules

- Read `CI.md` first: how a change ships (feature branch to staging to production) and what each workflow does.
- **Every repo calls these workflows with `@main`.** A change here changes CI everywhere at once: keep inputs backwards compatible and test on one repo's PR before merging.
- **This repo is public.** Never put a secret, a private URL or customer data in it.
- **Brand check** (`scripts/brand-check.mjs`): reads only the lines a PR adds. Rules mirror shopeazy-brand `BRAND.md` and `VOICE.md`; change both together. Blocking since 2026-10-25: every repo passes `mode: block` in its `ci.yml` (the monorepo sets `MODE: block` in its own brand step). The `brand-override` label lets a hotfix through.
- Brand and voice for anything written here: the **shopeazy-brand** repo. Commit as eamon@shopeazy.co.
