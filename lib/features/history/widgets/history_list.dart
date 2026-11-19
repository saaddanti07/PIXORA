import 'package:flutter/material.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/core/widgets/pixora_card.dart';
import 'package:pixora/features/history/models/history_entry.dart';

/// Renders processed photos. Phase 01 keeps this dormant (the ledger is empty),
/// but the presentation is ready for the first real results in Phase 02.
class HistoryList extends StatelessWidget {
  const HistoryList({required this.entries, super.key});

  final List<HistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final PixoraPalette palette = PixoraPalette.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        for (final HistoryEntry entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PixoraCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: palette.iconSurface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.image_outlined,
                        size: 20, color: palette.secondaryText),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.processedAt.toLocal().toString(),
                          style: textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
