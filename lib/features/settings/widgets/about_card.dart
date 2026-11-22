import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/core/constants/app_constants.dart';
import 'package:pixora/core/widgets/pixora_card.dart';

/// Application identity and the free, ad-supported promise.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PixoraPalette palette = PixoraPalette.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return PixoraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(AppConstants.appName, style: textTheme.titleMedium),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  l10n.settingsFreeBadge,
                  style: textTheme.labelSmall?.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l10n.settingsVersion(
              '${AppConstants.appVersion} · build ${AppConstants.buildStamp}',
            ),
            style: textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.settingsAdSupported, style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Divider(color: palette.cardBorder, height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Icon(Icons.fingerprint_rounded,
                  size: 16, color: palette.secondaryText),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${l10n.settingsApplicationId}: ${AppConstants.applicationId}',
                  style: textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
                applicationLegalese: l10n.settingsLicensesNote,
              ),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(l10n.settingsLicenses),
            ),
          ),
        ],
      ),
    );
  }
}
