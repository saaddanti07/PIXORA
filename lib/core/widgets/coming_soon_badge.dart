import 'package:flutter/material.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';

/// Honest label for features that are designed but not implemented yet.
class ComingSoonBadge extends StatelessWidget {
  const ComingSoonBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final PixoraPalette palette = PixoraPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}
