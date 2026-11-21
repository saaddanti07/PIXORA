import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_colors.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/features/history/data/history_repository.dart';
import 'package:pixora/features/image_engine/interfaces/image_processor.dart';
import 'package:pixora/features/image_engine/models/processing_policy.dart';
import 'package:pixora/features/image_engine/models/processing_tool.dart';
import 'package:pixora/features/image_engine/services/image_engine_registry.dart';
import 'package:pixora/features/image_picker/models/image_selection_messages.dart';
import 'package:pixora/features/image_picker/models/picked_image.dart';
import 'package:pixora/features/image_picker/services/image_selection_controller.dart';
import 'package:pixora/features/image_picker/widgets/photo_details_card.dart';
import 'package:pixora/features/image_picker/widgets/photo_preview_frame.dart';
import 'package:pixora/features/processing/screens/processing_screen.dart';

/// Shows the photo the user picked, its real dimensions, and the two actions
/// that exist in Phase 01: pick another photo, or go back.
///
/// No processing result is faked here — the notice explains that enhancement
/// arrives in an upcoming update.
class ImagePreviewScreen extends StatefulWidget {
  const ImagePreviewScreen({
    required this.image,
    required this.onPickAnother,
    this.engineRegistry,
    this.historyRepository,
    this.processingPolicy,
    super.key,
  });

  /// The photo to preview.
  final PickedImage image;

  /// Opens the picker again; returns the new photo, `null` when cancelled, and
  /// may throw [ImageSelectionException].
  final Future<PickedImage?> Function() onPickAnother;

  /// The processors this build can run. When absent (widget tests, or a build
  /// without the engine) the processing actions are not shown at all, so the
  /// screen can never offer a tool that cannot work.
  final ImageEngineRegistry? engineRegistry;

  /// Where a finished result is recorded.
  final HistoryRepository? historyRepository;

  /// The Smart AI Engine limits for this device.
  final ProcessingPolicy? processingPolicy;

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late PickedImage _image = widget.image;
  bool _isPicking = false;

  PixoraImageProcessor? get _restoreProcessor => widget.historyRepository == null
      ? null
      : widget.engineRegistry?.processorFor(ProcessingToolId.oldPhotoRestoration);

  PixoraImageProcessor? get _fastProcessor => widget.historyRepository == null
      ? null
      : widget.engineRegistry?.processorFor(ProcessingToolId.photoEnhancement);

  bool get _hasProcessing => _restoreProcessor != null || _fastProcessor != null;

  Future<void> _process(ProcessingToolId tool, PixoraImageProcessor processor) async {
    final HistoryRepository? history = widget.historyRepository;
    if (history == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ProcessingScreen(
          source: _image,
          tool: tool,
          processor: processor,
          historyRepository: history,
          maxOutputDimension: widget.processingPolicy?.maxOutputDimension,
        ),
      ),
    );
  }

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
        await _releasePreviousImage(_image, next);
        if (!mounted) {
          return;
        }
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

  /// Frees the previous photo from Flutter's image cache.
  ///
  /// Two reasons: a 2-3 GB phone must not hold two full-size bitmaps just
  /// because the user swapped photos, and a cache entry that is still alive is
  /// exactly what makes a preview show a stale picture instead of the new one.
  Future<void> _releasePreviousImage(PickedImage previous, PickedImage next) async {
    if (previous.path == next.path) {
      return;
    }
    try {
      await FileImage(File(previous.path)).evict();
    } on Object {
      // Evicting is best effort: the new photo must still be shown even if the
      // old entry cannot be removed.
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
            // Keyed by path: a new selection must build a brand new image
            // widget, so the previous photo, its decoding state and its zoom
            // can never leak into the new one.
            PhotoPreviewFrame(
              key: ValueKey<String>(_image.path),
              image: _image,
            ),
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
            if (!_hasProcessing)
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
            if (_restoreProcessor != null)
              FilledButton.icon(
                onPressed: () => _process(
                  ProcessingToolId.oldPhotoRestoration,
                  _restoreProcessor!,
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                label: Text(l10n.processingRestoreAction),
              ),
            if (_restoreProcessor != null) const SizedBox(height: AppSpacing.xs),
            if (_fastProcessor != null)
              OutlinedButton.icon(
                onPressed: () => _process(
                  ProcessingToolId.photoEnhancement,
                  _fastProcessor!,
                ),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(l10n.processingEnhanceAction),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandPrimary,
                ),
              ),
            if (_fastProcessor != null) const SizedBox(height: AppSpacing.xs),
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
