/// Visual First/Then schedule component for transition support and behavioral momentum.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/locale_registry.dart';
import '../../models/daily_schedule.dart';
import '../../services/symbols/composite_symbol_provider.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';
import 'activity_editor_dialog.dart';
import 'activity_expression_sheet.dart';

class FirstThenView extends ConsumerWidget {
  const FirstThenView({
    super.key,
    this.onNavigateToSchedule,
  });

  final VoidCallback? onNavigateToSchedule;

  Future<void> _speak(
    BuildContext context,
    WidgetRef ref,
    String text,
  ) async {
    final tts = ref.read(ttsEngineProvider);
    final locale = Localizations.localeOf(context);
    await tts.speak(text, locale: locale);
  }

  void _speakFirstThen(
    BuildContext context,
    WidgetRef ref,
    ScheduleActivity? first,
    ScheduleActivity? then,
  ) {
    if (first == null && then == null) return;
    final locale = Localizations.localeOf(context);
    final langCode = LocaleRegistry.codeForLocale(locale);

    final firstLabel = first?.speechFor(langCode) ?? '';
    final thenLabel = then?.speechFor(langCode) ?? '';

    String sentence;
    if (langCode == 'ar_dz') {
      if (first != null && then != null) {
        sentence = 'الاولى $firstLabel، و من بعد $thenLabel.';
      } else if (first != null) {
        sentence = 'الاولى $firstLabel.';
      } else {
        sentence = 'من بعد $thenLabel.';
      }
    } else if (langCode == 'ar') {
      if (first != null && then != null) {
        sentence = 'أولاً $firstLabel، ثم $thenLabel.';
      } else if (first != null) {
        sentence = 'أولاً $firstLabel.';
      } else {
        sentence = 'ثم $thenLabel.';
      }
    } else if (langCode == 'de') {
      if (first != null && then != null) {
        sentence = 'Zuerst $firstLabel, dann $thenLabel.';
      } else if (first != null) {
        sentence = 'Zuerst $firstLabel.';
      } else {
        sentence = 'Dann $thenLabel.';
      }
    } else {
      if (first != null && then != null) {
        sentence = 'First $firstLabel, then $thenLabel.';
      } else if (first != null) {
        sentence = 'First $firstLabel.';
      } else {
        sentence = 'Then $thenLabel.';
      }
    }

    _speak(context, ref, sentence);
  }

