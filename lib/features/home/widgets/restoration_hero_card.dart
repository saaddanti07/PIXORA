import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_colors.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';

/// The primary call to action: pick a photo to restore.
class RestorationHeroCard extends StatelessWidget {
  const RestorationHeroCard({
    required this.onChoosePhoto,
    required this.isPicking,
    super.key,
  });

  final VoidCallback onChoosePhoto;
  final bool isPicking;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PixoraPalette palette = PixoraPalette.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: palette.heroLinearGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: palette.cardShadow,
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -70,
            right: -50,
            child: _Glow(size: 210, opacity: 0.22),
          ),
          Positioned(
            bottom: -90,
            left: -40,
            child: _Glow(size: 190, opacity: 0.16),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.lock_outline_rounded,
                          size: 13, color: Colors.white),
                      const SizedBox(width: AppSpacing.xxs + 2),
                      Text(
                        l10n.homeHeroBadge,
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.homeHeroTitle,
                  style: textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.homeHeroDescription,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isPicking ? null : onChoosePhoto,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.brandIndigo,
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.75),
                      disabledForegroundColor:
                          AppColors.brandIndigo.withValues(alpha: 0.7),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: isPicking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.brandIndigo,
                            ),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined,
                            size: 20),
                    label: Text(
                      isPicking ? l10n.homeOpeningGallery : l10n.homeChoosePhoto,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.opacity, super.key});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
