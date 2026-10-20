/// Accessible Smart Multilingual AAC Keyboard Screen.
///
/// Provides literate and emerging-literate AAC users with an accessible typing
/// surface featuring offline prefix autocomplete, next-word suggestions,
/// personal card prioritization, direct TTS speech, and seamless sentence bar sync.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/locale_registry.dart';
import '../../models/models.dart';
import '../../services/keyboard/smart_keyboard_service.dart';
import '../../services/symbols/symbols.dart';
import '../../state/state.dart';
import '../cards/personal_card_editor_screen.dart';
import '../theme/lighthouse_theme.dart';

class SmartKeyboardScreen extends ConsumerStatefulWidget {
  const SmartKeyboardScreen({
    this.initialText = '',
    super.key,
  });

  final String initialText;

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    // 1. Gather any existing words from the sentence bar to preserve composed text
    final tokens = ref.read(utteranceProvider);
    final currentLang = LocaleRegistry.codeForLocale(Localizations.localeOf(context));
    final initialText = tokens.map((b) => b.labelFor(currentLang)).join(' ');

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SmartKeyboardScreen(initialText: initialText),
      ),
    );
  }

  @override
  ConsumerState<SmartKeyboardScreen> createState() => _SmartKeyboardScreenState();
}

class _SmartKeyboardScreenState extends ConsumerState<SmartKeyboardScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String _currentLang = 'en';
  bool _shiftActive = false;
  bool _numbersActive = false;

  List<KeyboardSuggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText;
    if (_controller.text.isNotEmpty) {
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
    _controller.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uiCode = LocaleRegistry.codeForLocale(Localizations.localeOf(context));
      setState(() {
        _currentLang = uiCode;
        _updateSuggestions();
      });
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _updateSuggestions();
  }

  void _updateSuggestions() {
    final text = _controller.text;
    final lastWord = text.isEmpty ? '' : text.split(RegExp(r'\s+')).last;

    final service = ref.read(smartKeyboardServiceProvider);
    final cards = ref.read(personalCardsProvider).valueOrNull ?? const [];
    final quickPhrases = ref.read(quickPhrasesProvider).valueOrNull ?? const [];

    setState(() {
      if (lastWord.isNotEmpty) {
        _suggestions = service.getSuggestions(
          prefix: lastWord,
          languageCode: _currentLang,
          personalCards: cards,
          quickPhrases: quickPhrases,
          limit: 8,
        );
      } else if (text.trim().isNotEmpty) {
        // Next-word prediction based on previous word
        final words = text.trim().split(RegExp(r'\s+'));
        final prev = words.isNotEmpty ? words.last : '';
        _suggestions = service.predictNextWords(
          precedingWord: prev,
          languageCode: _currentLang,
          personalCards: cards,
          limit: 8,
        );
      } else {
        // Empty text: show starter personal cards and quick phrases
        _suggestions = service.getSuggestions(
          prefix: '',
          languageCode: _currentLang,
          personalCards: cards,
          quickPhrases: quickPhrases,
          limit: 8,
        );
      }
    });
  }

  void _insertSuggestion(KeyboardSuggestion suggestion) {
    final text = _controller.text;
    final words = text.split(RegExp(r'\s+'));

    String replacement = suggestion.text;
    if (words.isNotEmpty && text.isNotEmpty && !text.endsWith(' ')) {
      // Replace the last partial word
      words[words.length - 1] = replacement;
      _controller.text = '${words.join(' ')} ';
    } else {
      _controller.text = '${text.trimRight()} $replacement '.trimLeft();
    }
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
  }

  void _appendCharacter(String char) {
    final text = _controller.text;
    final selection = _controller.selection;

    final actualChar = _shiftActive ? char.toUpperCase() : char.toLowerCase();

    if (selection.isValid && selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, actualChar);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + actualChar.length),
      );
    } else {
      _controller.text = text + actualChar;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }

    if (_shiftActive) {
      setState(() => _shiftActive = false);
    }
  }

  void _backspace() {
    final text = _controller.text;
    if (text.isEmpty) return;

    final selection = _controller.selection;
    if (selection.isValid && selection.start >= 0 && selection.end > selection.start) {
      final newText = text.replaceRange(selection.start, selection.end, '');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
    } else {
      final newText = text.substring(0, text.length - 1);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: newText.length);
    }
  }

  void _clear() {
    _controller.clear();
  }

  Future<void> _speak() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final tts = ref.read(ttsEngineProvider);
    final spec = LocaleRegistry.specForCode(_currentLang);
    final targetLocale = spec?.locale ?? Localizations.localeOf(context);

    await tts.speak(text, locale: targetLocale);
  }

  void _commitAndReturn() {
    final text = _controller.text.trim();
    final utteranceNotifier = ref.read(utteranceProvider.notifier);
    utteranceNotifier.clear();

    if (text.isNotEmpty) {
      final words = text.split(RegExp(r'\s+'));
      final cards = ref.read(personalCardsProvider).valueOrNull ?? const [];

      for (int i = 0; i < words.length; i++) {
        final w = words[i];
        if (w.isEmpty) continue;

        // Try matching with personal cards
        final matchedCard = cards.firstWhere(
          (c) => c.labelFor(_currentLang).toLowerCase() == w.toLowerCase(),
          orElse: () => PersonalCard(
            id: 'typed_${DateTime.now().millisecondsSinceEpoch}_$i',
            profileId: 'temp',
            name: w,
            category: PersonalCardCategory.custom,
            imageUri: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        utteranceNotifier.commit(matchedCard.toAacButton());
      }
    }

    Navigator.of(context).pop();
  }

  Future<void> _saveAsQuickPhraseOrCard() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Composed Text'),
        content: Text('Save "$text" as a Personal Card or a Quick Phrase?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('phrase'),
            child: const Text('Quick Phrase'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('card'),
            style: FilledButton.styleFrom(backgroundColor: LhColors.brown),
            child: const Text('Personal Card'),
          ),
        ],
      ),
    );

    if (action == 'phrase') {
      await ref.read(quickPhrasesProvider.notifier).addPhrase(text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved "$text" to Quick Phrases')),
        );
      }
    } else if (action == 'card') {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PersonalCardEditorScreen(
              initialLabel: text,
              initialSpeech: text,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = _currentLang.startsWith('ar');
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: LhColors.cream,
      appBar: AppBar(
        title: const Text('Smart AAC Keyboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Communication Board',
          onPressed: _commitAndReturn,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Save as Quick Phrase or Card',
            onPressed: _saveAsQuickPhraseOrCard,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Apply to Sentence Bar',
            onPressed: _commitAndReturn,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Language selector bar
            _buildLanguageSelector(),

            // 2. Composed Sentence Bar & controls
            _buildComposedSentenceBar(isRtl),

            // 3. Dynamic Prefix / Next-word Autocomplete Suggestions
            _buildSuggestionBar(),

            const Divider(height: 1, color: LhColors.line),

            // 4. On-Screen Accessible AAC Keyboard
            Expanded(
              child: Directionality(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: _buildVirtualKeyboard(isLandscape),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: LhColors.surface,
      child: Row(
        children: [
          const Icon(Icons.translate, size: 18, color: LhColors.ink2),
          const SizedBox(width: 8),
          const Text(
            'Keyboard Script:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LhColors.ink2),
          ),
          const Spacer(),
          _langPill('EN', 'en', 'English'),
          const SizedBox(width: 6),
          _langPill('DE', 'de', 'Deutsch'),
          const SizedBox(width: 6),
          _langPill('AR', 'ar', 'العربية'),
          const SizedBox(width: 6),
          _langPill('DZ', 'ar_dz', 'الدارجة'),
        ],
      ),
    );
  }

  Widget _langPill(String label, String code, String tooltip) {
    final isSelected = _currentLang.replaceAll('-', '_') == code;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _currentLang = code;
            _updateSuggestions();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? LhColors.brown : LhColors.cream2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? LhColors.brown : LhColors.line2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : LhColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposedSentenceBar(bool isRtl) {
    final text = _controller.text;
    final hasText = text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LhColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: LhColors.nuriSky, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Spacious multi-line text input area
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64, maxHeight: 110),
            child: SingleChildScrollView(
              reverse: true, // Auto-scroll to end as user types
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: LhColors.nuriNavy,
                  height: 1.35,
                ),
                decoration: const InputDecoration(
                  hintText: 'Tippe hier oder wähle Wortvorschläge...',
                  hintStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.normal,
                    color: LhColors.ink3,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Actions row: Clear, Backspace, Copy, and prominent Speaker button
          Row(
            children: [
              if (hasText) ...[
                // Clear button
                Semantics(
                  label: 'Clear text',
                  button: true,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: _clear,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: LhColors.cream2,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 16, color: LhColors.ink2),
                          SizedBox(width: 4),
                          Text(
                            'Löschen',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: LhColors.ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Backspace button
                Semantics(
                  label: 'Backspace',
                  button: true,
                  excludeSemantics: true,
                  child: Tooltip(
                    message: 'Backspace',
                    child: InkWell(
                      onTap: _backspace,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: LhColors.cream2,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.backspace_outlined, size: 16, color: LhColors.ink2),
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Apply / Finish check button
              TextButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Fertig'),
                style: TextButton.styleFrom(
                  foregroundColor: LhColors.nuriTeal,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _commitAndReturn,
              ),
              const SizedBox(width: 6),
              // Prominent Blue Speaker Button matching mockup
              FilledButton.icon(
                icon: const Icon(Icons.volume_up_rounded, size: 20),
                label: const Text(
                  'Speak',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: hasText ? LhColors.nuriBlue : LhColors.line2,
                  foregroundColor: hasText ? Colors.white : LhColors.ink3,
                  elevation: hasText ? 2 : 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: hasText ? _speak : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionBar() {
    return Container(
      height: 52,
      margin: const EdgeInsets.only(bottom: 6),
      child: _suggestions.isEmpty
          ? const Center(
              child: Text(
                'Type letters for word suggestions',
                style: TextStyle(fontSize: 13, color: LhColors.ink3),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _suggestions[index];
                return _buildSuggestionChip(item);
              },
            ),
    );
  }

  Widget _buildSuggestionChip(KeyboardSuggestion item) {
    final isCard = item.isPersonalCard;
    final isPhrase = item.isQuickPhrase;

    final bgColor = isCard
        ? const Color(0xFFFFFFA6) // Fitzgerald people/personal color
        : isPhrase
            ? LhColors.amberTint
            : LhColors.surface;

    final borderColor = isCard
        ? const Color(0xFFDBD06A)
        : isPhrase
            ? LhColors.amberLine
            : LhColors.line2;

    return Semantics(
      label: 'Suggestion: ${item.text}',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _insertSuggestion(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: LhShadows.tileRest,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCard) ...[
                if (item.iconUri != null && item.iconUri!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CompositeSymbolProvider.defaultInstance.buildSymbol(
                        context,
                        uri: item.iconUri!,
                        label: item.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ] else ...[
                  const Icon(Icons.star, size: 16, color: LhColors.amberDeep),
                  const SizedBox(width: 6),
                ],
              ] else if (isPhrase) ...[
                const Icon(Icons.chat_bubble_outline, size: 14, color: LhColors.brown),
                const SizedBox(width: 6),
              ],
              Text(
                item.text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isCard ? FontWeight.bold : FontWeight.w600,
                  color: LhColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVirtualKeyboard(bool isLandscape) {
    if (_numbersActive) {
      return _buildNumericLayout();
    }

    final lang = _currentLang.replaceAll('-', '_').toLowerCase();
    if (lang.startsWith('ar')) {
      return _buildArabicLayout();
    } else if (lang.startsWith('de')) {
      return _buildGermanLayout();
    } else {
      return _buildEnglishLayout();
    }
  }

  Widget _buildEnglishLayout() {
    const row1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
    const row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
    const row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

    return _buildKeyboardRows([
      row1,
      row2,
      row3,
    ]);
  }

  Widget _buildGermanLayout() {
    const row1 = ['q', 'w', 'e', 'r', 't', 'z', 'u', 'i', 'o', 'p', 'ü'];
    const row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ö', 'ä'];
    const row3 = ['y', 'x', 'c', 'v', 'b', 'n', 'm', 'ß'];

    return _buildKeyboardRows([
      row1,
      row2,
      row3,
    ]);
  }

  Widget _buildArabicLayout() {
    const row1 = ['ض', 'ص', 'ث', 'ق', 'ف', 'غ', 'ع', 'ه', 'خ', 'ح', 'ج', 'د'];
    const row2 = ['ش', 'س', 'ي', 'ب', 'ل', 'ا', 'ت', 'ن', 'م', 'ك', 'ط'];
    const row3 = ['ئ', 'ء', 'ؤ', 'ر', 'لا', 'ى', 'ة', 'و', 'ز', 'ظ'];

    return _buildKeyboardRows([
      row1,
      row2,
      row3,
    ]);
  }

  Widget _buildNumericLayout() {
    const row1 = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
    const row2 = ['@', '#', '\$', '%', '&', '*', '-', '+', '(', ')'];
    const row3 = ['!', '"', '\'', ':', ';', '/', '?', ',', '.'];

    return _buildKeyboardRows([
      row1,
      row2,
      row3,
    ]);
  }

  Widget _buildKeyboardRows(List<List<String>> rows) {
    return Container(
      color: LhColors.cream2,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        children: [
          for (final row in rows)
            Expanded(
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: _buildKey(
                        _shiftActive ? key.toUpperCase() : key,
                        onTap: () => _appendCharacter(key),
                      ),
                    ),
                ],
              ),
            ),
          // Bottom Functional Row (Shift/Num, Space, Period, Clear/Done)
          Expanded(
            child: Row(
              children: [
                // 123 / ABC toggle
                Expanded(
                  flex: 2,
                  child: _buildKey(
                    _numbersActive ? 'ABC' : '?123',
                    isSpecial: true,
                    onTap: () {
                      setState(() => _numbersActive = !_numbersActive);
                    },
                  ),
                ),
                // Shift toggle (for Latin)
                if (!_currentLang.startsWith('ar') && !_numbersActive)
                  Expanded(
                    flex: 2,
                    child: _buildKey(
                      _shiftActive ? '⬆' : '⇧',
                      isSpecial: true,
                      onTap: () {
                        setState(() => _shiftActive = !_shiftActive);
                      },
                    ),
                  ),
                // Space bar
                Expanded(
                  flex: 6,
                  child: _buildKey(
                    'Space',
                    isSpecial: false,
                    onTap: () => _appendCharacter(' '),
                  ),
                ),
                // Period
                Expanded(
                  flex: 2,
                  child: _buildKey(
                    '.',
                    onTap: () => _appendCharacter('.'),
                  ),
                ),
                // Comma
                Expanded(
                  flex: 2,
                  child: _buildKey(
                    ',',
                    onTap: () => _appendCharacter(','),
                  ),
                ),
                // Backspace
                Expanded(
                  flex: 2,
                  child: _buildKey(
                    '⌫',
                    isSpecial: true,
                    onTap: _backspace,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(
    String label, {
    required VoidCallback onTap,
    bool isSpecial = false,
  }) {
    String semanticLabel = label;
    if (label == 'Space') {
      semanticLabel = 'Space';
    } else if (label == '⌫') {
      semanticLabel = 'Backspace';
    } else if (label == '⇧' || label == '⬆') {
      semanticLabel = 'Shift';
    } else if (label == '?123') {
      semanticLabel = 'Numbers and symbols';
    } else if (label == 'ABC') {
      semanticLabel = 'Letters';
    }

    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: Semantics(
        label: semanticLabel,
        button: true,
        excludeSemantics: true,
        child: Material(
          color: isSpecial ? LhColors.cream : LhColors.surface,
          borderRadius: BorderRadius.circular(10),
          elevation: 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isSpecial ? 16 : 22,
                    fontWeight: FontWeight.bold,
                    color: isSpecial ? LhColors.brown : LhColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
