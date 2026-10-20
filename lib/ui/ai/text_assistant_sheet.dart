/// Accessible AI Text Assistant & Translator Sheet.
///
/// Enables literate communicators and caregivers to type shorthand text,
/// generate natural complete sentences, and translate across English, German,
/// Modern Standard Arabic, and Algerian Darija.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/locale_registry.dart';
import '../../l10n/app_localizations.dart';
import '../../logic/ai/ai.dart';
import '../../models/models.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';

class TextAssistantSheet extends StatefulWidget {
  const TextAssistantSheet({
    required this.board,
    super.key,
  });

  final AACBoard board;

  static void show(BuildContext context, WidgetRef ref, AACBoard board) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LhColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TextAssistantSheet(board: board),
      ),
    );
  }

  @override
  State<TextAssistantSheet> createState() => _TextAssistantSheetState();
}

class _TextAssistantSheetState extends State<TextAssistantSheet> {
  final _controller = TextEditingController();
  final _textAssistant = const AITextAssistant();
  final _translator = const AIMultilingualTranslator();

  List<String> _suggestions = const [];
  String? _translatedText;
  String _targetLang = 'ar_dz';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query, String langCode) {
    setState(() {
      _suggestions = _textAssistant.getSuggestions(query, langCode);
      if (query.trim().isNotEmpty) {
        _translatedText = _translator.translate(query, targetLanguageCode: _targetLang);
      } else {
        _translatedText = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final locale = Localizations.localeOf(context);
        final langCode = LocaleRegistry.codeForLocale(locale);
        final l10n = AppLocalizations.of(context);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: LhColors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.aiAssistantTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: LhColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.aiAssistantInputHint,
                    filled: true,
                    fillColor: LhColors.cream,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: LhColors.line2),
                    ),
                    prefixIcon: const Icon(Icons.keyboard_outlined),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              _onQueryChanged('', langCode);
                            },
                          )
                        : null,
                  ),
                  onChanged: (q) => _onQueryChanged(q, langCode),
                ),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    l10n.aiSuggestionsHeader,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: LhColors.ink2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final suggestion in _suggestions) ...[
                    Card(
                      elevation: 0,
                      color: LhColors.cream2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: LhColors.line),
                      ),
                      child: ListTile(
                        title: Text(
                          suggestion,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: LhColors.ink,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.volume_up, color: LhColors.brown),
                          tooltip: l10n.speakSentence,
                          onPressed: () async {
                            final tts = ref.read(ttsEngineProvider);
                            await tts.speak(suggestion, locale: locale);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(l10n.translateTo,
                        style: const TextStyle(fontSize: 13, color: LhColors.ink2)),
                    DropdownButton<String>(
                      value: _targetLang,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                            value: 'ar_dz', child: Text('Algerian Darija (الدارجة)')),
                        DropdownMenuItem(
                            value: 'ar', child: Text('العربية (Standard)')),
                        DropdownMenuItem(
                            value: 'de', child: Text('Deutsch')),
                        DropdownMenuItem(
                            value: 'en', child: Text('English')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _targetLang = val;
                            if (_controller.text.isNotEmpty) {
                              _translatedText = _translator.translate(
                                _controller.text,
                                targetLanguageCode: _targetLang,
                              );
                            }
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (_translatedText != null && _translatedText!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: LhColors.amberTint,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: LhColors.amberLine),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _translatedText!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: LhColors.brown,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.volume_up, color: LhColors.brown),
                          onPressed: () async {
                            final targetSpec = LocaleRegistry.specForCode(_targetLang);
                            final targetLocale = targetSpec?.locale ?? locale;
                            await ref.read(ttsEngineProvider).speak(
                                  _translatedText!,
                                  locale: targetLocale,
                                );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
