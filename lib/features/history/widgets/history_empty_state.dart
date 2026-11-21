import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/core/widgets/empty_state.dart';
import 'package:pixora/core/widgets/pixora_card.dart';

/// The History empty state: explains what will appear here and offers the next
/// step, plus a privacy reassurance.
class HistoryEmptyState extends StatelessWidget {
  const HistoryEmptyState({required this.onAction, super.key});

  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PixoraPalette palette = PixoraPalette.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return PixoraCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: <Widget>[
          EmptyState(
            icon: Icons.photo_library_outlined,
            title: l10n.historyEmptyTitle,
            message: l10n.historyEmptyDescription,
            actionLabel: l10n.historyEmptyAction,
            onAction: onAction,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.shield_outlined, size: 14, color: palette.secondaryText),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  l10n.historyPrivacyNote,
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
