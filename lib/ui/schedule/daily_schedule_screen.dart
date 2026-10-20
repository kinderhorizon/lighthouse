/// Daily Routine, Visual Schedule, First/Then, and Visual Timer host screen.
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
import 'first_then_view.dart';
import 'manage_elements_screen.dart';
import 'visual_timer_view.dart';
import '../widgets/nuritalk_brand_logo.dart';

class DailyScheduleScreen extends ConsumerStatefulWidget {
  const DailyScheduleScreen({
    super.key,
    this.initialTab = 0,
  });

  /// 0 = Daily Schedule, 1 = First/Then, 2 = Visual Timer
  final int initialTab;

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyScheduleScreen(initialTab: initialTab),
      ),
    );
  }

  @override
  ConsumerState<DailyScheduleScreen> createState() => _DailyScheduleScreenState();
}

class _DailyScheduleScreenState extends ConsumerState<DailyScheduleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _caregiverMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static String _localized(
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

  Future<void> _showTemplatePicker(String langCode) async {
    final templates = ref.read(scheduleTemplatesProvider);

    await showModalBottomSheet(
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      _localized(
                        langCode,
                        en: 'Apply Routine Template',
                        de: 'Routine-Vorlage laden',
                        ar: 'تحميل نموذج الروتين',
                        arDz: 'تحميل نموذج البرنامج',
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: LhColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: LhColors.line),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  itemBuilder: (_, idx) {
                    final tmpl = templates[idx];
                    final title = tmpl.titleFor(langCode);
                    final desc = tmpl.descriptionFor(langCode);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: LhColors.sand,
                        foregroundColor: LhColors.brown,
                        child: Text('${tmpl.activities.length}'),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(desc),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text(title),
                            content: Text(
                              _localized(
                                langCode,
                                en: 'Do you want to replace current schedule or add to it?',
                                de: 'Möchten Sie den aktuellen Ablauf ersetzen oder anhängen?',
                                ar: 'هل تريد استبدال الجدول الحالي أم الإضافة عليه؟',
                                arDz: 'راك حاب تبدل البرنامج كامل ولا تزيد عليه؟',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(c).pop(null),
                                child: Text(_localized(langCode, en: 'Cancel', de: 'Abbrechen', ar: 'إلغاء', arDz: 'إلغاء')),
                              ),
                              OutlinedButton(
                                onPressed: () => Navigator.of(c).pop(false),
                                child: Text(_localized(langCode, en: 'Add To Current', de: 'Anhängen', ar: 'إضافة للجدول', arDz: 'زيد عليه')),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(c).pop(true),
                                child: Text(_localized(langCode, en: 'Replace All', de: 'Ersetzen', ar: 'استبدال الكل', arDz: 'بدل كامل')),
                              ),
                            ],
                          ),
                        );

                        if (confirm != null) {
                          await ref.read(dailyScheduleProvider.notifier).applyTemplate(
                                tmpl.id,
                                replace: confirm,
                              );
                        }
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

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final langCode = LocaleRegistry.codeForLocale(locale);
    final isRtl = LocaleRegistry.isRtl(locale);

    final title = _localized(
      langCode,
      en: 'Routines & Time',
      de: 'Abläufe & Zeit',
      ar: 'الروتين والوقت',
      arDz: 'الروتين والوقت',
    );

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: LhColors.cream,
        appBar: AppBar(
          backgroundColor: LhColors.surface,
          foregroundColor: LhColors.ink,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NuriTalkBrandLogo(height: 24, fontSize: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: LhColors.nuriNavy),
                ),
              ),
            ],
          ),
          actions: [
            // Manage Elements Button (Mockup 4)
            IconButton(
              tooltip: _localized(
                langCode,
                en: 'Manage Elements',
                de: 'Elemente verwalten',
                ar: 'إدارة العناصر',
                arDz: 'إدارة العناصر',
              ),
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => ManageElementsScreen.show(context),
            ),
            // Template Button
            IconButton(
              tooltip: _localized(
                langCode,
                en: 'Templates',
                de: 'Vorlagen',
                ar: 'النماذج',
                arDz: 'النماذج',
              ),
              icon: const Icon(Icons.bookmark_border),
              onPressed: () => _showTemplatePicker(langCode),
            ),
            // Caregiver Edit Mode Toggle
            IconButton(
              tooltip: _caregiverMode
                  ? _localized(langCode, en: 'Communicator Mode', de: 'Kommunikationsmodus', ar: 'وضع التواصل', arDz: 'وضع التواصل')
                  : _localized(langCode, en: 'Caregiver Edit Mode', de: 'Bearbeitungsmodus', ar: 'وضع التعديل', arDz: 'وضع التعديل'),
              icon: Icon(
                _caregiverMode ? Icons.lock_open : Icons.edit_note,
                color: _caregiverMode ? LhColors.nuriBlue : LhColors.ink,
              ),
              onPressed: () {
                setState(() => _caregiverMode = !_caregiverMode);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(milliseconds: 1500),
                    content: Text(
                      _caregiverMode
                          ? _localized(langCode, en: 'Caregiver Edit Mode active', de: 'Bearbeitungsmodus aktiv', ar: 'تم تفعيل وضع التعديل', arDz: 'وضع التعديل مفعل')
                          : _localized(langCode, en: 'Communicator Mode active', de: 'Kommunikationsmodus aktiv', ar: 'تم تفعيل وضع التواصل', arDz: 'وضع التواصل مفعل'),
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: LhColors.nuriBlue,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          tooltip: _localized(langCode, en: 'Add Step', de: 'Schritt hinzufügen', ar: 'إضافة خطوة', arDz: 'زيد خطوة'),
          onPressed: () async {
            final newAct = await ActivityEditorDialog.show(context);
            if (newAct != null) {
              await ref.read(dailyScheduleProvider.notifier).saveActivity(newAct);
            }
          },
          child: const Icon(Icons.add, size: 28),
        ),
        body: Column(
          children: [
            // Header Subtitle + Segmented Pill TabBar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              color: LhColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _localized(
                      langCode,
                      en: 'Make daily steps visible for clarity and security.',
                      de: 'Alltagsschritte sichtbar machen. Für mehr Orientierung und Sicherheit.',
                      ar: 'توضيح خطوات اليوم لمزيد من الراحة والأمان.',
                      arDz: 'توضيح خطوات اليوم لمزيد من الراحة والأمان.',
                    ),
                    style: const TextStyle(fontSize: 12, color: LhColors.ink2),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEFF5),
                      borderRadius: BorderRadius.circular(21),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: LhColors.nuriNavy,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: LhColors.ink2,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(
                          text: _localized(langCode, en: 'Schedule', de: 'Tagesplan', ar: 'الجدول', arDz: 'البرنامج'),
                        ),
                        Tab(
                          text: _localized(langCode, en: 'First / Then', de: 'Zuerst / Dann', ar: 'أولاً / ثم', arDz: 'الأولى / من بعد'),
                        ),
                        Tab(
                          text: _localized(langCode, en: 'Timer', de: 'Timer', ar: 'المؤقت', arDz: 'المؤقت'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: LhColors.line2),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildScheduleTab(context, langCode),
                  FirstThenView(
                    onNavigateToSchedule: () => _tabController.animateTo(0),
                  ),
                  const VisualTimerView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTab(BuildContext context, String langCode) {
    final scheduleAsync = ref.watch(dailyScheduleProvider);

    return scheduleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (schedule) {
        if (schedule.activities.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 64, color: LhColors.ink2),
                  const SizedBox(height: 16),
                  Text(
                    _localized(
                      langCode,
                      en: 'No activities scheduled for today',
                      de: 'Heute keine Aktivitäten geplant',
                      ar: 'لا توجد أنشطة مجدولة اليوم',
                      arDz: 'ماكانش أنشطة مبرمجة لليوم',
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LhColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _localized(
                      langCode,
                      en: 'Start by choosing a routine template or adding a custom activity.',
                      de: 'Wählen Sie eine Vorlage oder erstellen Sie eine eigene Aktivität.',
                      ar: 'ابدأ باختيار نموذج روتين أو إضافة نشاط مخصص.',
                      arDz: 'اختر نموذج للروتين أو زيد نشاط مخصص باش تبدا.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: LhColors.ink2),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.wb_sunny_outlined),
                        label: Text(_localized(langCode, en: 'Morning Routine', de: 'Morgenroutine', ar: 'روتين الصباح', arDz: 'روتين الصباح')),
                        style: FilledButton.styleFrom(backgroundColor: LhColors.brown),
                        onPressed: () {
                          ref.read(dailyScheduleProvider.notifier).applyTemplate('morning_routine');
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.school_outlined),
                        label: Text(_localized(langCode, en: 'School Day', de: 'Schultag', ar: 'يوم المدرسة', arDz: 'المدرسة')),
                        onPressed: () {
                          ref.read(dailyScheduleProvider.notifier).applyTemplate('school_routine');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        final completedCount = schedule.activities.where((a) => a.isCompleted).length;
        final totalCount = schedule.activities.length;
        final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

        return Column(
          children: [
            // Tagesfortschritt Progress Card (Mockup 3)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LhColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LhColors.line2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF4D4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wb_sunny_rounded,
                          color: Color(0xFFFFA000),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _localized(
                          langCode,
                          en: 'Daily Progress',
                          de: 'Tagesfortschritt',
                          ar: 'إنجاز اليوم',
                          arDz: 'برنامج اليوم',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: LhColors.nuriNavy,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5EEF3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$completedCount / $totalCount',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: LhColors.nuriTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE5EEF3),
                      valueColor: const AlwaysStoppedAnimation<Color>(LhColors.nuriTeal),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${(progress * 100).toInt()}% ${_localized(langCode, en: 'done', de: 'erledigt', ar: 'مكتمل', arDz: 'كامل')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: LhColors.nuriNavy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _localized(
                            langCode,
                            en: 'Great job! Keep going.',
                            de: 'Toll gemacht! Weiter so.',
                            ar: 'عمل رائع! واصل التقدم.',
                            arDz: 'يعطيك الصحة! كمل هكذا.',
                          ),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: LhColors.ink2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Activities List matching Mockup 3
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                itemCount: schedule.activities.length + 1,
                itemBuilder: (ctx, idx) {
                  if (idx == schedule.activities.length) {
                    // Dashed "+ Neuen Schritt hinzufügen" card at bottom
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final newAct = await ActivityEditorDialog.show(context);
                        if (newAct != null) {
                          await ref.read(dailyScheduleProvider.notifier).saveActivity(newAct);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: LhColors.nuriBlue.withAlpha(140),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_circle_outline, color: LhColors.nuriBlue, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _localized(
                                langCode,
                                en: 'Add new step',
                                de: 'Neuen Schritt hinzufügen',
                                ar: 'إضافة خطوة جديدة',
                                arDz: 'زيد خطوة جديدة',
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: LhColors.nuriBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final act = schedule.activities[idx];
                  return _buildActivityTile(
                    context,
                    act,
                    langCode,
                    key: ValueKey(act.id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityTile(
    BuildContext context,
    ScheduleActivity activity,
    String langCode, {
    required Key key,
  }) {
    final label = activity.labelFor(langCode);
    final bgColor = ScheduleActivityCategory.colorFor(activity.category);

    return Semantics(
      label: '$label, ${activity.time ?? ''}, ${activity.durationMinutes} Min',
      checked: activity.isCompleted,
      hint: activity.isCompleted ? 'Marked complete' : 'Not completed',
      child: Container(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: activity.isCompleted ? const Color(0xFFF9FBFC) : LhColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: activity.isCompleted ? LhColors.line2 : LhColors.line2,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // Tapping opens ActivityExpressionSheet
              ActivityExpressionSheet.show(context, activity);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // 6-dot drag indicator
                  const Icon(Icons.drag_indicator, color: LhColors.ink3, size: 22),
                  const SizedBox(width: 8),
                  // Category icon / image in circular avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: CompositeSymbolProvider.defaultInstance.buildSymbol(
                            context,
                            uri: activity.imageUri,
                            label: label,
                            height: 26,
                          ),
                        ),
                        if (activity.isCompleted)
                          Container(
                            color: const Color(0xFF2E7D32).withAlpha(40),
                            child: const Icon(Icons.check, color: Color(0xFF2E7D32), size: 24),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and time badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: activity.isCompleted ? LhColors.ink2 : LhColors.ink,
                            decoration: activity.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (activity.time != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F4F8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time, size: 12, color: LhColors.ink2),
                                    const SizedBox(width: 4),
                                    Text(
                                      activity.time!,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: LhColors.ink),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              '${activity.durationMinutes} Min',
                              style: const TextStyle(fontSize: 12, color: LhColors.ink2),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Checkmark toggle button (min 48x48 touch target)
                  IconButton(
                    iconSize: 24,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: Icon(
                      activity.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: activity.isCompleted ? const Color(0xFF2E7D32) : LhColors.ink3,
                      size: 24,
                    ),
                    tooltip: activity.isCompleted ? 'Mark Incomplete' : 'Mark Done',
                    onPressed: () {
                      ref.read(dailyScheduleProvider.notifier).toggleCompleted(activity.id);
                    },
                  ),
                  // Edit button (min 48x48 touch target)
                  IconButton(
                    iconSize: 20,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.edit_outlined, size: 20, color: LhColors.ink2),
                    tooltip: 'Edit Activity',
                    onPressed: () async {
                      final edited = await ActivityEditorDialog.show(context, activity: activity);
                      if (edited != null) {
                        await ref.read(dailyScheduleProvider.notifier).saveActivity(edited);
                      }
                    },
                  ),
                  // Delete button (min 48x48 touch target)
                  IconButton(
                    iconSize: 20,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFC62828)),
                    tooltip: 'Delete Activity',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Delete Activity'),
                          content: Text('Remove "$label" from schedule?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(c).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
                              onPressed: () => Navigator.of(c).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(dailyScheduleProvider.notifier).deleteActivity(activity.id);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

