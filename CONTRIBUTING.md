# Contributing to Lighthouse AAC

Thanks for your interest. Lighthouse is the flagship open-source product of the
Kinder Horizon Foundation, a non-profit BC Society. It is a communication tool
for non-speaking children, so correctness, privacy, and a calm, stable
experience matter more than feature velocity.

## Before you start

- Read `README.md` and the Architecture Decision Records in `docs/adr/`. The
  ADRs are the source of truth for load-bearing decisions; if a change
  contradicts one, update the ADR in the same PR.
- The core invariant is **Augment, Don't Rearrange**: buttons never move,
  nothing is hidden, the app suggests and never insists. Changes that move a
  child's tiles around will be declined.

## Local setup

```sh
flutter pub get
git config core.hooksPath .githooks   # enable the style + residue hooks
```

Enabling the hooks is required: it wires up the same checks CI enforces, so you
catch problems before you push.

## House rules (enforced by CI)

CI runs `flutter analyze --no-fatal-infos`, `flutter test`, ARASAAC asset
integrity, and two text guards. A PR cannot merge until all pass.

1. **No residue** (`scripts/no-residue.sh`). The repo is public, so the
   following must never appear in tracked files or commit messages:
   - **Personal first names** (use a role: "the founder", "the clinical lead",
     "the implementer"). The foundation's formal public byline is fine where an
     author credit is appropriate.
   - **AI-assistant or AI-editor names**, and **AI co-author trailers** in
     commit messages.
   - **Absolute home-directory paths** (`/Users/...`, `~/dev/...`). Use
     repo-relative paths.
   - **Known-sensitive files** (signing keys, keystores, `key.properties`,
     `local.settings.json`, the un-redacted Azure ops doc). These are
     gitignored; the pre-commit hook also refuses to stage them.
2. **Typography** (`scripts/no-em-dash.sh`). Use regular hyphens; em and en
   dashes are rejected. Commas, parens, colons, or separate sentences cover the
   cases you would reach for one.

If the residue guard flags a genuine false positive, scope the pattern in
`scripts/no-residue.sh` in the same PR rather than disabling the check.

## Secrets

Never commit secrets. Release signing keys, the OTA content-signing seed, and
Azure connection strings live offline / in the secrets manager. Use the
`*.example` templates. Enable GitHub secret-scanning push protection in the
repository Settings (Code security) as a backstop; it is free for public repos.

## Pull requests

- Keep PRs focused. Squash-merge is the default so feature-branch history stays
  out of `main`.
- Add or update tests for behavioural changes. Widget tests that touch the board
  must pin a tablet-sized surface (see existing tests for the pattern).
