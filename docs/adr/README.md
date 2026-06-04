# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for Lighthouse
AAC. Each ADR captures a single decision that constrains future work, the
reasoning behind it, the alternatives that were rejected, and the reviewers
who signed off.

Reading order for new contributors:
1. [0001, Asset licensing](0001-asset-licensing.md)
2. [0002, No automatic telemetry](0002-no-automatic-telemetry.md)
3. [0003, Cold-start glow + onboarding](0003-cold-start-glow-and-onboarding.md)
4. [0004, TTS strategy](0004-tts-strategy.md)
5. [0005, Isar schema versioning](0005-isar-schema-versioning.md)
6. [0006, Thompson sampler + glow architecture](0006-thompson-sampler-and-glow-architecture.md)
7. [0007, Android toolchain + Isar community fork](0007-android-toolchain-and-isar-community.md)
8. [0008, Localization + launch languages (en, ar, es)](0008-localization-and-launch-languages.md)
9. [0009, Sub-boards, home restructure, cross-board scoping](0009-sub-boards-and-cross-board-scoping.md)

## Adding a new ADR

1. Number it `000N-kebab-case-title.md`, sequential, no gaps.
2. Status starts at `Proposed`, moves to `Accepted` once locked.
3. Include the `Reviewers` footer with reviewer names, roles, and dates.
4. Load-bearing decisions (architecture, hard-to-reverse, child-safety,
   brand/legal) get an independent second review before status moves
   to Accepted.
5. Update this README's reading order.

## Retiring an ADR

Don't delete superseded ADRs. Change status to `Superseded by NNNN`, link to
the new one, and keep the file. History matters.
