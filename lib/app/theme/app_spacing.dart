/// Spacing scale (dp) used for every gap and padding in the interface.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 44;

  /// Horizontal padding used by every screen so the layout rhythm matches.
  static const double screen = 20;
}

/// Corner radii used by cards, sheets and controls.
abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 26;
  static const double pill = 999;
}

/// Motion durations, kept short so the UI feels responsive on slower phones.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);
}
