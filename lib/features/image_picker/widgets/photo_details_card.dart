import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/core/utilities/byte_format.dart';
import 'package:pixora/core/widgets/pixora_card.dart';
import 'package:pixora/features/image_picker/models/image_format_label.dart';
import 'package:pixora/features/image_picker/models/picked_image.dart';

/// Local, factual details about the selected photo. Everything shown here is
/// read from the file on the device.
class PhotoDetailsCard extends StatelessWidget {
  const PhotoDetailsCard({required this.image, super.key});

  final PickedImage image;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PixoraPalette palette = PixoraPalette.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String dimensions = image.dimensions == null
        ? l10n.previewUnknown
        : l10n.previewDimensionValue(
            image.dimensions!.width,
            image.dimensions!.height,
          );

    return PixoraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.info_outline_rounded,
                  size: 18, color: palette.secondaryText),
              const SizedBox(width: AppSpacing.xs),
              Text(l10n.previewDetailsTitle, style: textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(label: l10n.previewFileName, value: image.fileName),
          _DetailRow(label: l10n.previewDimensions, value: dimensions),
          _DetailRow(
            label: l10n.previewFileSize,
            value: formatBytes(image.sizeBytes),
          ),
          _DetailRow(
            label: l10n.previewFormat,
            value: image.format.label(l10n),
            isLast: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: palette.mutedSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.lock_outline_rounded,
                    size: 15, color: palette.secondaryText),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.previewStoredLocally,
                    style: textTheme.labelSmall,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: textTheme.bodySmall),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
