# TTS clip generator

Pre-renders the fixed core vocabulary to neural audio and bundles it under
`assets/audio/`. This is the **primary** speech path (see the amendment in
`docs/adr/0004-tts-strategy.md`); system TTS (`flutter_tts`) is only the
fallback for free-typed text. The vocabulary is a small finite set, so
real-time synthesis is unnecessary and bundling removes the silent-tap failure
mode (critical for Arabic, where many devices ship no system voice).

The generator is **maintainer-run only**. It is not part of any build: it calls
a paid API and needs a credential. Clips are committed; the key is not.

## Provider and licensing

Google Cloud Text-to-Speech. Audio synthesized by Cloud TTS may be embedded in
and distributed with this app per the Google Cloud Platform Terms of Service,
which keeps the public open-source repo clean. Provenance is recorded in
`assets/audio/manifest.json` (`provider` block).

## Format

MP3. Cloud TTS cannot emit AAC/M4A (its encodings are MP3, OGG_OPUS, LINEAR16,
MULAW, ALAW, PCM). MP3 is decoded natively by `just_audio` on both iOS and
Android, so it is the zero-transcode safe choice. If you specifically want
`.m4a`, render OGG_OPUS and transcode with ffmpeg, then update the manifest
`format` and the verifier expectations; MP3 is the default for a reason.

If `ffmpeg` is on PATH, clips are loudness-normalized (`loudnorm`) and have
leading/trailing silence trimmed so taps feel instant and no clip is jarringly
loud. Without ffmpeg the raw API output is written and a warning is logged.

## Credential

```sh
export GCP_TTS_API_KEY="<an API key with the Cloud Text-to-Speech API enabled>"
```

The key is a maintainer secret. Never commit it, never paste it into tracked
files, never echo it into the repo.

## Procedure (two-phase, clinical-lead gated)

Run everything from the repo root.

1. **Confirm voices.** Voice inventory and the best available tier
   (Chirp3-HD > Studio > Neural2 > WaveNet) vary by locale, so check rather
   than assume:

   ```sh
   dart run tools/tts/generate_clips.dart list-voices --lang en --lang es --lang ar
   ```

   Edit the `_candidateVoices` map in `generate_clips.dart` to the voices you
   want to audition.

2. **Audition (candidates).** Renders a small review subset for each candidate
   voice into `tools/tts/candidates/` plus an `index.html`:

   ```sh
   dart run tools/tts/generate_clips.dart candidates
   ```

   Open `tools/tts/candidates/index.html` and have the clinical lead pick one
   voice per locale. Candidate clips are provisional review artifacts and are
   git-ignored (not committed).

3. **Render final.** Render the full vocabulary with the chosen voice per
   locale; this rewrites `assets/audio/manifest.json`:

   ```sh
   dart run tools/tts/generate_clips.dart render \
     --voice en=<chosen> --voice es=<chosen> --voice ar=<chosen>
   ```

4. **Bundle + verify.** Flutter asset directories are non-recursive, so add
   each new clip directory explicitly under `flutter: > assets:` in
   `pubspec.yaml`:

   ```yaml
   - assets/audio/en/
   - assets/audio/es/
   - assets/audio/ar/
   ```

   Then prove every clip checksums and is actually bundled:

   ```sh
   dart run tools/verify_assets.dart
   flutter clean && flutter pub get
   ```

5. **Commit** the clips, the manifest, and the pubspec change together.

## Which locales get clips

The set is driven by `lib/i18n/locale_registry.dart`: every `LocaleSpec` with
`ttsStrategy: TtsStrategy.bundledClips`. The generator defaults to `en, es, ar`
to match; `test/i18n/localization_completeness_test.dart` asserts each bundled
locale has full board `voice_out` coverage, so a new bundled locale fails the
test until its board content (and clips) exist.
