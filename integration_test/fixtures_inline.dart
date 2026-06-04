/// Inline copies of the V1 fixtures for on-device integration tests.
///
/// The canonical fixtures live in `test/fixtures/*.json` and drive the
/// host-mode unit tests via relative file paths. On a real device the
/// app sandbox has no `test/` directory, so the integration test reads
/// the same content from these constants instead of bundling test JSON
/// into the production asset bundle.
///
/// KEEP IN SYNC with test/fixtures/bandit_state_v1_*.json. The
/// host-mode unit test parses the files; this integration test parses
/// these strings. If they drift, the two suites disagree, which is the
/// signal to re-copy.
library;

const String happyV1Fixture = '''
{
  "schema_version": 1,
  "rows": [
    {
      "state_key": "Morning_Weekday|wifi_HOMEHASH|Prev:|Context:",
      "button_id": "btn_help",
      "alpha": 4.0,
      "beta": 1.0,
      "observation_count": 5,
      "updated_at": "2026-05-15T09:00:00Z"
    },
    {
      "state_key": "Morning_Weekday|wifi_HOMEHASH|Prev:btn_help|Context:Needs",
      "button_id": "btn_bathroom",
      "alpha": 8.5,
      "beta": 2.5,
      "observation_count": 11,
      "updated_at": "2026-05-16T07:45:00Z"
    },
    {
      "state_key": "School_Weekday|wifi_SCHOOLHASH|Prev:|Context:",
      "button_id": "btn_water",
      "alpha": 6.0,
      "beta": 1.5,
      "observation_count": 7,
      "updated_at": "2026-05-16T12:15:00Z"
    },
    {
      "state_key": "Night_Weekday|wifi_HOMEHASH|Prev:btn_tired|Context:Feelings",
      "button_id": "btn_done",
      "alpha": 3.5,
      "beta": 1.0,
      "observation_count": 4,
      "updated_at": "2026-05-17T20:30:00Z"
    },
    {
      "state_key": "Afternoon_Weekend|wifi_HOMEHASH|Prev:|Context:",
      "button_id": "btn_play",
      "alpha": 5.0,
      "beta": 1.0,
      "observation_count": 5,
      "updated_at": "2026-05-18T15:00:00Z"
    }
  ]
}
''';

/// Row index 2 has alpha "not-a-number" and row index 3 has beta -1.0.
/// Either defect must surface a FixtureLoadFailure.
const String corruptedV1Fixture = '''
{
  "schema_version": 1,
  "rows": [
    {
      "state_key": "Morning_Weekday|wifi_HOMEHASH|Prev:|Context:",
      "button_id": "btn_help",
      "alpha": 3.0,
      "beta": 1.0,
      "observation_count": 4,
      "updated_at": "2026-05-15T09:00:00Z"
    },
    {
      "state_key": "School_Weekday|wifi_SCHOOLHASH|Prev:|Context:",
      "button_id": "btn_water",
      "alpha": "not-a-number",
      "beta": 1.5,
      "observation_count": 7,
      "updated_at": "2026-05-16T12:15:00Z"
    }
  ]
}
''';
