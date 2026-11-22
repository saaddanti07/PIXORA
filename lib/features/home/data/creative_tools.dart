import 'package:flutter/material.dart';
import 'package:pixora/l10n/generated/app_localizations.dart';

/// A creative entry point on the home dashboard.
@immutable
class CreativeTool {
  const CreativeTool({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
  });

  /// Stable identifier used for analytics-free routing and future history
  /// records. Never translated.
  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// Tint used for the tool icon tile.
  final Color accent;
}

/// The eight tools planned for PIXORA.
///
/// Phase 01 renders them as finished-looking entry points that are explicitly
/// marked "coming soon": they are not wired to any processing, and tapping one
/// opens an honest explanation instead of a fake result.
List<CreativeTool> buildCreativeTools(AppLocalizations l10n) {
  return <CreativeTool>[
    CreativeTool(
      id: 'photo_enhancement',
      title: l10n.toolEnhanceTitle,
      description: l10n.toolEnhanceDescription,
      icon: Icons.auto_awesome_rounded,
      accent: const Color(0xFF7C6BFF),
    ),
    CreativeTool(
      id: 'old_photo_restoration',
      title: l10n.toolRestorationTitle,
      description: l10n.toolRestorationDescription,
      icon: Icons.auto_fix_high_rounded,
      accent: const Color(0xFFF5A524),
    ),
    CreativeTool(
      id: 'face_enhancement',
      title: l10n.toolFaceTitle,
      description: l10n.toolFaceDescription,
      icon: Icons.face_retouching_natural_rounded,
      accent: const Color(0xFF38BDF8),
    ),
    CreativeTool(
      id: 'colorization',
      title: l10n.toolColorizeTitle,
      description: l10n.toolColorizeDescription,
      icon: Icons.palette_outlined,
      accent: const Color(0xFFF472B6),
    ),
    CreativeTool(
      id: 'background_enhancement',
      title: l10n.toolBackgroundTitle,
      description: l10n.toolBackgroundDescription,
      icon: Icons.landscape_outlined,
      accent: const Color(0xFF34D399),
    ),
    CreativeTool(
      id: 'anime_style',
      title: l10n.toolAnimeTitle,
      description: l10n.toolAnimeDescription,
      icon: Icons.animation_rounded,
      accent: const Color(0xFFA78BFA),
    ),
    CreativeTool(
      id: 'artistic_effects',
      title: l10n.toolArtisticTitle,
      description: l10n.toolArtisticDescription,
      icon: Icons.brush_outlined,
      accent: const Color(0xFFFB7185),
    ),
    CreativeTool(
      id: 'pixel_art',
      title: l10n.toolPixelTitle,
      description: l10n.toolPixelDescription,
      icon: Icons.grid_on_rounded,
      accent: const Color(0xFF60A5FA),
    ),
  ];
}
