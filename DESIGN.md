# Design

This repo has no UI. Anything public it holds (the org profile, badges) follows the ShopEazy brand:
the **shopeazy-brand** repo (`tokens.json`, `BRAND.md`, `VOICE.md`) is the source of truth.
For Claude chat, the same truth is in the design system (claude.ai/artifact/7znNcpbWAyCSwT5VSibKFj)
and the Brand Studio's Brand book page (claude.ai/artifact/MtYMmdwf8MCAvvaTRc2kMY).

The brand check (`scripts/brand-check.mjs`, `.github/workflows/brand.yml`) turns the most
common brand rules into a PR check for every repo. Its rules must match `BRAND.md` and `VOICE.md`;
change them together.
