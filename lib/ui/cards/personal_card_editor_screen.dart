/// Visual Personal AAC Card Editor and Manager.
///
/// Features:
/// - Live WYSIWYG card preview matching physical AAC photo cards
/// - Photo selection from Camera, Gallery, and Symbol Library
/// - Spoken text with live TTS test button
/// - Category picker with Fitzgerald Key color coding
/// - Multi-board assignment (My Family, My Friends, My Things, etc.)
/// - Multilingual localization accordion (Arabic, Darija, German, English)
/// - Favorite toggle and deletion confirmation
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../logic/fitzgerald_palette.dart';
import '../../models/models.dart';
import '../../services/symbols/symbols.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';

class PersonalCardEditorScreen extends ConsumerStatefulWidget {
  const PersonalCardEditorScreen({
    this.existingCard,
    this.initialBoardId,
    this.initialLabel,
    this.initialSpeech,
    super.key,
  });

  final PersonalCard? existingCard;
  final String? initialBoardId;
  final String? initialLabel;
  final String? initialSpeech;

  @override
  ConsumerState<PersonalCardEditorScreen> createState() =>
      _PersonalCardEditorScreenState();
}

class _PersonalCardEditorScreenState
    extends ConsumerState<PersonalCardEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _speechController;

  // Localized label controllers
  final _labelArController = TextEditingController();
  final _labelArDzController = TextEditingController();
  final _labelDeController = TextEditingController();
  final _labelEnController = TextEditingController();

  // Localized speech controllers
  final _speechArController = TextEditingController();
  final _speechArDzController = TextEditingController();
  final _speechDeController = TextEditingController();
  final _speechEnController = TextEditingController();

  String _category = PersonalCardCategory.family;
  String _imageUri = '';
  List<String> _selectedBoards = [];
  bool _isFavorite = false;
  bool _isSaving = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final card = widget.existingCard;

    _nameController = TextEditingController(
      text: card?.name ?? widget.initialLabel ?? '',
    );
    _speechController = TextEditingController(
      text: card?.speechText ?? widget.initialSpeech ?? '',
    );

    if (card != null) {
      _category = card.category;
      _imageUri = card.imageUri;
      _selectedBoards = List.from(card.boardIds);
      _isFavorite = card.isFavorite;

      _labelArController.text = card.labelsByLocale['ar'] ?? '';
      _labelArDzController.text = card.labelsByLocale['ar_dz'] ?? card.labelsByLocale['ar-DZ'] ?? '';
      _labelDeController.text = card.labelsByLocale['de'] ?? '';
      _labelEnController.text = card.labelsByLocale['en'] ?? '';

      _speechArController.text = card.speechByLocale['ar'] ?? '';
      _speechArDzController.text = card.speechByLocale['ar_dz'] ?? card.speechByLocale['ar-DZ'] ?? '';
      _speechDeController.text = card.speechByLocale['de'] ?? '';
      _speechEnController.text = card.speechByLocale['en'] ?? '';
    } else {
      if (widget.initialBoardId != null) {
        _selectedBoards = [widget.initialBoardId!];
        if (widget.initialBoardId == PersonalBoardId.myFamily) {
          _category = PersonalCardCategory.family;
        } else if (widget.initialBoardId == PersonalBoardId.myFriends) {
          _category = PersonalCardCategory.friends;
        } else if (widget.initialBoardId == PersonalBoardId.myThings) {
          _category = PersonalCardCategory.things;
        } else if (widget.initialBoardId == PersonalBoardId.myFavoriteFood) {
          _category = PersonalCardCategory.food;
        } else if (widget.initialBoardId == PersonalBoardId.myPlaces) {
          _category = PersonalCardCategory.places;
        } else if (widget.initialBoardId == PersonalBoardId.myActivities) {
          _category = PersonalCardCategory.activities;
        }
      } else {
        _selectedBoards = [PersonalBoardId.myFamily];
      }
    }

    _nameController.addListener(() => setState(() {}));
    _speechController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speechController.dispose();
    _labelArController.dispose();
    _labelArDzController.dispose();
    _labelDeController.dispose();
    _labelEnController.dispose();
    _speechArController.dispose();
    _speechArDzController.dispose();
    _speechDeController.dispose();
    _speechEnController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final activeProfile = ref.read(activeProfileProvider).valueOrNull;
      final profileId = activeProfile?.id ?? 'default';
      final store = ref.read(personalCardStoreProvider);

      final cardId = widget.existingCard?.id ??
          'card_${DateTime.now().millisecondsSinceEpoch}';

      final uri = await store.saveCardImage(
        profileId: profileId,
        cardId: cardId,
        bytes: bytes,
        mimeType: picked.mimeType ?? 'image/jpeg',
      );

      setState(() {
        _imageUri = uri;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load photo: $e')),
        );
      }
    }
  }

  Future<void> _pickSymbol() async {
    final symbols = [
      ('person', 'assets/symbols/people/mother.png', 'Mother'),
      ('person', 'assets/symbols/people/father.png', 'Father'),
      ('person', 'assets/symbols/people/sister.png', 'Sister'),
      ('person', 'assets/symbols/people/brother.png', 'Brother'),
      ('place', 'assets/symbols/places/house.png', 'House'),
      ('place', 'assets/symbols/places/school.png', 'School'),
      ('food', 'assets/symbols/food/water.png', 'Water'),
      ('food', 'assets/symbols/food/food.png', 'Food'),
      ('activity', 'assets/symbols/activities/play.png', 'Play'),
      ('heart', 'assets/symbols/feelings/happy.png', 'Happy'),
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
                        label: s.$3,
                      ),
                    ),
                    Text(s.$3, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    if (chosen != null) {
      setState(() => _imageUri = chosen);
    }
  }

  Future<void> _testSpeech() async {
    final text = _speechController.text.trim().isNotEmpty
        ? _speechController.text.trim()
        : _nameController.text.trim();
    if (text.isEmpty) return;

    final tts = ref.read(ttsEngineProvider);
    final locale = Localizations.localeOf(context);
    await tts.speak(text, locale: locale);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a card name')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final activeProfile = ref.read(activeProfileProvider).valueOrNull;
      final profileId = activeProfile?.id ?? 'default';
      final now = DateTime.now();

      final labels = <String, String>{};
      if (_labelArController.text.trim().isNotEmpty) {
        labels['ar'] = _labelArController.text.trim();
      }
      if (_labelArDzController.text.trim().isNotEmpty) {
        labels['ar_dz'] = _labelArDzController.text.trim();
      }
      if (_labelDeController.text.trim().isNotEmpty) {
        labels['de'] = _labelDeController.text.trim();
      }
      if (_labelEnController.text.trim().isNotEmpty) {
        labels['en'] = _labelEnController.text.trim();
      }

      final speech = <String, String>{};
      if (_speechArController.text.trim().isNotEmpty) {
        speech['ar'] = _speechArController.text.trim();
      }
      if (_speechArDzController.text.trim().isNotEmpty) {
        speech['ar_dz'] = _speechArDzController.text.trim();
      }
      if (_speechDeController.text.trim().isNotEmpty) {
        speech['de'] = _speechDeController.text.trim();
      }
      if (_speechEnController.text.trim().isNotEmpty) {
        speech['en'] = _speechEnController.text.trim();
      }

      final card = PersonalCard(
        id: widget.existingCard?.id ??
            'card_${DateTime.now().millisecondsSinceEpoch}',
        profileId: profileId,
        name: name,
        speechText: _speechController.text.trim().isNotEmpty
            ? _speechController.text.trim()
            : name,
        category: _category,
        imageUri: _imageUri,
        labelsByLocale: labels,
        speechByLocale: speech,
        boardIds: _selectedBoards.isEmpty
            ? [PersonalBoardId.myFamily]
            : _selectedBoards,
        isFavorite: _isFavorite,
        sortOrder: widget.existingCard?.sortOrder ?? 0,
        createdAt: widget.existingCard?.createdAt ?? now,
        updatedAt: now,
      );

      await ref.read(personalCardsProvider.notifier).saveCard(card);

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving card: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Personal Card?'),
        content: Text(
          'Are you sure you want to delete "${widget.existingCard!.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.existingCard != null) {
      await ref
          .read(personalCardsProvider.notifier)
          .deleteCard(widget.existingCard!.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCard != null;

    return Scaffold(
      backgroundColor: LhColors.cream,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Personal Card' : 'New Personal Card'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Card',
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: LhColors.brown),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save Card'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Live WYSIWYG Card Preview matching user's photo card specification
              _buildLivePreviewCard(),

              const SizedBox(height: 20),

              // 2. Photo Selection Affordance
              _buildPhotoPickerRow(),

              const SizedBox(height: 16),

              // 3. Card Name and Spoken Utterance
              _buildTextInputs(),

              const SizedBox(height: 16),

              // 4. Category Selector (Fitzgerald Key)
              _buildCategorySelector(),

              const SizedBox(height: 16),

              // 5. Board Assignment Selector
              _buildBoardSelector(),

              const SizedBox(height: 16),

              // 6. Favorite Toggle
              SwitchListTile(
                value: _isFavorite,
                title: const Text('Show in Home Favorites'),
                subtitle: const Text('Pins this card to the top communication strip'),
                secondary: Icon(
                  _isFavorite ? Icons.star : Icons.star_border,
                  color: LhColors.amberDeep,
                ),
                activeThumbColor: LhColors.amberDeep,
                onChanged: (val) => setState(() => _isFavorite = val),
              ),

              const SizedBox(height: 16),

              // 7. Multilingual Translations Accordion
              _buildTranslationsAccordion(),
            ],
          ),
        ),
      ),
    );
  }

  /// Live Card Preview rendered identically to real board tiles
  Widget _buildLivePreviewCard() {
    final label = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim().toUpperCase()
        : 'CARD LABEL';

    final categoryColor = switch (_category) {
      PersonalCardCategory.family ||
      PersonalCardCategory.friends ||
      PersonalCardCategory.caregivers =>
        const Color(0xFFFFFFA6),
      PersonalCardCategory.things ||
      PersonalCardCategory.food ||
      PersonalCardCategory.places =>
        const Color(0xFFFFD9A6),
      PersonalCardCategory.activities || PersonalCardCategory.actions =>
        const Color(0xFFC2FFC2),
      PersonalCardCategory.feelings => const Color(0xFFA6D9FF),
      _ => const Color(0xFFFFF2DF),
    };

    final edge = categoryEdgeColor(categoryColor);

    return Center(
      child: Container(
        width: 170,
        height: 210,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: edge, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Upper ~72% for large real photo
            Expanded(
              flex: 72,
              child: Container(
                color: const Color(0xFFF8F8F8),
                child: _imageUri.isNotEmpty
                    ? CompositeSymbolProvider.defaultInstance.buildSymbol(
                        context,
                        uri: _imageUri,
                        label: label,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : const Center(
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          size: 48,
                          color: LhColors.ink3,
                        ),
                      ),
              ),
            ),
            const Divider(height: 1, thickness: 1.5, color: Color(0xFFEADFCE)),
            // Bottom ~28% for bold high-contrast label band
            Expanded(
              flex: 28,
              child: Container(
                color: categoryColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: LhColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPickerRow() {
    return Card(
      color: LhColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.emoji_symbols),
              label: const Text('Symbol'),
              onPressed: _pickSymbol,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInputs() {
    return Card(
      color: LhColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Card Display Name *',
                hintText: 'e.g. Mama, Grandfather, Red Cup',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _speechController,
              decoration: InputDecoration(
                labelText: 'Spoken TTS Text (Optional)',
                hintText: 'Leave empty to speak Display Name',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.record_voice_over_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.volume_up, color: LhColors.brown),
                  tooltip: 'Test Speech / Pronunciation',
                  onPressed: _testSpeech,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = [
      (PersonalCardCategory.family, 'Family', const Color(0xFFFFFFA6)),
      (PersonalCardCategory.friends, 'Friends', const Color(0xFFFFFFA6)),
      (PersonalCardCategory.caregivers, 'Caregivers', const Color(0xFFFFFFA6)),
      (PersonalCardCategory.things, 'Objects', const Color(0xFFFFD9A6)),
      (PersonalCardCategory.food, 'Food & Drinks', const Color(0xFFFFD9A6)),
      (PersonalCardCategory.activities, 'Activities', const Color(0xFFC2FFC2)),
      (PersonalCardCategory.places, 'Places', const Color(0xFFFFD9A6)),
      (PersonalCardCategory.feelings, 'Feelings', const Color(0xFFA6D9FF)),
      (PersonalCardCategory.actions, 'Actions', const Color(0xFFC2FFC2)),
      (PersonalCardCategory.custom, 'Custom', const Color(0xFFFFF2DF)),
    ];

    return Card(
      color: LhColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category (Color Coding):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final isSelected = _category == cat.$1;
                return ChoiceChip(
                  label: Text(cat.$2),
                  selected: isSelected,
                  selectedColor: cat.$3,
                  backgroundColor: cat.$3.withValues(alpha: 0.4),
                  side: BorderSide(
                    color: isSelected ? LhColors.brown : Colors.transparent,
                    width: isSelected ? 2 : 1,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _category = cat.$1);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardSelector() {
    final boards = [
      (PersonalBoardId.myFamily, 'My Family'),
      (PersonalBoardId.myFriends, 'My Friends'),
      (PersonalBoardId.myThings, 'My Things'),
      (PersonalBoardId.myFavoriteFood, 'My Favorite Food'),
      (PersonalBoardId.myPlaces, 'My Places'),
      (PersonalBoardId.myActivities, 'My Activities'),
    ];

    return Card(
      color: LhColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assign to Personal Boards:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: boards.map((b) {
                final isSelected = _selectedBoards.contains(b.$1);
                return FilterChip(
                  label: Text(b.$2),
                  selected: isSelected,
                  selectedColor: LhColors.amberTint,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedBoards.add(b.$1);
                      } else {
                        _selectedBoards.remove(b.$1);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationsAccordion() {
    return Card(
      color: LhColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: const Text('Multilingual Translations (Optional)'),
        subtitle: const Text('Custom labels and pronunciation for Arabic, Darija, and German'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildLocaleSection(
                  'Arabic (العربية)',
                  _labelArController,
                  _speechArController,
                  isRtl: true,
                ),
                const Divider(),
                _buildLocaleSection(
                  'Algerian Darija (الدارجة)',
                  _labelArDzController,
                  _speechArDzController,
                  isRtl: true,
                ),
                const Divider(),
                _buildLocaleSection(
                  'German (Deutsch)',
                  _labelDeController,
                  _speechDeController,
                ),
                const Divider(),
                _buildLocaleSection(
                  'English',
                  _labelEnController,
                  _speechEnController,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocaleSection(
    String languageTitle,
    TextEditingController labelCtrl,
    TextEditingController speechCtrl, {
    bool isRtl = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(languageTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: labelCtrl,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: speechCtrl,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'Spoken Text',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
