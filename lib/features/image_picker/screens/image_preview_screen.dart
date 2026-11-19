import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_colors.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/features/image_picker/models/image_selection_messages.dart';
import 'package:pixora/features/image_picker/models/picked_image.dart';
import 'package:pixora/features/image_picker/services/image_selection_controller.dart';
import 'package:pixora/features/image_picker/widgets/photo_details_card.dart';
import 'package:pixora/features/image_picker/widgets/photo_preview_frame.dart';

/// Shows the photo the user picked, its real dimensions, and the two actions
/// that exist in Phase 01: pick another photo, or go back.
///
/// No processing result is faked here — the notice explains that enhancement
/// arrives in an upcoming update.
class ImagePreviewScreen extends StatefulWidget {
  const ImagePreviewScreen({
    required this.image,
    required this.onPickAnother,
    super.key,
  });

  /// The photo to preview.
  final PickedImage image;

  /// Opens the picker again; returns the new photo, `null` when cancelled, and
  /// may throw [ImageSelectionException].
  final Future<PickedImage?> Function() onPickAnother;

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late PickedImage _image = widget.image;
  bool _isPicking = false;

  Future<void> _pickAnother() async {
    if (_isPicking) {
      return;
    }
    setState(() => _isPicking = true);
    try {
      final PickedImage? next = await widget.onPickAnother();
      if (!mounted) {
        return;
      }
      if (next != null) {
        setState(() => _image = next);
      }
    } on ImageSelectionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(imageSelectionErrorMessage(context.l10n, error.kind)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PixoraPalette palette = PixoraPalette.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: l10n.previewClose,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.previewTitle),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.xl,
          ),
          children: <Widget>[
            PhotoPreviewFrame(image: _image),
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: Text(
                l10n.previewZoomHint,
                style: textTheme.labelSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PhotoDetailsCard(image: _image),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.mutedSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.auto_awesome_outlined,
                      size: 18, color: palette.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.previewFutureNotice,
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FilledButton.icon(
              onPressed: _isPicking ? null : _pickAnother,
              icon: _isPicking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined, size: 20),
              label: Text(l10n.previewChooseAnother),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(l10n.previewBackHome),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
