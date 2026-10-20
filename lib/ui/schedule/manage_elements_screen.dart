/// Manage Elements Screen ("Elemente verwalten") - Mockup 4
///
/// Features:
/// - 24+ comprehensive daily life routine activities across categories:
///   Morgen / Routine, Freizeit, Schule, Essen, Körper / Hygiene, Bettzeit.
/// - Search bar with real-time text filter.
/// - Category pill filter chips with item counts.
/// - Switch toggle to enable/disable elements in active daily schedule.
/// - Drag handles, edit, delete, and "+ Neu hinzufügen" full-width button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/locale_registry.dart';
import '../../models/daily_schedule.dart';
import '../../services/symbols/composite_symbol_provider.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';
import '../widgets/nuritalk_brand_logo.dart';
import 'activity_editor_dialog.dart';

class ManageElementsScreen extends ConsumerStatefulWidget {
  const ManageElementsScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManageElementsScreen()),
    );
  }

  @override
  ConsumerState<ManageElementsScreen> createState() => _ManageElementsScreenState();
}

class _ManageElementsScreenState extends ConsumerState<ManageElementsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 24 bundled rich daily elements
  static const List<ScheduleActivity> _bundledElements = [
    ScheduleActivity(
      id: 'elem_wake_up',
      title: 'Aufstehen',
      category: ScheduleActivityCategory.routine,
      durationMinutes: 10,
      imageUri: '',
      labelsByLocale: {
        'de': 'Aufstehen',
        'en': 'Wake up',
        'ar': 'الاستيقاظ من النوم',
        'ar_dz': 'تنوض من النعاس',
      },
    ),
    ScheduleActivity(
      id: 'elem_teeth_morning',
      title: 'Zähne putzen',
      category: ScheduleActivityCategory.hygiene,
      durationMinutes: 5,
      imageUri: '',
      labelsByLocale: {
        'de': 'Zähne putzen',
        'en': 'Brush teeth',
        'ar': 'تنظيف الأسنان',
        'ar_dz': 'غسل السنان',
      },
    ),
    ScheduleActivity(
      id: 'elem_wash_face',
      title: 'Gesicht waschen',
      category: ScheduleActivityCategory.hygiene,
      durationMinutes: 5,
      imageUri: '',
      labelsByLocale: {
        'de': 'Gesicht waschen',
        'en': 'Wash face',
        'ar': 'غسل الوجه',
        'ar_dz': 'غسل الوجه',
      },
    ),
    ScheduleActivity(
      id: 'elem_dress',
      title: 'Anziehen',
      category: ScheduleActivityCategory.routine,
      durationMinutes: 15,
      imageUri: '',
      labelsByLocale: {
        'de': 'Anziehen',
        'en': 'Get dressed',
        'ar': 'ارتداء الملابس',
        'ar_dz': 'لبس قشك',
      },
    ),
    ScheduleActivity(
      id: 'elem_breakfast',
      title: 'Frühstücken',
      category: ScheduleActivityCategory.meal,
      durationMinutes: 20,
      imageUri: '',
      labelsByLocale: {
        'de': 'Frühstücken',
        'en': 'Eat breakfast',
        'ar': 'تناول الفطور',
        'ar_dz': 'الفطور',
      },
    ),
    ScheduleActivity(
      id: 'elem_pack_bag',
      title: 'Schultasche packen',
      category: ScheduleActivityCategory.school,
      durationMinutes: 10,
      imageUri: '',
      labelsByLocale: {
        'de': 'Schultasche packen',
        'en': 'Pack school bag',
        'ar': 'تجهيز المحفظة',
        'ar_dz': 'توجاد الكرطابة',
      },
    ),
    ScheduleActivity(
      id: 'elem_shoes_jacket',
      title: 'Schuhe & Jacke',
      category: ScheduleActivityCategory.routine,
      durationMinutes: 10,
      imageUri: '',
      labelsByLocale: {
        'de': 'Schuhe & Jacke',
        'en': 'Shoes & jacket',
        'ar': 'الحذاء والمعطف',
        'ar_dz': 'الصباط والفيستة',
      },
    ),
    ScheduleActivity(
      id: 'elem_go_school',
      title: 'Zur Schule gehen',
      category: ScheduleActivityCategory.school,
      durationMinutes: 25,
      imageUri: '',
      labelsByLocale: {
        'de': 'Zur Schule gehen',
        'en': 'Go to school',
        'ar': 'الذهاب إلى المدرسة',
        'ar_dz': 'الذهاب للمدرسة',
      },
    ),
    ScheduleActivity(
      id: 'elem_class',
      title: 'Unterricht & Lernen',
      category: ScheduleActivityCategory.school,
      durationMinutes: 45,
      imageUri: '',
      labelsByLocale: {
        'de': 'Unterricht & Lernen',
        'en': 'Classroom learning',
        'ar': 'الدرس والتعلم',
        'ar_dz': 'القراية في القسم',
      },
    ),
    ScheduleActivity(
      id: 'elem_snack',
      title: 'Pausenbrot essen',
      category: ScheduleActivityCategory.meal,
      durationMinutes: 15,
      imageUri: '',
      labelsByLocale: {
        'de': 'Pausenbrot essen',
        'en': 'Eat snack',
        'ar': 'وجبة الاستراحة',
        'ar_dz': 'الكسكروت تاع الراحة',
      },
    ),
    ScheduleActivity(
      id: 'elem_playground',
      title: 'Spielplatz spielen',
      category: ScheduleActivityCategory.leisure,
      durationMinutes: 30,
      imageUri: '',
      labelsByLocale: {
        'de': 'Spielplatz spielen',
        'en': 'Playground play',
        'ar': 'اللعب في الحديقة',
        'ar_dz': 'اللعب في الجردينة',
      },
    ),
    ScheduleActivity(
      id: 'elem_come_home',
      title: 'Nach Hause kommen',
      category: ScheduleActivityCategory.routine,
      durationMinutes: 15,
      imageUri: '',
      labelsByLocale: {
        'de': 'Nach Hause kommen',
        'en': 'Come back home',
        'ar': 'العودة للمنزل',
        'ar_dz': 'الرجوع للدار',
      },
    ),
    ScheduleActivity(
      id: 'elem_wash_hands',
      title: 'Hände waschen',
      category: ScheduleActivityCategory.hygiene,
      durationMinutes: 5,
      imageUri: '',
      labelsByLocale: {
        'de': 'Hände waschen',
        'en': 'Wash hands',
        'ar': 'غسل اليدين',
        'ar_dz': 'غسل اليدين',
      },
    ),
    ScheduleActivity(
      id: 'elem_lunch',
      title: 'Mittagessen',
      category: ScheduleActivityCategory.meal,
      durationMinutes: 30,
      imageUri: '',
      labelsByLocale: {
        'de': 'Mittagessen',
        'en': 'Eat lunch',
        'ar': 'تناول الغداء',
        'ar_dz': 'الغدا',
      },
    ),
    ScheduleActivity(
      id: 'elem_homework',
      title: 'Hausaufgaben machen',
      category: ScheduleActivityCategory.school,
      durationMinutes: 30,
      imageUri: '',
      labelsByLocale: {
        'de': 'Hausaufgaben machen',
        'en': 'Do homework',
        'ar': 'إنجاز الواجبات',
        'ar_dz': 'حل التمارين',
      },
    ),
    ScheduleActivity(
      id: 'elem_free_play',
      title: 'Freies Spielen',
      category: ScheduleActivityCategory.leisure,
      durationMinutes: 45,
      imageUri: '',
      labelsByLocale: {
        'de': 'Freies Spielen',
        'en': 'Free play',
        'ar': 'وقت اللعب الحر',
        'ar_dz': 'وقت اللعب',
      },
    ),
    ScheduleActivity(
      id: 'elem_tablet_music',
      title: 'Musik hören / Tablet',
      category: ScheduleActivityCategory.leisure,
      durationMinutes: 20,
      imageUri: '',
      labelsByLocale: {
        'de': 'Musik hören / Tablet',
        'en': 'Listen to music / Tablet',
        'ar': 'الموسيقى أو اللوحة',
        'ar_dz': 'الموسيقى ولا الطابليت',
      },
    ),
    ScheduleActivity(
      id: 'elem_tidy_room',
      title: 'Zimmer aufräumen',
      category: ScheduleActivityCategory.routine,
      durationMinutes: 15,
      imageUri: '',
      labelsByLocale: {
        'de': 'Zimmer aufräumen',
        'en': 'Tidy room',
        'ar': 'ترتيب الغرفة',
        'ar_dz': 'ترتيب البيت',
      },
    ),
    ScheduleActivity(
      id: 'elem_walk',
      title: 'Spaziergang machen',
      category: ScheduleActivityCategory.leisure,
      durationMinutes: 30,
      imageUri: '',
      labelsByLocale: {
        'de': 'Spaziergang machen',
        'en': 'Take a walk',
        'ar': 'نزهة في الخارج',
        'ar_dz': 'تحويسة برا',
      },
    ),
    ScheduleActivity(
      id: 'elem_dinner',
      title: 'Abendessen',
      category: ScheduleActivityCategory.meal,
      durationMinutes: 30,
      imageUri: '',
      labelsByLocale: {
        'de': 'Abendessen',
        'en': 'Eat dinner',
        'ar': 'تناول العشاء',
        'ar_dz': 'العشا',
      },
    ),
    ScheduleActivity(
      id: 'elem_bath',
      title: 'Baden / Duschen',
      category: ScheduleActivityCategory.hygiene,
      durationMinutes: 20,
      imageUri: '',
      labelsByLocale: {
        'de': 'Baden / Duschen',
        'en': 'Bath / shower',
        'ar': 'الاستحمام',
        'ar_dz': 'الدوش',
      },
    ),
    ScheduleActivity(
      id: 'elem_pyjamas',
      title: 'Schlafanzug anziehen',
      category: ScheduleActivityCategory.bedtime,
      durationMinutes: 10,
      imageUri: '',
      labelsByLocale: {
        'de': 'Schlafanzug anziehen',
        'en': 'Put on pyjamas',
        'ar': 'ارتداء ملابس النوم',
        'ar_dz': 'لبس بيجاما النعاس',
      },
    ),
    ScheduleActivity(
      id: 'elem_story',
      title: 'Gute-Nacht-Geschichte',
      category: ScheduleActivityCategory.bedtime,
      durationMinutes: 15,
      imageUri: '',
      labelsByLocale: {
        'de': 'Gute-Nacht-Geschichte',
        'en': 'Bedtime story',
        'ar': 'قصة قبل النوم',
        'ar_dz': 'حكاية قبل النعاس',
      },
    ),
    ScheduleActivity(
      id: 'elem_sleep',
      title: 'Schlafen gehen',
      category: ScheduleActivityCategory.bedtime,
      durationMinutes: 480,
      imageUri: '',
      labelsByLocale: {
        'de': 'Schlafen gehen',
        'en': 'Go to sleep',
        'ar': 'النوم والراحة',
        'ar_dz': 'الرقاد',
      },
    ),
  ];

  static IconData _iconForCategory(String cat) {
    switch (cat) {
      case ScheduleActivityCategory.routine:
        return Icons.wb_sunny_rounded;
      case ScheduleActivityCategory.hygiene:
        return Icons.clean_hands_rounded;
      case ScheduleActivityCategory.meal:
        return Icons.restaurant_rounded;
      case ScheduleActivityCategory.school:
        return Icons.school_rounded;
      case ScheduleActivityCategory.leisure:
        return Icons.nature_people_rounded;
      case ScheduleActivityCategory.bedtime:
        return Icons.bedtime_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final langCode = LocaleRegistry.codeForLocale(locale);
    final isRtl = LocaleRegistry.isRtl(locale);
    final scheduleAsync = ref.watch(dailyScheduleProvider);
    final activeIds = scheduleAsync.valueOrNull?.activities.map((a) => a.id).toSet() ?? {};

    // Filter elements based on search and category
    final filtered = _bundledElements.where((elem) {
      final label = elem.labelFor(langCode).toLowerCase();
      if (_searchQuery.isNotEmpty && !label.contains(_searchQuery)) {
        return false;
      }
      if (_selectedCategory == 'all') return true;
      if (_selectedCategory == 'routine' && elem.category == ScheduleActivityCategory.routine) return true;
      if (_selectedCategory == 'leisure' && elem.category == ScheduleActivityCategory.leisure) return true;
      if (_selectedCategory == 'school' && elem.category == ScheduleActivityCategory.school) return true;
      if (_selectedCategory == 'meal' && elem.category == ScheduleActivityCategory.meal) return true;
      if (_selectedCategory == 'hygiene' && elem.category == ScheduleActivityCategory.hygiene) return true;
      if (_selectedCategory == 'bedtime' && elem.category == ScheduleActivityCategory.bedtime) return true;
      return false;
    }).toList();

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: LhColors.cream,
        appBar: AppBar(
          backgroundColor: LhColors.surface,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const NuriTalkBrandLogo(height: 26, fontSize: 17),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header (Title + Subtitle)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              color: LhColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Elemente verwalten',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: LhColors.nuriNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Verfügbare Aktivitäten und Routinenschritte anpassen.',
                    style: TextStyle(
                      fontSize: 13,
                      color: LhColors.ink2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Segmented Tabs (Routinen / Kategorien / Uploads)
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEFF5),
                      borderRadius: BorderRadius.circular(20),
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
                      tabs: const [
                        Tab(text: 'Routinen'),
                        Tab(text: 'Kategorien'),
                        Tab(text: 'Uploads'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: LhColors.line2),

            // Search Bar + Category Pills Bar
            Container(
              color: LhColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  // Search TextField
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Elemente durchsuchen...',
                        hintStyle: TextStyle(fontSize: 14, color: LhColors.ink3),
                        prefixIcon: Icon(Icons.search, size: 20, color: LhColors.ink2),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'Alle (${_bundledElements.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('routine', 'Routine'),
                        const SizedBox(width: 8),
                        _buildFilterChip('leisure', 'Freizeit / Draußen'),
                        const SizedBox(width: 8),
                        _buildFilterChip('school', 'Schule'),
                        const SizedBox(width: 8),
                        _buildFilterChip('meal', 'Essen'),
                        const SizedBox(width: 8),
                        _buildFilterChip('hygiene', 'Körper / Hygiene'),
                        const SizedBox(width: 8),
                        _buildFilterChip('bedtime', 'Abend / Bett'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: LhColors.line2),

            // Elements List
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Routinen
                  ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isEnabled = activeIds.contains(item.id);
                      final label = item.labelFor(langCode);

                      return Semantics(
                        label: '$label, ${ScheduleActivityCategory.nameFor(item.category, langCode)}, ${item.durationMinutes} Min',
                        toggled: isEnabled,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: LhColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: LhColors.line2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Drag handle
                              const Icon(Icons.drag_indicator, color: LhColors.ink3, size: 22),
                              const SizedBox(width: 8),
                              // Category Icon Avatar
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: ScheduleActivityCategory.colorFor(item.category),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: item.imageUri.isNotEmpty
                                      ? CompositeSymbolProvider.defaultInstance.buildSymbol(
                                          context,
                                          uri: item.imageUri,
                                          label: label,
                                          height: 28,
                                        )
                                      : Icon(
                                          _iconForCategory(item.category),
                                          color: LhColors.nuriNavy,
                                          size: 22,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Title & Duration
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: LhColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          ScheduleActivityCategory.nameFor(item.category, langCode),
                                          style: const TextStyle(fontSize: 12, color: LhColors.ink2),
                                        ),
                                        const Text(' · ', style: TextStyle(color: LhColors.ink3)),
                                        Text(
                                          '${item.durationMinutes} Min',
                                          style: const TextStyle(fontSize: 12, color: LhColors.ink2),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Toggle Switch
                              Semantics(
                                label: 'Enable $label in schedule',
                                child: Switch(
                                  value: isEnabled,
                                  activeTrackColor: LhColors.nuriTeal,
                                  activeThumbColor: LhColors.nuriNavy,
                                  onChanged: (val) async {
                                    if (val) {
                                      await ref.read(dailyScheduleProvider.notifier).saveActivity(item);
                                    } else {
                                      await ref.read(dailyScheduleProvider.notifier).deleteActivity(item.id);
                                    }
                                  },
                                ),
                              ),
                              // Edit button (min 48x48 touch target)
                              IconButton(
                                iconSize: 20,
                                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                tooltip: 'Edit $label',
                                icon: const Icon(Icons.edit_outlined, size: 20, color: LhColors.ink2),
                                onPressed: () async {
                                  final edited = await ActivityEditorDialog.show(context, activity: item);
                                  if (edited != null) {
                                    await ref.read(dailyScheduleProvider.notifier).saveActivity(edited);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Tab 1: Kategorien
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildCategoryRow('Morgen & Routine', Icons.wb_sunny_rounded, const Color(0xFFFFF9E6)),
                      _buildCategoryRow('Freizeit & Draußen', Icons.nature_people_rounded, const Color(0xFFE1F5FE)),
                      _buildCategoryRow('Schule & Lernen', Icons.school_rounded, const Color(0xFFEDE7F6)),
                      _buildCategoryRow('Essen & Trinken', Icons.restaurant_rounded, const Color(0xFFFBE9E7)),
                      _buildCategoryRow('Körper / Hygiene', Icons.clean_hands_rounded, const Color(0xFFE0F2F1)),
                      _buildCategoryRow('Abend & Schlafen', Icons.bedtime_rounded, const Color(0xFFE8EAF6)),
                    ],
                  ),
                  // Tab 2: Uploads
                  SingleChildScrollView(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_upload_outlined, size: 64, color: LhColors.nuriBlue),
                            const SizedBox(height: 16),
                            const Text(
                              'Eigene Bilder & Symbole',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LhColors.nuriNavy),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Laden Sie eigene Fotos vom Smartphone hoch, um persönliche Routinenschritte zu erstellen.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: LhColors.ink2),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add_photo_alternate_outlined),
                              label: const Text('Foto auswählen'),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Foto-Upload bereit für persönliche Karten.')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Sticky Button "+ Neu hinzufügen"
            Container(
              padding: const EdgeInsets.all(16),
              color: LhColors.surface,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: LhColors.nuriBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 22),
                    label: const Text(
                      'Neu hinzufügen',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final created = await ActivityEditorDialog.show(context);
                      if (created != null) {
                        await ref.read(dailyScheduleProvider.notifier).saveActivity(created);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedCategory == key;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _selectedCategory = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? LhColors.nuriNavy : const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : LhColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow(String name, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: LhColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LhColors.line2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: LhColors.nuriNavy, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LhColors.ink),
            ),
          ),
          const Icon(Icons.chevron_right, color: LhColors.ink3),
        ],
      ),
    );
  }
}
