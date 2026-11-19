import 'package:flutter/widgets.dart';
import 'package:pixora/l10n/generated/app_localizations.dart';

export 'package:pixora/l10n/generated/app_localizations.dart';

/// `context.l10n` — the shortest path to translated interface strings.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
