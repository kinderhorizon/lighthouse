/// Dialog/Screen for caregivers and users to create or edit a scheduled activity.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../i18n/locale_registry.dart';
import '../../models/daily_schedule.dart';
import '../../services/symbols/composite_symbol_provider.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';

class ActivityEditorDialog extends ConsumerStatefulWidget {
  const ActivityEditorDialog({
    super.key,
    this.initialActivity,
  });

  final ScheduleActivity? initialActivity;

  static Future<ScheduleActivity?> show(
    BuildContext context, {
    ScheduleActivity? activity,
  }) {
    return showDialog<ScheduleActivity>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ActivityEditorDialog(initialActivity: activity),
    );
  }

  @override
  ConsumerState<ActivityEditorDialog> createState() => _ActivityEditorDialogState();
}

class _ActivityEditorDialogState extends ConsumerState<ActivityEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _titleDeController;
  late final TextEditingController _titleArController;
  late final TextEditingController _titleArDzController;

  late TimeOfDay? _selectedTime;
  late int _durationMinutes;
  late String _category;
  String? _symbolUri;
  bool _showTranslations = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final act = widget.initialActivity;
    _titleController = TextEditingController(text: act?.title ?? '');
    _titleDeController = TextEditingController(text: act?.labelsByLocale['de'] ?? '');
    _titleArController = TextEditingController(text: act?.labelsByLocale['ar'] ?? '');
    _titleArDzController = TextEditingController(text: act?.labelsByLocale['ar_dz'] ?? '');

    if (act?.time != null && act!.time!.contains(':')) {
      final parts = act.time!.split(':');
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 0;
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    } else {
      _selectedTime = null;
    }

    _durationMinutes = act?.durationMinutes ?? 30;
    _category = act?.category ?? ScheduleActivityCategory.routine;
    _symbolUri = act?.imageUri;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleDeController.dispose();
    _titleArController.dispose();
    _titleArDzController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _symbolUri = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load image: $e')),
        );
      }
    }
  }

  Future<void> _pickSymbol() async {
    final symbols = [
      ('Wake Up', 'assets/symbols/actions/go.png'),
      ('Breakfast', 'assets/symbols/food/food.png'),
      ('Brush Teeth', 'assets/symbols/actions/wash.png'),
      ('Get Dressed', 'assets/symbols/things/shirt.png'),
      ('School', 'assets/symbols/places/school.png'),
      ('Play / Fun', 'assets/symbols/activities/play.png'),
      ('Lunch', 'assets/symbols/food/food.png'),
      ('Drink Water', 'assets/symbols/food/water.png'),
      ('Therapy / Study', 'assets/symbols/actions/read.png'),
      ('Rest / Relax', 'assets/symbols/actions/wait.png'),
      ('Shower / Bath', 'assets/symbols/actions/wash.png'),
      ('Bedtime / Sleep', 'assets/symbols/actions/sleep.png'),
    ];

    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Symbol'),
        content: SizedBox(
          width: 320,
          height: 380,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: symbols.length,
            itemBuilder: (_, idx) {
              final s = symbols[idx];
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(ctx).pop(s.$2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: CompositeSymbolProvider.defaultInstance.buildSymbol(
                        context,
                        uri: s.$2,
                        label: s.$1,
                      ),
                    ),
                    Text(
                      s.$1,
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    if (chosen != null) {
      setState(() => _symbolUri = chosen);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _testSpeech() async {
    final text = _titleController.text.trim();
    if (text.isEmpty) return;
    final locale = Localizations.localeOf(context);
    final tts = ref.read(ttsEngineProvider);
    await tts.speak(text, locale: locale);
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an activity title')),
      );
      return;
    }

    final id = widget.initialActivity?.id ?? 'act_${DateTime.now().millisecondsSinceEpoch}';

    String? timeString;
    if (_selectedTime != null) {
      final h = _selectedTime!.hour.toString().padLeft(2, '0');
      final m = _selectedTime!.minute.toString().padLeft(2, '0');
      timeString = '$h:$m';
    }

    final localizedLabels = <String, String>{
      'en': title,
    };
    if (_titleDeController.text.trim().isNotEmpty) {
      localizedLabels['de'] = _titleDeController.text.trim();
    }
    if (_titleArController.text.trim().isNotEmpty) {
      localizedLabels['ar'] = _titleArController.text.trim();
    }
    if (_titleArDzController.text.trim().isNotEmpty) {
      localizedLabels['ar_dz'] = _titleArDzController.text.trim();
    }

    final activity = ScheduleActivity(
      id: id,
      title: title,
      time: timeString,
      imageUri: _symbolUri ?? '',
      durationMinutes: _durationMinutes,
      category: _category,
      isCompleted: widget.initialActivity?.isCompleted ?? false,
      labelsByLocale: localizedLabels,
      speechByLocale: localizedLabels,
    );

    Navigator.of(context).pop(activity);
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

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final langCode = LocaleRegistry.codeForLocale(locale);
    final isRtl = LocaleRegistry.isRtl(locale);

    final title = widget.initialActivity == null
        ? _localized(langCode, en: 'New Activity', de: 'Neue Aktivität', ar: 'نشاط جديد', arDz: 'نشاط جديد')
        : _localized(langCode, en: 'Edit Activity', de: 'Aktivität bearbeiten', ar: 'تعديل النشاط', arDz: 'تعديل النشاط');

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: LhColors.cream,
        child: Container(
          width: 480,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: LhColors.ink,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(color: LhColors.line, height: 1),

              // Form fields
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Preview Box
                      Center(
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: ScheduleActivityCategory.colorFor(_category),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: LhColors.line, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _symbolUri != null
                                ? CompositeSymbolProvider.defaultInstance.buildSymbol(
                                    context,
                                    uri: _symbolUri!,
                                    label: _titleController.text,
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 40,
                                      color: LhColors.ink2,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Image source buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.outlined(
                            tooltip: 'Camera',
                            icon: const Icon(Icons.photo_camera, size: 20),
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: 'Gallery',
                            icon: const Icon(Icons.photo_library, size: 20),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: 'Symbols',
                            icon: const Icon(Icons.category_outlined, size: 20),
                            onPressed: _pickSymbol,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Title input
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: _localized(langCode, en: 'Activity Name', de: 'Aktivitätsname', ar: 'اسم النشاط', arDz: 'اسم النشاط'),
                          hintText: 'e.g. Breakfast, Brush Teeth...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.volume_up),
                            tooltip: 'Test Speech',
                            onPressed: _testSpeech,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),

                      // Category Selector
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: InputDecoration(
                          labelText: _localized(langCode, en: 'Category', de: 'Kategorie', ar: 'الفئة', arDz: 'النوع'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ScheduleActivityCategory.all.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: ScheduleActivityCategory.colorFor(cat),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: LhColors.line),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(ScheduleActivityCategory.nameFor(cat, langCode)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _category = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Time and Duration
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.access_time),
                              label: Text(
                                _selectedTime != null
                                    ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                                    : _localized(langCode, en: 'Set Time', de: 'Zeit setzen', ar: 'حدد الوقت', arDz: 'دير الوقت'),
                              ),
                              onPressed: _selectTime,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _durationMinutes,
                              decoration: InputDecoration(
                                labelText: _localized(langCode, en: 'Duration', de: 'Dauer', ar: 'المدة', arDz: 'المدة'),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                              items: const [
                                DropdownMenuItem(value: 5, child: Text('5 min')),
                                DropdownMenuItem(value: 10, child: Text('10 min')),
                                DropdownMenuItem(value: 15, child: Text('15 min')),
                                DropdownMenuItem(value: 30, child: Text('30 min')),
                                DropdownMenuItem(value: 45, child: Text('45 min')),
                                DropdownMenuItem(value: 60, child: Text('60 min')),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _durationMinutes = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Expand Multilingual Translations Accordion
                      InkWell(
                        onTap: () => setState(() => _showTranslations = !_showTranslations),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                _showTranslations ? Icons.expand_less : Icons.expand_more,
                                color: LhColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _localized(
                                  langCode,
                                  en: 'Multilingual Names (AR, DZ, DE, EN)',
                                  de: 'Mehrsprachige Namen (AR, DZ, DE, EN)',
                                  ar: 'الأسماء بلغات متعددة (عربي، دارجة، ألماني، إنجليزي)',
                                  arDz: 'الأسماء باللغات الأخرى',
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: LhColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_showTranslations) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _titleDeController,
                          decoration: InputDecoration(
                            labelText: 'German (de)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _titleArController,
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            labelText: 'Arabic (العربية)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _titleArDzController,
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            labelText: 'Algerian Darija (الدارجة)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              const Divider(color: LhColors.line, height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(_localized(langCode, en: 'Cancel', de: 'Abbrechen', ar: 'إلغاء', arDz: 'إلغاء')),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: LhColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _save,
                      child: Text(_localized(langCode, en: 'Save', de: 'Speichern', ar: 'حفظ', arDz: 'حفظ')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
