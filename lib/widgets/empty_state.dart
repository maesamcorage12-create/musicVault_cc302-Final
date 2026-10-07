import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'glass_card.dart';

/// Illustrated empty state (spec §29).
///
/// Every dynamic page uses this instead of rendering a blank screen: no
/// playlists, no favourites, no history, no search results.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// Tighter spacing for empty states rendered inside a list.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final double pad = compact ? AppDimensions.xl : AppDimensions.huge;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.xl,
            vertical: compact ? AppDimensions.lg : pad,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _GlowOrb(icon: icon),
              SizedBox(height: compact ? AppDimensions.lg : AppDimensions.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact ? text.titleLarge : text.headlineSmall,
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: AppDimensions.xl),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(actionLabel!),
                ),
              ],
              if (secondaryActionLabel != null && onSecondaryAction != null) ...<Widget>[
                const SizedBox(height: AppDimensions.md),
                TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: VibeColors.primaryGradient,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: VibeColors.neonPink.withValues(alpha: 0.32),
            blurRadius: 44,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: VibeColors.electricBlue.withValues(alpha: 0.34),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VibeColors.deepBackground.withValues(alpha: 0.55),
          ),
          child: Icon(icon, size: 38, color: VibeColors.white),
        ),
      ),
    );
  }
}

/// Inline error state (spec §30). Used when a page-level operation fails and a
/// SnackBar would not be enough context.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.xl),
          child: GlassCard(
            intensity: GlassIntensity.strong,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 40, color: const Color(0xFFFF6B8A)),
                const SizedBox(height: AppDimensions.md),
                Text(title, style: text.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  message,
                  style: text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...<Widget>[
                  const SizedBox(height: AppDimensions.lg),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
