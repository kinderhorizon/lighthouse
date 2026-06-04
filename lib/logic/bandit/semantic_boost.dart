/// Verb -> object-category associations for semantic glow boosts (ADR 0011).
///
/// After the child taps a verb with a clear object domain, the words that
/// verb typically takes should light up (clinical alpha feedback: "after
/// eat highlight food, after drink highlight water"). This is a small, curated
/// table rather than learned data, so it is meaningful on day one before the
/// usage bandit has anything to say.
///
/// Keyed on the stable button `id` (locale-independent), mapping to the set of
/// board `category` values to highlight. Verbs WITHOUT a strong object domain
/// (want / need / like / get / make) are intentionally absent: the clinical lead asked for
/// those to surface the child's most-used words, which is the bandit's job, so
/// they fall through to it.
library;

const Map<String, Set<String>> kVerbObjectBoosts = {
  // Eat -> solid food (the Food folder + food items inside it), NOT drinks:
  // "eat water" is wrong in English (clinical review). Water carries the dedicated
  // `drink` category so the eat boost no longer lights it up.
  'btn_eat': {'food', 'food_nav'},
  // Drink -> drinks (water) + the Food folder, where the other drinks live.
  'btn_drink': {'drink', 'food_nav'},
  // Go -> places; Play -> activities; Look / Open -> things.
  // NOTE: the Activities board items use the singular category `activity`; the
  // home folder uses `activities_nav`. Both must be listed or the in-folder
  // half of the boost silently never fires (a guard test enforces this).
  'btn_go': {'places', 'places_nav'},
  'btn_play': {'activity', 'activities_nav'},
  'btn_look': {'things', 'things_nav'},
  'btn_open': {'things', 'things_nav'},
};

/// The categories to boost given the [buttonId] of the last word tapped, or an
/// empty set when the word has no curated object domain (defer to the bandit).
Set<String> verbObjectBoosts(String? buttonId) =>
    buttonId == null ? const {} : (kVerbObjectBoosts[buttonId] ?? const {});

/// Transitive / catenative "light" verbs that take an object or another verb
/// but have no single object DOMAIN to boost (unlike eat -> food). After one of
/// these, the next word should be a verb or a noun ("want to GO", "want WATER"),
/// never a response, feeling, social, or question word. These are exactly the
/// verbs left out of [kVerbObjectBoosts] precisely because their object is
/// open-ended; here we instead curb the implausible suggestions.
///
/// LOCALE-INDEPENDENT BY DESIGN. These are button `id`s, which are identical in
/// every language (only `label` / `voice_out` are localized, per ADR 0008), so
/// this rule applies unchanged to en / es / ar and any future language with no
/// per-locale work. "Quiero" and "أريد" are still `btn_want`. A guard test
/// asserts every id here is a real board button so a rename can't silently
/// disable the rule.
const Set<String> kTransitiveVerbs = {
  'btn_want',
  'btn_need',
  'btn_like',
  'btn_get',
  'btn_make',
};

/// Board `category` values that do not grammatically follow a transitive verb
/// as the next word, so they are SUPPRESSED from the glow after one (the child
/// can still tap them; this only curbs the SUGGESTION). Without this, cold-start
/// base_weights surfaced high-weight responses/feelings like "yes" and "happy"
/// right after "want" (clinical review), which read as wrong guidance.
///
/// LOCALE-INDEPENDENT BY DESIGN, same as [kTransitiveVerbs]: these are board
/// `category` values, which are shared across every locale (a button keeps its
/// category in es / ar / future languages; only its words are translated). "You
/// don't say want-yes" holds in every language, so the rule needs no per-locale
/// variant. A guard test asserts each category here exists on a real board.
const Set<String> kPostVerbSuppressedCategories = {
  'response', // yes / no
  'feeling', // happy / sad / ...
  'social', // sorry / thank you
  'question', // what / where / ...
};

/// Categories to suppress from the glow given the [buttonId] of the last word
/// tapped: non-empty only after a transitive verb (see [kTransitiveVerbs]).
Set<String> postVerbSuppressedCategories(String? buttonId) =>
    buttonId != null && kTransitiveVerbs.contains(buttonId)
        ? kPostVerbSuppressedCategories
        : const {};
