import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/state/settings_controller.dart';
import 'package:pixora/app/state/settings_scope.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/core/widgets/pixora_card.dart';
import 'package:pixora/core/widgets/screen_header.dart';
import 'package:pixora/features/settings/models/app_settings.dart';
import 'package:pixora/features/settings/widgets/about_card.dart';
import 'package:pixora/features/settings/widgets/language_selector.dart';
import 'package:pixora/features/settings/widgets/settings_section.dart';
import 'package:pixora/features/settings/widgets/theme_mode_selector.dart';

/// Settings: appearance, language, privacy and application information.
///
/// Every change is applied immediately and saved locally.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SettingsController controller = SettingsScope.of(context);
    final AppSettings settings = controller.settings;
    final PixoraPalette palette = PixoraPalette.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

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
              title: l10n.settingsTitle,
              subtitle: l10n.settingsSubtitle,
            ),
            const SizedBox(height: AppSpacing.xl),
            SettingsSection(
              title: l10n.settingsAppearanceTitle,
              subtitle: l10n.settingsAppearanceSubtitle,
              child: ThemeModeSelector(
                value: settings.themeMode,
                onChanged: controller.setThemeMode,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SettingsSection(
              title: l10n.settingsLanguageTitle,
              subtitle: l10n.settingsLanguageSubtitle,
              child: LanguageSelector(
                value: settings.language,
                onChanged: controller.setLanguage,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SettingsSection(
              title: l10n.settingsPrivacyTitle,
              child: PixoraCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.shield_moon_outlined,
                        size: 20, color: palette.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.settingsPrivacyBody,
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SettingsSection(
              title: l10n.settingsAboutTitle,
              subtitle: l10n.settingsAboutSubtitle,
              child: const AboutCard(),
            ),
          ],
        ),
      ),
    );
  }
}
