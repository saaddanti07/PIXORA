import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/core/widgets/screen_header.dart';
import 'package:pixora/features/history/data/history_repository.dart';
import 'package:pixora/features/history/models/history_entry.dart';
import 'package:pixora/features/history/screens/history_comparison_screen.dart';
import 'package:pixora/features/history/widgets/history_empty_state.dart';
import 'package:pixora/features/history/widgets/history_list.dart';

/// History: processed photos, kept entirely on the device.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.repository,
    required this.onStartRestoration,
    this.thumbnailBuilder,
    super.key,
  });

  final HistoryRepository repository;

  /// Takes the user to the Home tab so they can pick a photo.
  final VoidCallback onStartRestoration;

  /// Allows an alternate thumbnail renderer in previews and widget tests.
  final Widget Function(BuildContext context, HistoryEntry entry)? thumbnailBuilder;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.repository,
        builder: (BuildContext context, Widget? child) {
          final AppLocalizations l10n = context.l10n;
          final List<HistoryEntry> entries = widget.repository.load();
          return SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                ScreenHeader(title: l10n.historyTitle, subtitle: l10n.historySubtitle),
                const SizedBox(height: AppSpacing.xl),
                if (entries.isEmpty)
                  HistoryEmptyState(onAction: widget.onStartRestoration)
                else
                  HistoryList(
                    entries: entries,
                    thumbnailBuilder: widget.thumbnailBuilder,
                    onOpen: (HistoryEntry entry) => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HistoryComparisonScreen(entry: entry),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}
