import 'package:flutter/material.dart';

/// Typographic scale for PIXORA.
///
/// The app relies on the platform font (Roboto on Android, with full Arabic
/// coverage through the system fallback) so that the APK stays small — which
/// matters for the 32 GB / 2 GB RAM target device — while the weights,
/// tracking and line heights below still give the interface its own voice.
abstract final class AppTypography {
  static TextTheme build(
    TextTheme base, {
    required Color primary,
    required Color secondary,
  }) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.14,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.18,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.2,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: base.titleSmall?.copyWith(
        color: primary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: primary, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(color: secondary, height: 1.5),
      bodySmall: base.bodySmall?.copyWith(color: secondary, height: 1.45),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelSmall: base.labelSmall?.copyWith(
        color: secondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}
