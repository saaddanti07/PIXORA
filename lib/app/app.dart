import 'package:flutter/material.dart';
import 'package:pixora/app/bootstrap.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/navigation/root_shell.dart';
import 'package:pixora/app/state/settings_controller.dart';
import 'package:pixora/app/state/settings_scope.dart';
import 'package:pixora/app/theme/app_theme.dart';
import 'package:pixora/core/constants/app_constants.dart';
import 'package:pixora/features/settings/models/app_settings.dart';

/// The PIXORA application widget.
///
/// This is the single place where a preference becomes visible UI: theme mode
/// and locale are read from [PixoraBootstrap.settingsController] on every build,
/// so changing either one in Settings rebuilds the whole [MaterialApp] — every
/// screen, dialog, card and the navigation bar — without restarting the app.
///
/// The listener wiring is explicit (`addListener`/`setState`/`removeListener`)
/// rather than hidden in an intermediate builder, so there is exactly one
/// rebuild path and it can be asserted in tests.
class PixoraApp extends StatefulWidget {
  const PixoraApp({required this.bootstrap, super.key});

  final PixoraBootstrap bootstrap;

  @override
  State<PixoraApp> createState() => _PixoraAppState();
}

class _PixoraAppState extends State<PixoraApp> {
  SettingsController get _settingsController =>
      widget.bootstrap.settingsController;

  @override
  void initState() {
    super.initState();
    _settingsController.addListener(_handleSettingsChanged);
  }

  @override
  void didUpdateWidget(covariant PixoraApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bootstrap.settingsController != _settingsController) {
      oldWidget.bootstrap.settingsController
          .removeListener(_handleSettingsChanged);
      _settingsController.addListener(_handleSettingsChanged);
    }
  }

  @override
  void dispose() {
    _settingsController.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  /// Rebuilds the entire application tree, which is what makes a new theme or
  /// language apply instantly and everywhere.
  void _handleSettingsChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = _settingsController.settings;
    final Locale locale = settings.language.locale;

    return SettingsScope(
      controller: _settingsController,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,

        // Lets Android restore the visible tab if the process is killed in the
        // background (see RootShell), instead of dropping the user back on Home.
        restorationScopeId: 'pixora',
        title: AppConstants.appName,
        onGenerateTitle: (BuildContext context) => context.l10n.appName,

        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: settings.themeMode,

        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,

        // The language the user picked always wins. Without this callback the
        // resolved locale comes from the platform's locale list, so a device
        // reporting a dialect (ar-DZ, fr-DZ) or an unrelated system language
        // could resolve to a different language than the one shown as selected.
        localeListResolutionCallback: (
          List<Locale>? deviceLocales,
          Iterable<Locale> supportedLocales,
        ) =>
            _resolveLocale(locale, supportedLocales),

        home: RootShell(
          imagePickerService: widget.bootstrap.imagePickerService,
          historyRepository: widget.bootstrap.historyRepository,
        ),
      ),
    );
  }

  /// Maps the selected language onto the matching supported [Locale].
  ///
  /// Falls back to the first supported locale (English) only if the generated
  /// localization set ever stops containing the selected language, which keeps
  /// `MaterialApp` from asserting on an unsupported locale.
  static Locale _resolveLocale(Locale preferred, Iterable<Locale> supported) {
    for (final Locale candidate in supported) {
      if (candidate.languageCode == preferred.languageCode) {
        return candidate;
      }
    }
    return supported.isNotEmpty ? supported.first : preferred;
  }
}
