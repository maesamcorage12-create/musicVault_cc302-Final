import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';

import '../../models/playback_state.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../repositories/playback_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/vibe_actions.dart';

/// Settings (spec §26). Everything here is local to the device/account.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String appVersion = '1.0.0+1';

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final PlayerProvider player = context.watch<PlayerProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();
    final LibraryProvider library = context.watch<LibraryProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.xl,
        AppDimensions.lg,
        AppDimensions.xxl,
      ),
      children: <Widget>[
        const PageHeader(
          title: 'Settings',
          subtitle: 'Everything is stored locally on this device',
        ),

        // Account ---------------------------------------------------------
        const _GroupLabel('Account'),
        GlassCard(
          padding: const EdgeInsets.all(AppDimensions.md),
          borderRadius: AppDimensions.radiusTile,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                auth.user?.username ?? 'Listener',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                auth.user?.email ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rename(context, auth),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('RENAME'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => VibeActions.confirmLogout(context),
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text('LOG OUT'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF8FA6),
                        side: const BorderSide(color: Color(0x55FF6B8A)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.xl),

        // Appearance ------------------------------------------------------
        const _GroupLabel('Appearance'),
        GlassCard(
          padding: const EdgeInsets.all(AppDimensions.md),
          borderRadius: AppDimensions.radiusTile,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Background quality',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Lower settings reduce blur and particles if animations stutter.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: <Widget>[
                  for (final BackgroundQuality quality
                      in BackgroundQuality.values) ...<Widget>[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppDimensions.sm),
                        child: ChoiceChip(
                          label: Text(quality.label),
                          selected: settings.backgroundQuality == quality,
                          onSelected: (_) =>
                              settings.setBackgroundQuality(quality),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Divider(height: AppDimensions.xl),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.reduceMotion,
                onChanged: settings.setReduceMotion,
                title: Text(
                  'Reduce motion',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(
                  'Freezes the animated background on a static frame.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                activeThumbColor: VibeColors.neonPink,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.xl),

        // Audio -----------------------------------------------------------
        const _GroupLabel('Audio'),
        GlassCard(
          padding: const EdgeInsets.all(AppDimensions.md),
          borderRadius: AppDimensions.radiusTile,
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Volume',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    '${(player.volume * 100).round()}%',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: VibeColors.softPink),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () =>
                        player.setVolume((player.volume - 0.1).clamp(0, 1)),
                    tooltip: 'Volume down',
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Expanded(
                    child: Slider(
                      value: player.volume,
                      onChanged: player.setVolume,
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        player.setVolume((player.volume + 0.1).clamp(0, 1)),
                    tooltip: 'Volume up',
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const Divider(height: AppDimensions.xl),
              _SwitchRow(
                title: 'Shuffle',
                subtitle: 'Plays tracks in a random order.',
                value: player.shuffle,
                onChanged: (_) => player.toggleShuffle(),
              ),
              const SizedBox(height: AppDimensions.sm),
              _SwitchRow(
                title: 'Repeat ${player.repeatMode.shortLabel.toLowerCase()}',
                subtitle: 'Cycles off → all → one.',
                value: player.repeatMode != RepeatMode.off,
                onChanged: (_) => player.cycleRepeatMode(),
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await player.stop();
                        if (context.mounted) {
                          VibeActions.showSnack(
                            context,
                            'Playback stopped.',
                          );
                        }
                      },
                      icon: const Icon(Icons.stop_rounded, size: 16),
                      label: const Text('STOP'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: player.hasQueue
                          ? () {
                              player.clearQueue();
                              VibeActions.showSnack(context, 'Queue cleared.');
                            }
                          : null,
                      icon: const Icon(Icons.playlist_remove_rounded, size: 16),
                      label: const Text('CLEAR QUEUE'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.xl),

        // Data ------------------------------------------------------------
        const _GroupLabel('Local data'),
        GlassCard(
          padding: const EdgeInsets.all(AppDimensions.md),
          borderRadius: AppDimensions.radiusTile,
          child: Column(
            children: <Widget>[
              _DataAction(
                icon: Icons.history_rounded,
                title: 'Clear history',
                subtitle: '${library.history.length} '
                    '${library.history.length == 1 ? 'entry' : 'entries'}',
                onTap: () async {
                  final bool confirmed = await VibeActions.confirmDialog(
                        context,
                        title: 'Clear listening history?',
                        message:
                            'Your statistics reset to zero. Favourites and '
                            'playlists are not affected.',
                        confirmLabel: 'Clear history',
                        isDestructive: true,
                      ) ??
                      false;
                  if (!confirmed || !context.mounted) {
                    return;
                  }
                  await library.clearHistory();
                  if (!context.mounted) {
                    return;
                  }
                  VibeActions.showSnack(context, 'History cleared.');
                },
              ),
              const Divider(height: AppDimensions.xl),
              _DataAction(
                icon: Icons.delete_sweep_outlined,
                title: 'Clear local data',
                subtitle: 'Playlists, favourites and history',
                onTap: () => VibeActions.confirmClearLocalData(context),
                destructive: true,
              ),
              const Divider(height: AppDimensions.xl),
              _DataAction(
                icon: Icons.restore_rounded,
                title: 'Reset preferences',
                subtitle: 'Appearance and audio defaults',
                onTap: () async {
                  await settings.resetToDefaults();
                  if (!context.mounted) {
                    return;
                  }
                  VibeActions.showSnack(context, 'Preferences reset.');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.xl),

        // About -----------------------------------------------------------
        const _GroupLabel('About'),
        GlassCard(
          padding: const EdgeInsets.all(AppDimensions.md),
          borderRadius: AppDimensions.radiusTile,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: VibeColors.primaryGradient,
                    ),
                    child: const Icon(
                      Icons.multitrack_audio_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'VibeVault',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Version $appVersion',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                'A student-scale music streaming and playlist management app '
                'built 100% with Flutter and Dart. All accounts, playlists, '
                'favourites and statistics live in local storage on this '
                'device — there is no server and no network access.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: VibeColors.mutedText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Passwords are stored as salted SHA-256 digests, never '
                      'as plain text. This is a school project scheme, not '
                      'production authentication.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (settings.errorMessage != null) ...<Widget>[
          const SizedBox(height: AppDimensions.lg),
          Text(
            settings.errorMessage!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: const Color(0xFFFF8FA6)),
          ),
        ],
      ],
    );
  }

  Future<void> _rename(BuildContext context, AuthProvider auth) async {
    final TextEditingController controller = TextEditingController(
      text: auth.user?.username ?? '',
    );
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Change username'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (name == null || name.isEmpty || !context.mounted) {
      return;
    }
    await auth.renameAccount(name);
    if (!context.mounted) {
      return;
    }
    if (auth.errorMessage != null) {
      VibeActions.showSnack(context, auth.errorMessage!, isError: true);
      auth.clearError();
    }
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md, left: AppDimensions.xs),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.8,
              color: VibeColors.softPink,
            ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      activeThumbColor: VibeColors.neonPink,
    );
  }
}

class _DataAction extends StatelessWidget {
  const _DataAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color color =
        destructive ? const Color(0xFFFF8FA6) : VibeColors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: VibeColors.mutedText),
          ],
        ),
      ),
    );
  }
}
