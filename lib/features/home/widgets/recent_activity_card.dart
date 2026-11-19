import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/core/widgets/empty_state.dart';
import 'package:pixora/core/widgets/pixora_card.dart';
import 'package:pixora/features/history/models/history_entry.dart';

/// Recent activity on the dashboard.
///
/// Driven by the real local history ledger, which is empty in Phase 01 — so a
/// designed empty state is shown rather than invented content.
class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({
    required this.entries,
    required this.onViewAll,
    super.key,
  });

  final List<HistoryEntry> entries;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PixoraPalette palette = PixoraPalette.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    if (entries.isEmpty) {
      return PixoraCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: EmptyState(
          icon: Icons.history_rounded,
          title: l10n.homeRecentEmptyTitle,
          message: l10n.homeRecentEmptyDescription,
          compact: true,
        ),
      );
    }

    return PixoraCard(
      child: Column(
        children: <Widget>[
          for (final HistoryEntry entry in entries.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: palette.iconSurface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.image_outlined,
                        size: 18, color: palette.secondaryText),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: onViewAll,
              child: Text(l10n.homeRecentAction),
            ),
          ),
        ],
      ),
    );
  }
}
