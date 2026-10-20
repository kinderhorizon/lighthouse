/// Multi-child / multi-user profile management screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/user_profile.dart';
import '../../state/profile_provider.dart';
import '../../state/settings_provider.dart';
import '../theme/lighthouse_theme.dart';
import '../widgets/lh_widgets.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    final profilesAsync = ref.watch(profileListProvider);
    final activeProfileAsync = ref.watch(activeProfileProvider);

    return Scaffold(
      appBar: lhAppBar(context,
          title: l10n?.userProfilesTitle ?? 'User Profiles'),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error loading profiles: $err')),
        data: (profiles) {
          final active = activeProfileAsync.valueOrNull;
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l10n?.userProfilesDescription ??
                        'Manage independent user profiles for communicators, students, or family members. Each profile retains isolated speech settings, access preferences, and vocabulary.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: LhColors.ink2,
                      height: 1.4,
                    ),
                  ),
                ),
                for (final profile in profiles) ...[
                  _ProfileCard(
                    profile: profile,
                    isActive: active?.id == profile.id,
                    onSelect: () async {
                      await ref
                          .read(activeProfileProvider.notifier)
                          .switchProfile(profile.id);
                      if (profile.interfaceLocale != null) {
                        await ref
                            .read(settingsNotifierProvider.notifier)
                            .setLocaleOverride(profile.interfaceLocale);
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n?.switchedToProfile(profile.name) ??
                                'Switched to profile: ${profile.name}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    onEdit: () => _showEditDialog(context, ref, profile),
                    onDelete: profiles.length > 1
                        ? () => _confirmDelete(context, ref, profile)
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _showCreateDialog(context, ref),
                  icon: const Icon(Icons.person_add_rounded),
                  label: Text(l10n?.addNewProfile ?? 'Add New Profile'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n?.createProfileTitle ?? 'Create Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n?.profileNameLabel ?? 'Profile Name',
                hintText: l10n?.profileNameHint ?? 'e.g., Maya, Karim, Leo',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await ref
                    .read(activeProfileProvider.notifier)
                    .createProfile(name: name);
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              }
            },
            child: Text(l10n?.createAction ?? 'Create'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, UserProfile profile) {
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    final nameCtrl = TextEditingController(text: profile.name);
    double rate = profile.voiceRate;
    double pitch = profile.voicePitch;
    bool highContrast = profile.highContrast;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n?.editProfileTitle(profile.name) ??
              'Edit Profile: ${profile.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n?.profileNameLabel ?? 'Profile Name',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('${l10n?.speechSpeed ?? 'Speech Speed'}: ${(rate * 100).toInt()}%'),
                Slider(
                  value: rate,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  onChanged: (v) => setState(() => rate = v),
                ),
                Text('${l10n?.speechPitch ?? 'Speech Pitch'}: ${(pitch * 100).toInt()}%'),
                Slider(
                  value: pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  onChanged: (v) => setState(() => pitch = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n?.highContrastBoard ?? 'High-Contrast Board'),
                  value: highContrast,
                  onChanged: (v) => setState(() => highContrast = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final updated = profile.copyWith(
                  name: name.isNotEmpty ? name : profile.name,
                  voiceRate: rate,
                  voicePitch: pitch,
                  highContrast: highContrast,
                );
                await ref
                    .read(activeProfileProvider.notifier)
                    .updateActiveProfile(updated);
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              },
              child: Text(l10n?.saveAction ?? 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, UserProfile profile) {
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n?.deleteProfileTitle(profile.name) ??
            'Delete Profile "${profile.name}"?'),
        content: Text(l10n?.deleteProfileConfirm ??
            'This will permanently delete this profile and its custom settings. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref
                  .read(activeProfileProvider.notifier)
                  .deleteProfile(profile.id);
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            },
            child: Text(l10n?.deleteAction ?? 'Delete'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onSelect,
    required this.onEdit,
    this.onDelete,
  });

  final UserProfile profile;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    return Card(
      elevation: isActive ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? LhColors.brown : LhColors.line,
          width: isActive ? 2 : 1,
        ),
      ),
      color: isActive ? LhColors.cream : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  isActive ? LhColors.brown : LhColors.cream2,
              child: Text(
                profile.name.isNotEmpty
                    ? profile.name.substring(0, 1).toUpperCase()
                    : 'U',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : LhColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: LhColors.ink,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: LhColors.brown,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            l10n?.activeBadge ?? 'ACTIVE',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n?.accessMethod ?? 'Access'}: ${profile.accessMethod.name} • ${l10n?.speechSpeed ?? 'Speed'}: ${(profile.voiceRate * 100).toInt()}%'
                    '${profile.highContrast ? ' • ${l10n?.highContrastBoard ?? 'High-Contrast'}' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: LhColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: l10n?.editProfile ?? 'Edit Profile',
              onPressed: onEdit,
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: Colors.redAccent),
                tooltip: l10n?.deleteProfile ?? 'Delete Profile',
                onPressed: onDelete,
              ),
            if (!isActive)
              IconButton(
                icon: const Icon(Icons.check_circle_outline,
                    color: LhColors.brown),
                tooltip: l10n?.activateProfile ?? 'Activate Profile',
                onPressed: onSelect,
              ),
          ],
        ),
      ),
    );
  }
}
