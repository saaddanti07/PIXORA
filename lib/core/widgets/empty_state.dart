import 'package:flutter/material.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';

/// A polished, reusable empty state.
///
/// Empty is a normal state in PIXORA (no processed photos yet), so it is
/// designed rather than left blank — it explains the feature and offers the
/// next step.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final PixoraPalette palette = PixoraPalette.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double badgeSize = compact ? 56 : 72;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: badgeSize,
          height: badgeSize,
          decoration: BoxDecoration(
            gradient: palette.brandLinearGradient,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.brandGradient.last.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: compact ? 26 : 32),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
        Text(
          title,
          style: textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        if (actionLabel != null && onAction != null) ...<Widget>[
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          FilledButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}
