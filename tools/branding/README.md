# Lighthouse brand assets

App mark for **Lighthouse**, the AAC app by the Kinder Horizon Foundation.
Concept: **Beam** (selected by the clinical lead). A cream lighthouse on the
Foundation ink ground, with a warm amber beam sweeping up and to the right and
an amber lantern window. Built tower-first so it reads as a lighthouse (not a
wifi/broadcast glyph) down to 29px and survives 1-color and iOS-18 tinted mode.

## Palette (matches Kinder Horizon Foundation brand tokens)

| Token | Hex | Use |
|-------|-----|-----|
| Ink | `#1F3A44` | Icon ground, tower on light bg, 1-color mark |
| Amber | `#E8873C` | Beam + lantern light (the "logo sun" color) |
| Cream | `#F6EFE4` | Tower on the dark icon ground, reversed mark |

## Files

Vector sources (source of truth, not bundled into the app):
- `lighthouse-mark-color.svg` - ink tower + amber light, transparent. For light backgrounds (website header, light UI).
- `lighthouse-mark-mono.svg` - single ink. 1-color / print / favicon / embroidery.
- `lighthouse-mark-reversed.svg` - single cream. For dark backgrounds.
- `lighthouse-app-icon.svg` - full-bleed app-icon artwork (cream tower + amber on ink ground).

Rasters for the stores + launcher pipeline (not bundled):
- `app-icon-1024.png` - 1024x1024 full-bleed, **no alpha, no rounded corners** (the stores add corners). iOS + Play Store listing + launcher master.
- `app-icon-foreground-1024.png` - transparent foreground for Android adaptive icons. Mark sized conservatively to stay inside the 66% safe circle; pair with background `#1F3A44`.

Runtime (bundled via `assets/brand/` in pubspec):
- `../../assets/brand/lighthouse-mark.png` - 512px color-on-transparent mark for the in-app About screen.

## Generating platform icons

Icons are produced with `flutter_launcher_icons` from the two source PNGs above.
This step rewrites files under `android/` and `ios/`, so run it deliberately,
not as part of every build.

Add to `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.4   # or latest; `flutter pub add dev:flutter_launcher_icons` resolves it

flutter_launcher_icons:
  image_path: "tools/branding/app-icon-1024.png"
  android: "ic_launcher"
  adaptive_icon_background: "#1F3A44"
  adaptive_icon_foreground: "tools/branding/app-icon-foreground-1024.png"
  ios: true
  remove_alpha_ios: true
  min_sdk_android: 21
```

Then:

```bash
dart run flutter_launcher_icons
```

## Regenerating the source art

The art is generated deterministically from a one-off generator script.
Geometry is locked to the approved render; do not nudge coordinates
without a fresh sign-off.
