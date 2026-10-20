/// Bottom sheet allowing the AAC user to express requests, refusals, questions,
/// and preferences for a scheduled activity.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/locale_registry.dart';
import '../../models/models.dart';
import '../../services/symbols/composite_symbol_provider.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';

class ActivityExpressionSheet extends ConsumerWidget {
  const ActivityExpressionSheet({
    super.key,
    required this.activity,
  });

  final ScheduleActivity activity;

  static Future<void> show(BuildContext context, ScheduleActivity activity) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActivityExpressionSheet(activity: activity),
    );
  }

  Future<void> _speak(
    BuildContext context,
    WidgetRef ref,
    String text, {
    bool addToSentence = false,
  }) async {
    final tts = ref.read(ttsEngineProvider);
    final locale = Localizations.localeOf(context);
    await tts.speak(text, locale: locale);

    if (addToSentence) {
      ref.read(utteranceProvider.notifier).commit(
        AACButton(
          id: 'activity_expr_${DateTime.now().millisecondsSinceEpoch}',
          label: text,
          labelByLocale: const {},
          type: AACButtonType.word,
          position: (row: 0, col: 0),
          category: 'expression',
          baseWeight: 0.5,
          iconUri: activity.iconUri.isNotEmpty
              ? activity.iconUri
              : 'assets/symbols/actions/talk.png',
          voiceOut: text,
        ),
      );
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final langCode = LocaleRegistry.codeForLocale(locale);
    final isRtl = LocaleRegistry.isRtl(locale);
    final activityName = activity.labelFor(langCode);

    // Expressions localized in English, German, Arabic, Algerian Darija
    final expressions = _buildExpressions(activityName, langCode);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: LhColors.cream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: LhShadows.pop,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: LhColors.line2,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Activity Header Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ScheduleActivityCategory.colorFor(activity.category),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: LhColors.line, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: LhColors.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CompositeSymbolProvider.defaultInstance.buildSymbol(
                          context,
                          uri: activity.imageUri,
                          label: activityName,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (activity.time != null)
                              Text(
                                activity.time!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: LhColors.ink2,
                                ),
                              ),
                            Text(
                              activityName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: LhColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filled(
                        icon: const Icon(Icons.volume_up, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: LhColors.brown,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _speak(
                          context,
                          ref,
                          activity.speechFor(langCode),
                        ),
                        tooltip: 'Speak Activity',
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(color: LhColors.line, height: 1),

              // Communicative Expression Options
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  itemCount: expressions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final exp = expressions[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _speak(context, ref, exp.spokenText),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: exp.bgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: exp.borderColor, width: 1.5),
                          boxShadow: LhShadows.card,
                        ),
                        child: Row(
                          children: [
                            Icon(exp.icon, color: exp.iconColor, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                exp.title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: exp.textColor,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_to_photos_outlined, size: 20),
                              tooltip: 'Add to Sentence Bar',
                              color: exp.iconColor,
                              onPressed: () => _speak(
                                context,
                                ref,
                                exp.spokenText,
                                addToSentence: true,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.volume_up, size: 20, color: exp.iconColor),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_ExpressionItem> _buildExpressions(String name, String lang) {
    final isAr = lang.startsWith('ar');
    final isDe = lang.startsWith('de');
    final isDz = lang == 'ar_dz' || lang == 'ar-DZ';

    return [
      _ExpressionItem(
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF2E7D32),
        bgColor: const Color(0xFFE8F5E9),
        borderColor: const Color(0xFFA5D6A7),
        textColor: const Color(0xFF1B5E20),
        title: isDz
            ? 'راني باغي $name'
            : (isAr
                ? 'أريد $name'
                : (isDe ? 'Ich möchte $name' : 'I want $name')),
        spokenText: isDz
            ? 'راني باغي $name'
            : (isAr
                ? 'أريد $name'
                : (isDe ? 'Ich möchte $name' : 'I want $name')),
      ),
      _ExpressionItem(
        icon: Icons.cancel_outlined,
        iconColor: const Color(0xFFC62828),
        bgColor: const Color(0xFFFFEBEE),
        borderColor: const Color(0xFFEF9A9A),
        textColor: const Color(0xFFB71C1C),
        title: isDz
            ? 'ما رانيش باغي دروك'
            : (isAr
                ? 'لا أريد $name الآن'
                : (isDe
                    ? 'Ich möchte $name jetzt nicht'
                    : 'I do not want $name right now')),
        spokenText: isDz
            ? 'ما رانيش باغي دروك، اصبر شوية'
            : (isAr
                ? 'لا أريد $name الآن'
                : (isDe
                    ? 'Ich möchte $name jetzt nicht'
                    : 'I do not want $name right now')),
      ),
      _ExpressionItem(
        icon: Icons.schedule,
        iconColor: const Color(0xFF1565C0),
        bgColor: const Color(0xFFE3F2FD),
        borderColor: const Color(0xFF90CAF9),
        textColor: const Color(0xFF0D47A1),
        title: isDz
            ? 'وقتاش $name؟'
            : (isAr
                ? 'متى $name؟'
                : (isDe ? 'Wann ist $name?' : 'When is $name?')),
        spokenText: isDz
            ? 'وقتاش $name؟'
            : (isAr
                ? 'متى $name؟'
                : (isDe ? 'Wann ist $name?' : 'When is $name?')),
      ),
      _ExpressionItem(
        icon: Icons.hourglass_top,
        iconColor: const Color(0xFFE65100),
        bgColor: const Color(0xFFFFF3E0),
        borderColor: const Color(0xFFFFCC80),
        textColor: const Color(0xFFBF360C),
        title: isDz
            ? 'نزيد شوية وقت تعيش'
            : (isAr
                ? 'المزيد من الوقت من فضلك'
                : (isDe ? 'Mehr Zeit bitte' : 'More time please')),
        spokenText: isDz
            ? 'نزيد شوية وقت تعيش'
            : (isAr
                ? 'المزيد من الوقت من فضلك'
                : (isDe ? 'Ich brauche mehr Zeit bitte' : 'I need more time please')),
      ),
      _ExpressionItem(
        icon: Icons.skip_next_outlined,
        iconColor: const Color(0xFF6A1B9A),
        bgColor: const Color(0xFFF3E5F5),
        borderColor: const Color(0xFFCE93D8),
        textColor: const Color(0xFF4A148C),
        title: isDz
            ? 'واش كاين من بعد؟'
            : (isAr
                ? 'ما هو النشاط التالي؟'
                : (isDe ? 'Was kommt als Nächstes?' : 'What is next?')),
        spokenText: isDz
            ? 'واش كاين من بعد؟'
            : (isAr
                ? 'ما هو النشاط التالي؟'
                : (isDe ? 'Was kommt als Nächstes?' : 'What activity is next?')),
      ),
      _ExpressionItem(
        icon: Icons.swap_horiz,
        iconColor: const Color(0xFF00695C),
        bgColor: const Color(0xFFE0F2F1),
        borderColor: const Color(0xFF80CBC4),
        textColor: const Color(0xFF004D40),
        title: isDz
            ? 'نقدرو نبدلو هذا النشاط؟'
            : (isAr
                ? 'هل يمكننا تغيير هذا؟'
                : (isDe ? 'Können wir das ändern?' : 'Can we change this?')),
        spokenText: isDz
            ? 'نقدرو نبدلو هذا النشاط؟'
            : (isAr
                ? 'هل يمكننا تغيير هذا النشاط؟'
                : (isDe ? 'Können wir diese Aktivität ändern?' : 'Can we change this activity?')),
      ),
      _ExpressionItem(
        icon: Icons.task_alt,
        iconColor: const Color(0xFF2E7D32),
        bgColor: const Color(0xFFF1F8E9),
        borderColor: const Color(0xFFC5E1A5),
        textColor: const Color(0xFF33691E),
        title: isDz
            ? 'راني كملت!'
            : (isAr
                ? 'انتهيت من هذا النشاط!'
                : (isDe ? 'Ich bin fertig!' : 'I am all done!')),
        spokenText: isDz
            ? 'راني كملت هذا النشاط، الحمد لله!'
            : (isAr
                ? 'انتهيت من هذا النشاط!'
                : (isDe ? 'Ich bin mit dieser Aktivität fertig!' : 'I am all done with this activity!')),
      ),
    ];
  }
}

class _ExpressionItem {
  const _ExpressionItem({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.title,
    required this.spokenText,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final String title;
  final String spokenText;
}
