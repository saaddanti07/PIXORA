import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/localization/supported_language.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/core/widgets/pixora_card.dart';

/// English / العربية / Français selector. The chosen language is applied
/// instantly, without restarting the app.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final SupportedLanguage value;
  final ValueChanged<SupportedLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final PixoraPalette palette = PixoraPalette.of(context);
    return PixoraCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < SupportedLanguage.values.length; index++) ...<Widget>[
            if (index > 0)
              Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md,
                  color: palette.cardBorder),
            _LanguageTile(
              key: ValueKey<String>(
                'language_option_${SupportedLanguage.values[index].code}',
              ),
              language: SupportedLanguage.values[index],
              selected: SupportedLanguage.values[index] == value,
              onTap: () => onChanged(SupportedLanguage.values[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final SupportedLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PixoraPalette palette = PixoraPalette.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String localizedName;
    switch (language) {
      case SupportedLanguage.english:
        localizedName = l10n.languageEnglish;
      case SupportedLanguage.arabic:
        localizedName = l10n.languageArabic;
      case SupportedLanguage.french:
        localizedName = l10n.languageFrench;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: AppDurations.fast,
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.12)
                    : palette.mutedSurface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                language.code.toUpperCase(),
                style: textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.primary : palette.secondaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(language.nativeName, style: textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(localizedName, style: textTheme.labelSmall),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: scheme.primary, size: 22)
            else
              Icon(Icons.circle_outlined, color: palette.cardBorder, size: 22),
          ],
        ),
      ),
    );
  }
}
