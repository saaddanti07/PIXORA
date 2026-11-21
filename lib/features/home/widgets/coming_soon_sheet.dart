import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/core/widgets/coming_soon_badge.dart';
import 'package:pixora/features/home/data/creative_tools.dart';

/// Explains, honestly, that a tool is not available yet.
class ComingSoonSheet extends StatelessWidget {
  const ComingSoonSheet({required this.tool, super.key});

  final CreativeTool tool;

  static Future<void> show(BuildContext context, CreativeTool tool) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => ComingSoonSheet(tool: tool),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PixoraPalette palette = PixoraPalette.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tool.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(tool.icon, size: 22, color: tool.accent),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(tool.title, style: textTheme.titleMedium),
                    ),
                    ComingSoonBadge(label: l10n.toolComingSoon),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.toolComingSoonTitle, style: textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(l10n.toolComingSoonBody(tool.title), style: textTheme.bodySmall),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(l10n.toolComingSoonClose),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
