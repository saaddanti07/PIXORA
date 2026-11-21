import 'package:flutter/widgets.dart';
import 'package:pixora/app/state/settings_controller.dart';

/// Makes the [SettingsController] available to the widget tree and rebuilds
/// dependents whenever the theme or language changes.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    required SettingsController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// Returns the controller and subscribes the calling widget to changes.
  static SettingsController of(BuildContext context) {
    final SettingsScope? scope =
        context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope.of() called without a SettingsScope.');
    return scope!.notifier!;
  }

  /// Returns the controller without subscribing to changes (for callbacks).
  static SettingsController read(BuildContext context) {
    final SettingsScope? scope =
        context.getInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope.read() called without a SettingsScope.');
    return scope!.notifier!;
  }
}
