# ARASAAC Pictograms

Pictogram assets bundled with Lighthouse AAC under `assets/arasaac/` are
sourced from ARASAAC (Aragonese Portal of Augmentative and Alternative
Communication), a public initiative of the Government of Aragón, Spain.

## Required attribution (use verbatim)

> Symbols Author: Sergio Palao. Origin: ARASAAC (https://arasaac.org).
> License: CC (BY-NC-SA). Owner: Government of Aragón (Spain).

This attribution appears verbatim in the in-app About screen and must
remain present in any redistribution of the bundled assets.

## License terms

ARASAAC pictograms are licensed under the
**Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International
License (CC BY-NC-SA 4.0)**.

Full license text: https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode

Summary of terms:

- **Attribution (BY)**, credit the author and the origin (see above).
- **NonCommercial (NC)**, material may not be used for commercial purposes.
- **ShareAlike (SA)**, derivatives must be distributed under the same
  CC BY-NC-SA 4.0 license.

## What this means for Lighthouse AAC

- The Lighthouse AAC source code (`lib/`, `test/`, build configuration, etc.)
  is licensed under MIT (see `LICENSE` at repository root). MIT and
  CC BY-NC-SA 4.0 coexist by scope: the code is MIT; the bundled pictogram
  assets are CC BY-NC-SA 4.0.

- The application as distributed via App Store / Play Store / direct APK
  bundles ARASAAC pictograms, so the application bundle as a whole inherits
  the NC and SA constraints with respect to those assets.

- Kinder Horizon Foundation (the publisher) does not charge for the app and
  does not pursue any commercial monetization path. The free-forever charter
  is documented at https://kinderhorizon.org and is structurally compatible
  with the NC clause.

## Modifications to pictograms

Any modifications applied to ARASAAC pictograms before bundling are recorded
in `assets/arasaac/manifest.json` under the top-level `modifications` field.
The modified assets remain under CC BY-NC-SA 4.0; they are not extracted from
the asset bundle and licensed separately.

## Contact

Project notification email sent to `arasaac@aragon.es` before public beta to
register Lighthouse AAC as a project using ARASAAC pictograms.
