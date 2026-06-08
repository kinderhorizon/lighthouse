# Lighthouse AAC

[![CI](https://github.com/kinderhorizon/lighthouse/actions/workflows/ci.yml/badge.svg)](https://github.com/kinderhorizon/lighthouse/actions/workflows/ci.yml)

A free, open-source Augmentative and Alternative Communication (AAC) tablet app
for non-speaking children. Runs entirely on-device. Uses a Contextual
Multi-Armed Bandit (Thompson Sampling) to predict likely vocabulary based on
time, location, and recent tap history, and highlights predictions with a
"Golden Glow" without ever rearranging the grid.

**Core philosophy:** Augment, Don't Rearrange. Buttons never move. Nothing is
hidden. The app suggests, never insists. Muscle memory is sacred.

Flagship product of [Kinder Horizon Foundation](https://kinderhorizon.org), a
BC Society incorporated April 17, 2026.

## Status

Version 1.0, submitted to the App Store and Google Play for review.

## Repository layout

```
.
|-- assets/arasaac/      # Vendored ARASAAC pictograms (CC BY-NC-SA 4.0)
|   `-- manifest.json    # Audit trail: source ID, label, category, modifications
|-- boards/              # Default board specs (Home Core 48 v1.3)
|-- docs/
|   `-- adr/             # Architecture Decision Records
|-- lib/
|   |-- main.dart        # App entry point
|   |-- logic/           # Bandit, ContextManager, geometry helpers
|   |-- models/          # Data classes
|   |-- persistence/     # Isar collections + schema migrators
|   |-- services/        # TTS, crash logger, share, file import
|   |-- state/           # Riverpod providers (codegen)
|   `-- ui/              # Widgets, screens
|-- test/                # Unit, widget, and migration-chain tests
|-- scripts/
|   `-- *.sh             # Pre-commit / CI guards (style, residue, binaries)
|-- LICENSE              # MIT (source code)
|-- LICENSES/
|   `-- ARASAAC.md       # CC BY-NC-SA 4.0 attribution + terms
`-- NOTICE               # Third-party asset/dependency inventory
```

## Getting started

```bash
git config core.hooksPath .githooks   # one-time, enables commit guards
flutter pub get
flutter test
flutter run
```

## Licensing

- **Source code:** MIT (see `LICENSE`)
- **ARASAAC pictograms** under `assets/arasaac/`: CC BY-NC-SA 4.0
  (see `LICENSES/ARASAAC.md`)

The dual-license-by-scope arrangement is documented in
`docs/adr/0001-asset-licensing.md`.

## Contributing

Not yet open for external contributions.

If you're a parent of a non-speaking child, a Speech-Language Pathologist, or
an accessibility researcher interested in this project, reach out:
[info@kinderhorizon.org](mailto:info@kinderhorizon.org).
