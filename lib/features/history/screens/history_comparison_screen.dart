import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/features/history/models/history_entry.dart';
import 'package:pixora/features/processing/widgets/before_after_view.dart';

/// Reopens the saved original/result pair from the private history archive.
class HistoryComparisonScreen extends StatelessWidget {
  const HistoryComparisonScreen({
    required this.entry,
    this.imageBuilder,
    super.key,
  });

  final HistoryEntry entry;
  final Widget Function(BuildContext context, String path, BoxFit fit)? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? original = entry.originalPath;
    final int? width = entry.originalWidth;
    final int? height = entry.originalHeight;
    final double aspect = width != null && height != null && height > 0
        ? width / height
        : (entry.outputWidth != null && entry.outputHeight != null && entry.outputHeight! > 0
            ? entry.outputWidth! / entry.outputHeight!
            : 4 / 3);
    return Scaffold(
      appBar: AppBar(title: Text(entry.fileName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: <Widget>[
            if (original != null && File(original).existsSync())
              BeforeAfterView(
                beforePath: original,
                afterPath: entry.imagePath,
                aspectRatio: aspect,
                beforeLabel: l10n.processingOriginal,
                afterLabel: l10n.processingResult,
                imageBuilder: imageBuilder,
              )
            else
              imageBuilder?.call(context, entry.imagePath, BoxFit.contain) ??
                  Image.file(File(entry.imagePath), fit: BoxFit.contain),
            const SizedBox(height: AppSpacing.md),
            Text(entry.methodId == 'classical-enhancement'
                ? l10n.processingClassicalBadge
                : l10n.processingAiBadge),
            Text(l10n.processingDuration((entry.durationMs / 1000).toStringAsFixed(1))),
            Text(entry.processedAt.toLocal().toString()),
            if (width != null && height != null)
              Text('$width × $height → ${entry.outputWidth ?? '?'} × ${entry.outputHeight ?? '?'}'),
          ],
        ),
      ),
    );
  }
}
