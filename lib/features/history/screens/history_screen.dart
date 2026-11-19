import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/core/widgets/screen_header.dart';
import 'package:pixora/features/history/data/history_repository.dart';
import 'package:pixora/features/history/models/history_entry.dart';
import 'package:pixora/features/history/widgets/history_empty_state.dart';
import 'package:pixora/features/history/widgets/history_list.dart';

/// History: processed photos, kept entirely on the device.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.repository,
    required this.onStartRestoration,
    super.key,
  });

  final HistoryRepository repository;

  /// Takes the user to the Home tab so they can pick a photo.
  final VoidCallback onStartRestoration;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final List<HistoryEntry> _entries = widget.repository.load();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            ScreenHeader(
              title: l10n.historyTitle,
              subtitle: l10n.historySubtitle,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_entries.isEmpty)
              HistoryEmptyState(onAction: widget.onStartRestoration)
            else
              HistoryList(entries: _entries),
          ],
        ),
      ),
    );
  }
}
