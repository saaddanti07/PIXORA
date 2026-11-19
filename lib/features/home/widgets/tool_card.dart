import 'package:flutter/material.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/core/widgets/coming_soon_badge.dart';
import 'package:pixora/core/widgets/pixora_card.dart';
import 'package:pixora/features/home/data/creative_tools.dart';

/// A creative tool entry point. Visually complete, but explicitly labelled as
/// not available yet.
class ToolCard extends StatelessWidget {
  const ToolCard({
    required this.tool,
    required this.comingSoonLabel,
    required this.onTap,
    super.key,
  });

  final CreativeTool tool;
  final String comingSoonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return PixoraCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tool.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(tool.icon, size: 21, color: tool.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tool.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            tool.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          ComingSoonBadge(label: comingSoonLabel),
        ],
      ),
    );
  }
}
