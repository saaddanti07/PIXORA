import 'package:flutter/material.dart';
import 'package:pixora/app/theme/app_colors.dart';

/// Brand tokens that Material's [ColorScheme] does not describe: gradients,
/// elevation shadows and the surface nuances PIXORA uses across screens.
///
/// Exposed as a [ThemeExtension] so widgets read them from the theme instead of
/// branching on brightness, and so light/dark transitions animate smoothly.
@immutable
class PixoraPalette extends ThemeExtension<PixoraPalette> {
  const PixoraPalette({
    required this.brandGradient,
    required this.heroGradient,
    required this.accent,
    required this.cardSurface,
    required this.cardBorder,
    required this.mutedSurface,
    required this.iconSurface,
    required this.secondaryText,
    required this.cardShadow,
  });

  final List<Color> brandGradient;
  final List<Color> heroGradient;
  final Color accent;
  final Color cardSurface;
  final Color cardBorder;
  final Color mutedSurface;
  final Color iconSurface;
  final Color secondaryText;
  final List<BoxShadow> cardShadow;

  LinearGradient get brandLinearGradient => LinearGradient(
        colors: brandGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get heroLinearGradient => LinearGradient(
        colors: heroGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const PixoraPalette light = PixoraPalette(
    brandGradient: <Color>[AppColors.brandPrimary, AppColors.brandViolet],
    heroGradient: <Color>[
      Color(0xFF5B4BE0),
      Color(0xFF7C5CEA),
      Color(0xFFA855F7),
    ],
    accent: AppColors.accent,
    cardSurface: AppColors.lightSurface,
    cardBorder: AppColors.lightBorder,
    mutedSurface: AppColors.lightMutedSurface,
    iconSurface: Color(0xFFF0EDFF),
    secondaryText: AppColors.lightTextSecondary,
    cardShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x14191333),
        blurRadius: 24,
        offset: Offset(0, 10),
        spreadRadius: -8,
      ),
    ],
  );

  static const PixoraPalette dark = PixoraPalette(
    brandGradient: <Color>[Color(0xFF7C6BFF), Color(0xFFC084FC)],
    heroGradient: <Color>[
      Color(0xFF3F33BC),
      Color(0xFF6D4AE0),
      Color(0xFF9B4BF0),
    ],
    accent: AppColors.accent,
    cardSurface: AppColors.darkSurface,
    cardBorder: AppColors.darkBorder,
    mutedSurface: AppColors.darkMutedSurface,
    iconSurface: Color(0xFF231F35),
    secondaryText: AppColors.darkTextSecondary,
    cardShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 26,
        offset: Offset(0, 12),
        spreadRadius: -10,
      ),
    ],
  );

  /// Palette for the current theme, falling back to the light palette when the
  /// widget is rendered outside a PIXORA [ThemeData] (for example in tests).
  static PixoraPalette of(BuildContext context) =>
      Theme.of(context).extension<PixoraPalette>() ?? light;

  @override
  PixoraPalette copyWith({
    List<Color>? brandGradient,
    List<Color>? heroGradient,
    Color? accent,
    Color? cardSurface,
    Color? cardBorder,
    Color? mutedSurface,
    Color? iconSurface,
    Color? secondaryText,
    List<BoxShadow>? cardShadow,
  }) {
    return PixoraPalette(
      brandGradient: brandGradient ?? this.brandGradient,
      heroGradient: heroGradient ?? this.heroGradient,
      accent: accent ?? this.accent,
      cardSurface: cardSurface ?? this.cardSurface,
      cardBorder: cardBorder ?? this.cardBorder,
      mutedSurface: mutedSurface ?? this.mutedSurface,
      iconSurface: iconSurface ?? this.iconSurface,
      secondaryText: secondaryText ?? this.secondaryText,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  PixoraPalette lerp(ThemeExtension<PixoraPalette>? other, double t) {
    if (other is! PixoraPalette) {
      return this;
    }
    return PixoraPalette(
      brandGradient: _lerpColorList(brandGradient, other.brandGradient, t),
      heroGradient: _lerpColorList(heroGradient, other.heroGradient, t),
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t) ?? cardSurface,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t) ?? cardBorder,
      mutedSurface: Color.lerp(mutedSurface, other.mutedSurface, t) ?? mutedSurface,
      iconSurface: Color.lerp(iconSurface, other.iconSurface, t) ?? iconSurface,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t) ?? secondaryText,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t) ?? cardShadow,
    );
  }

  static List<Color> _lerpColorList(List<Color> a, List<Color> b, double t) {
    final int length = a.length < b.length ? a.length : b.length;
    return <Color>[
      for (int index = 0; index < length; index++)
        Color.lerp(a[index], b[index], t) ?? a[index],
    ];
  }
}
