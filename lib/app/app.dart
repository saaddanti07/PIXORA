import 'package:flutter/material.dart';
import 'package:pixora/app/bootstrap.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/navigation/root_shell.dart';
import 'package:pixora/app/state/settings_scope.dart';
import 'package:pixora/app/theme/app_theme.dart';
import 'package:pixora/core/constants/app_constants.dart';
import 'package:pixora/features/settings/models/app_settings.dart';

/// The PIXORA application widget.
///
/// Theme mode and locale come from [PixoraBootstrap.settingsController], so a
/// change in Settings is reflected instantly — including right-to-left layout
/// when Arabic is selected — without restarting the app.
class PixoraApp extends StatelessWidget {
  const PixoraApp({required this.bootstrap, super.key});

  final PixoraBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      controller: bootstrap.settingsController,
      child: ListenableBuilder(
        listenable: bootstrap.settingsController,
        builder: (BuildContext context, Widget? child) {
          final AppSettings settings = bootstrap.settingsController.settings;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppConstants.appName,
            onGenerateTitle: (BuildContext context) => context.l10n.appName,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            locale: settings.language.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: RootShell(
              imagePickerService: bootstrap.imagePickerService,
              historyRepository: bootstrap.historyRepository,
            ),
          );
        },
      ),
    );
  }
}
