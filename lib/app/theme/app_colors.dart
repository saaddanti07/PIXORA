import 'package:flutter/material.dart';

/// Raw brand colours.
///
/// Widgets should normally use theme tokens ([ColorScheme] and
/// [PixoraPalette]) so light and dark mode stay coherent; these constants are
/// the single source of truth those tokens are built from.
abstract final class AppColors {
  static const Color brandPrimary = Color(0xFF5B4BE0);
  static const Color brandViolet = Color(0xFF8B5CF6);
  static const Color brandIndigo = Color(0xFF3B2FA8);
  static const Color accent = Color(0xFFF5A524);
  static const Color accentSoft = Color(0xFFFFD08A);

  // Light theme surfaces.
  static const Color lightBackground = Color(0xFFF7F6FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE9E7F4);
  static const Color lightMutedSurface = Color(0xFFF1EFFA);
  static const Color lightTextPrimary = Color(0xFF15131F);
  static const Color lightTextSecondary = Color(0xFF6C6885);

  // Dark theme surfaces.
  static const Color darkBackground = Color(0xFF0A0912);
  static const Color darkSurface = Color(0xFF15131F);
  static const Color darkBorder = Color(0xFF29263A);
  static const Color darkMutedSurface = Color(0xFF1D1A2B);
  static const Color darkTextPrimary = Color(0xFFF5F3FD);
  static const Color darkTextSecondary = Color(0xFF9E9AB5);
}
