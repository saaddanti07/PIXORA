import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';

/// Light / dark / system selector.
///
/// Uses plain tap targets instead of radio buttons: it reads better, works in
/// both text directions, and gives immediate visual feedback.
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<_ThemeOption> options = <_ThemeOption>[
      _ThemeOption(
        mode: ThemeMode.system,
        label: l10n.settingsThemeSystem,
        icon: Icons.brightness_auto_rounded,
      ),
      _ThemeOption(
        mode: ThemeMode.light,
        label: l10n.settingsThemeLight,
        icon: Icons.light_mode_rounded,
      ),
      _ThemeOption(
        mode: ThemeMode.dark,
        label: l10n.settingsThemeDark,
        icon: Icons.dark_mode_rounded,
      ),
    ];

    return Row(
      children: <Widget>[
        for (int index = 0; index < options.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ThemeOptionTile(
              option: options[index],
              selected: options[index].mode == value,
              onTap: () => onChanged(options[index].mode),
            ),
          ),
        ],
      ],
    );
  }
}

@immutable
class _ThemeOption {
  const _ThemeOption({
    required this.mode,
    required this.label,
    required this.icon,
  });

  final ThemeMode mode;
  final String label;
  final IconData icon;
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PixoraPalette palette = PixoraPalette.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.10)
                : palette.mutedSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? scheme.primary : palette.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                option.icon,
                size: 22,
                color: selected ? scheme.primary : palette.secondaryText,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: selected ? scheme.primary : palette.secondaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
