import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/core/constants/app_constants.dart';
import 'package:pixora/features/image_picker/models/picked_image.dart';

/// Shows the user's photo, decoded at a bounded resolution so large images do
/// not exhaust memory on a 2-3 GB device.
class PhotoPreviewFrame extends StatelessWidget {
  const PhotoPreviewFrame({required this.image, super.key});

  final PickedImage image;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final int cacheWidth = (screenWidth * pixelRatio)
        .round()
        .clamp(1, AppConstants.maxPreviewCacheWidth)
        .toInt();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height =
            (width / image.aspectRatio).clamp(180.0, 400.0).toDouble();
        return SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: ColoredBox(
              color: const Color(0xFF101018),
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Image.file(
                    File(image.path),
                    cacheWidth: cacheWidth,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) =>
                        _PreviewError(message: context.l10n.pickErrorUnreadable),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 34),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
