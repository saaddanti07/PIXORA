import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/core/widgets/pixora_card.dart';
import 'package:pixora/features/history/models/history_entry.dart';

class HistoryList extends StatelessWidget {
  const HistoryList({required this.entries, required this.onOpen, super.key});

  final List<HistoryEntry> entries;
  final ValueChanged<HistoryEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AppLocalizations l10n = context.l10n;
    return Column(
      children: <Widget>[
        for (final HistoryEntry entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PixoraCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => onOpen(entry),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.file(
                          File(entry.imagePath),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          cacheWidth: 128,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            width: 64, height: 64,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(entry.fileName, maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(entry.methodId == 'classical-enhancement'
                                ? l10n.processingClassicalBadge
                                : l10n.processingAiBadge,
                                style: textTheme.bodySmall),
                            Text(entry.processedAt.toLocal().toString(),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: textTheme.labelSmall),
                            if (entry.outputWidth != null && entry.outputHeight != null)
                              Text('${entry.outputWidth} × ${entry.outputHeight}',
                                  style: textTheme.labelSmall),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