  void _showActivityPicker(
    BuildContext context,
    WidgetRef ref, {
    required bool isFirst,
    required List<ScheduleActivity> activities,
    required ScheduleActivity? currentFirst,
    required ScheduleActivity? currentThen,
  }) {
    final locale = Localizations.localeOf(context);
    final langCode = LocaleRegistry.codeForLocale(locale);

    final title = isFirst
        ? _localizedText(langCode, en: 'Choose FIRST Activity', de: 'ZUERST-Aktivität wählen', ar: 'اختر النشاط الأول', arDz: 'خيّر النشاط الأول')
        : _localizedText(langCode, en: 'Choose THEN Activity', de: 'DANN-Aktivität wählen', ar: 'اختر النشاط التالي', arDz: 'خيّر النشاط اللي موراه');

    showModalBottomSheet(
      context: context,
      backgroundColor: LhColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: LhColors.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: LhColors.ink,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(_localizedText(langCode, en: 'New', de: 'Neu', ar: 'جديد', arDz: 'جديد')),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final newAct = await ActivityEditorDialog.show(context);
                        if (newAct != null) {
                          await ref.read(dailyScheduleProvider.notifier).saveActivity(newAct);
                          if (isFirst) {
                            await ref.read(dailyScheduleProvider.notifier).setFirstThen(
                              newAct.id,
                              currentThen?.id ?? '',
                            );
                          } else {
                            await ref.read(dailyScheduleProvider.notifier).setFirstThen(
                              currentFirst?.id ?? '',
                              newAct.id,
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(color: LhColors.line),
              if (activities.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _localizedText(langCode, en: 'No activities in schedule yet.', de: 'Noch keine Aktivitäten vorhanden.', ar: 'لا توجد أنشطة في الجدول بعد.', arDz: 'ماكانش أنشطة فالبرنامج.'),
                    style: const TextStyle(color: LhColors.ink2),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: activities.length,
                    itemBuilder: (c, idx) {
                      final act = activities[idx];
                      final isSelected = isFirst ? (currentFirst?.id == act.id) : (currentThen?.id == act.id);
                      final label = act.labelFor(langCode);

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: ScheduleActivityCategory.colorFor(act.category),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: LhColors.line),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CompositeSymbolProvider.defaultInstance.buildSymbol(
                            context,
                            uri: act.imageUri,
                            label: label,
                          ),
                        ),
                        title: Text(
                          label,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? LhColors.primary : LhColors.ink,
                          ),
                        ),
                        subtitle: act.time != null ? Text(act.time!) : null,
                        trailing: isSelected ? const Icon(Icons.check_circle, color: LhColors.primary) : null,
                        onTap: () {
                          if (isFirst) {
                            ref.read(dailyScheduleProvider.notifier).setFirstThen(
                              act.id,
                              currentThen?.id ?? '',
                            );
                          } else {
                            ref.read(dailyScheduleProvider.notifier).setFirstThen(
                              currentFirst?.id ?? '',
                              act.id,
                            );
                          }
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _advanceSchedule(
    BuildContext context,
    WidgetRef ref,
    DailySchedule schedule,
    ScheduleActivity? first,
    ScheduleActivity? then,
  ) {
    if (first == null) return;

    // Mark current first as completed
    ref.read(dailyScheduleProvider.notifier).toggleCompleted(first.id);

    // If then exists, then becomes new first!
    if (then != null) {
      // Find candidate next activity from remaining incomplete activities
      final remaining = schedule.activities.where((a) => a.id != first.id && a.id != then.id && !a.isCompleted).toList();
      final nextCandidateId = remaining.isNotEmpty ? remaining.first.id : '';

      ref.read(dailyScheduleProvider.notifier).setFirstThen(then.id, nextCandidateId);
    }
  }

  void _swapFirstAndThen(
    WidgetRef ref,
    ScheduleActivity? first,
    ScheduleActivity? then,
  ) {
    if (first == null && then == null) return;
    ref.read(dailyScheduleProvider.notifier).setFirstThen(
      then?.id ?? '',
      first?.id ?? '',
    );
  }

  static String _localizedText(
    String lang, {
    required String en,
    required String de,
    required String ar,
    required String arDz,
  }) {
    switch (lang) {
      case 'de':
        return de;
      case 'ar_dz':
        return arDz;
      case 'ar':
        return ar;
      default:
        return en;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final langCode = LocaleRegistry.codeForLocale(locale);
    final isRtl = LocaleRegistry.isRtl(locale);

    final scheduleAsync = ref.watch(dailyScheduleProvider);
    final pair = ref.watch(firstThenActivitiesProvider);

    return scheduleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (schedule) {
        final first = pair.first;
        final then = pair.then;

        if (schedule.activities.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.view_agenda_outlined, size: 64, color: LhColors.ink2),
                  const SizedBox(height: 16),
                  Text(
                    _localizedText(
                      langCode,
                      en: 'No activities for First/Then',
                      de: 'Keine Aktivitäten für Zuerst/Dann',
                      ar: 'لا توجد أنشطة لجدول أولاً/ثم',
                      arDz: 'ماكانش أنشطة لجدول الأولى/من بعد',
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LhColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _localizedText(
                      langCode,
                      en: 'Load a routine template or create an activity to start.',
                      de: 'Laden Sie eine Vorlage oder erstellen Sie eine Aktivität.',
                      ar: 'قم بتحميل نموذج أو إضافة نشاط للبدء.',
                      arDz: 'حمّل نموذج أو زيد نشاط باش تبدا.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: LhColors.ink2),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(dailyScheduleProvider.notifier).applyTemplate('morning_routine');
                    },
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: Text(
                      _localizedText(
                        langCode,
                        en: 'Load Morning Routine',
                        de: 'Morgenroutine laden',
                        ar: 'تحميل الروتين الصباحي',
                        arDz: 'تحميل روتين الصباح',
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: LhColors.brown,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final isWide = MediaQuery.sizeOf(context).width >= 600;

        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Column(
            children: [
              // Top Action / TTS bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: LhColors.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _localizedText(
                          langCode,
                          en: 'First / Then Visual Support',
                          de: 'Zuerst / Dann Ablauf',
                          ar: 'جدول أولاً / ثم البصري',
                          arDz: 'جدول الأولى / من بعد',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: LhColors.ink,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: _localizedText(
                        langCode,
                        en: 'Speak Sequence',
                        de: 'Ablauf vorlesen',
                        ar: 'نطق الترتيب',
                        arDz: 'انطق الترتيب',
                      ),
                      icon: const Icon(Icons.volume_up),
                      onPressed: () => _speakFirstThen(context, ref, first, then),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: _localizedText(
                        langCode,
                        en: 'Swap First and Then',
                        de: 'Reihenfolge tauschen',
                        ar: 'تبديل الترتيب',
                        arDz: 'قلّب الترتيب',
                      ),
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: () => _swapFirstAndThen(ref, first, then),
                    ),
                  ],
                ),
              ),

              // Visual Cards Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildCard(
                                context,
                                ref,
                                isFirst: true,
                                activity: first,
                                langCode: langCode,
                                onSelect: () => _showActivityPicker(
                                  context,
                                  ref,
                                  isFirst: true,
                                  activities: schedule.activities,
                                  currentFirst: first,
                                  currentThen: then,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 120),
                              child: Icon(
                                isRtl ? Icons.arrow_back : Icons.arrow_forward,
                                size: 36,
                                color: LhColors.primary,
                              ),
                            ),
                            Expanded(
                              child: _buildCard(
                                context,
                                ref,
                                isFirst: false,
                                activity: then,
                                langCode: langCode,
                                onSelect: () => _showActivityPicker(
                                  context,
                                  ref,
                                  isFirst: false,
                                  activities: schedule.activities,
                                  currentFirst: first,
                                  currentThen: then,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildCard(
                              context,
                              ref,
                              isFirst: true,
                              activity: first,
                              langCode: langCode,
                              onSelect: () => _showActivityPicker(
                                context,
                                ref,
                                isFirst: true,
                                activities: schedule.activities,
                                currentFirst: first,
                                currentThen: then,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Icon(
                                Icons.arrow_downward,
                                size: 32,
                                color: LhColors.primary,
                              ),
                            ),
                            _buildCard(
                              context,
                              ref,
                              isFirst: false,
                              activity: then,
                              langCode: langCode,
                              onSelect: () => _showActivityPicker(
                                context,
                                ref,
                                isFirst: false,
                                activities: schedule.activities,
                                currentFirst: first,
                                currentThen: then,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Bottom Control Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: LhColors.line)),
                ),
                child: Row(
                  children: [
                    if (first != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: Text(
                            _localizedText(
                              langCode,
                              en: 'Express First',
                              de: 'Ausdrücken (1)',
                              ar: 'التعبير عن الأول',
                              arDz: 'نهدر على الأولى',
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: LhColors.ink,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => ActivityExpressionSheet.show(context, first),
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (first != null)
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(
                            _localizedText(
                              langCode,
                              en: 'Done & Next',
                              de: 'Fertig & Weiter',
                              ar: 'تم & التالي',
                              arDz: 'كملت & اللي موراه',
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _advanceSchedule(context, ref, schedule, first, then),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref, {
    required bool isFirst,
    required ScheduleActivity? activity,
    required String langCode,
    required VoidCallback onSelect,
  }) {
    final badgeTitle = isFirst
        ? _localizedText(langCode, en: '1. FIRST', de: '1. ZUERST', ar: '١. أولاً', arDz: '١. الأولى')
        : _localizedText(langCode, en: '2. THEN', de: '2. DANN', ar: '٢. ثُمّ', arDz: '٢. من بعد');

    final badgeColor = isFirst ? const Color(0xFF1565C0) : const Color(0xFF2E7D32);
    final bgColor = activity != null
        ? ScheduleActivityCategory.colorFor(activity.category)
        : LhColors.card;

    final label = activity != null ? activity.labelFor(langCode) : _localizedText(langCode, en: 'Select activity', de: 'Aktivität wählen', ar: 'اختر نشاطاً', arDz: 'خيّر نشاط');

    return Semantics(
      label: '$badgeTitle: $label',
      button: true,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        elevation: 2,
        shadowColor: LhColors.line,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: activity != null
              ? () => _speak(context, ref, activity.speechFor(langCode))
              : onSelect,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isFirst ? const Color(0xFF1565C0) : const Color(0xFF2E7D32),
                width: 2.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header badge row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _localizedText(
                        langCode,
                        en: 'Change Activity',
                        de: 'Aktivität ändern',
                        ar: 'تغيير النشاط',
                        arDz: 'بدل النشاط',
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onSelect,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Center Image / Symbol
                Center(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: LhColors.line, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: activity != null
                        ? CompositeSymbolProvider.defaultInstance.buildSymbol(
                            context,
                            uri: activity.imageUri,
                            label: label,
                          )
                        : const Icon(
                            Icons.touch_app_outlined,
                            size: 48,
                            color: LhColors.ink2,
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // Label Text
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: LhColors.ink,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                if (activity?.time != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time, size: 14, color: LhColors.ink2),
                      const SizedBox(width: 4),
                      Text(
                        activity!.time!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: LhColors.ink2,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                // Card Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.volume_up, size: 20),
                      onPressed: activity != null
                          ? () => _speak(context, ref, activity.speechFor(langCode))
                          : null,
                      tooltip: 'Speak',
                    ),
                    const SizedBox(width: 8),
                    if (activity != null)
                      IconButton.outlined(
                        icon: const Icon(Icons.chat_bubble_outline, size: 20),
                        onPressed: () => ActivityExpressionSheet.show(context, activity),
                        tooltip: 'Express',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
