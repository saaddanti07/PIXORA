import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/app/theme/pixora_palette.dart';
import 'package:pixora/features/history/data/history_repository.dart';
import 'package:pixora/features/history/models/history_entry.dart';
import 'package:pixora/features/image_engine/interfaces/image_processor.dart';
import 'package:pixora/features/image_engine/interfaces/progress_aware_processor.dart';
import 'package:pixora/features/image_engine/models/image_processing_request.dart';
import 'package:pixora/features/image_engine/models/image_processing_result.dart';
import 'package:pixora/features/image_engine/models/processing_tool.dart';
import 'package:pixora/features/image_engine/services/native_engine_channel.dart';
import 'package:pixora/features/image_engine/services/gallery_export_service.dart';
import 'package:pixora/features/image_picker/models/picked_image.dart';
import 'package:pixora/features/processing/widgets/before_after_view.dart';

enum _Phase { running, success, failure, cancelled }

/// Runs one tool on one photo and shows exactly what happened.
///
/// Nothing here is a placeholder: the progress bar is driven by real per-tile
/// events from the native engine, the ETA is the engine's own projection, Cancel
/// really stops the job between tiles, and the result view shows the file the
/// engine actually produced next to the untouched original.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({
    required this.source,
    required this.tool,
    required this.processor,
    required this.historyRepository,
    this.maxOutputDimension,
    this.galleryExportService = const AndroidGalleryExportService(),
    super.key,
  });

  final PickedImage source;
  final ProcessingToolId tool;
  final PixoraImageProcessor processor;
  final HistoryRepository historyRepository;
  final int? maxOutputDimension;
  final GalleryExportService galleryExportService;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  _Phase _phase = _Phase.running;
  EngineProgress? _progress;
  ImageProcessingResult? _result;
  String? _error;
  bool _cancelling = false;
  bool _historySaved = false;
  bool _exporting = false;
  StreamSubscription<EngineProgress>? _subscription;

  bool get _usesAi => widget.tool == ProcessingToolId.oldPhotoRestoration;

  @override
  void initState() {
    super.initState();
    // Started on a microtask: the first setState must not run while this widget
    // is still being mounted, and the job must not wait for a frame either.
    Future<void>.microtask(() {
      if (mounted) {
        _run();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _phase = _Phase.running;
      _error = null;
      _result = null;
      _progress = null;
      _cancelling = false;
      _historySaved = false;
    });

    final ProgressAwareProcessor? aware = _progressAware();
    _subscription = aware?.progress.listen((EngineProgress event) {
      if (mounted) {
        setState(() => _progress = event);
      }
    });

    ImageProcessingResult result;
    try {
      result = await widget.processor.process(
        ImageProcessingRequest(
          sourcePath: widget.source.path,
          tool: widget.tool,
          maxOutputDimension: widget.maxOutputDimension,
        ),
      );
    } on Object catch (error) {
      result = ImageProcessingResult.failed(error.toString());
    } finally {
      // Deliberately not awaited: a completed job must not depend on the
      // stream teardown to publish its result.
      _subscription?.cancel();
      _subscription = null;
    }

    if (!mounted) {
      return;
    }

    switch (result.status) {
      case ImageProcessingStatus.succeeded:
        final bool historySaved = await _recordHistory(result);
        if (!mounted) {
          return;
        }
        setState(() {
          _phase = _Phase.success;
          _result = result;
          _historySaved = historySaved;
        });
      case ImageProcessingStatus.cancelled:
        setState(() => _phase = _Phase.cancelled);
      case ImageProcessingStatus.failed:
        setState(() {
          _phase = _Phase.failure;
          _error = result.failureReason;
        });
    }
  }

  Future<bool> _recordHistory(ImageProcessingResult result) async {
    final String? outputPath = result.outputPath;
    if (outputPath == null || outputPath.isEmpty) return false;
    final File output = File(outputPath);
    final File original = File(widget.source.path);
    if (output.absolute.path == original.absolute.path) return false;
    String? archivedOriginalPath;
    try {
      if (!await output.exists() || await output.length() <= 0 ||
          !await original.exists() || await original.length() <= 0) {
        return false;
      }
      final DateTime now = DateTime.now();
      final String id = '${now.microsecondsSinceEpoch}';
      final Directory archive = Directory(
        '${output.parent.path}${Platform.pathSeparator}history_sources',
      );
      await archive.create(recursive: true);
      final String extension = widget.source.fileName.contains('.')
          ? '.${widget.source.fileName.split('.').last}'
          : '.img';
      archivedOriginalPath =
          '${archive.path}${Platform.pathSeparator}pixora_${id}_original$extension';
      await original.copy(archivedOriginalPath);
      await widget.historyRepository.add(
        HistoryEntry(
          id: id,
          fileName: widget.source.fileName,
          imagePath: outputPath,
          originalPath: archivedOriginalPath,
          processedAt: now,
          methodId: _usesAi ? 'on-device-ai' : 'classical-enhancement',
          durationMs: result.duration.inMilliseconds,
          originalWidth: result.sourceWidth ?? widget.source.dimensions?.width,
          originalHeight: result.sourceHeight ?? widget.source.dimensions?.height,
          outputWidth: result.outputWidth,
          outputHeight: result.outputHeight,
          toolId: widget.tool.name,
        ),
      );
      return true;
    } on Object {
      if (archivedOriginalPath != null) {
        try { await File(archivedOriginalPath).delete(); } on Object { /* best effort */ }
      }
      return false;
    }
  }

  Future<void> _exportToGallery() async {
    final String? path = _result?.outputPath;
    if (path == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      await widget.galleryExportService.saveRestoredImage(
        path: path,
        displayName: 'PIXORA_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.processingGallerySaved)),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.processingGalleryFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _cancel() async {
    if (_cancelling) {
      return;
    }
    setState(() => _cancelling = true);
    await _progressAware()?.cancelActiveJob();
  }

  /// The processor exposing progress/cancel, if it has one.
  ///
  /// The declared type is `Object` on purpose: promotion from the processor
  /// interface to the optional capability interface is not applied by the
  /// analyser, and an explicit cast keeps this honest and obvious.
  ProgressAwareProcessor? _progressAware() {
    final Object processor = widget.processor;
    if (processor is ProgressAwareProcessor) {
      return processor;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_usesAi ? l10n.processingTitle : l10n.processingFastTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: l10n.processingClose,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: switch (_phase) {
            _Phase.running => _RunningView(
                source: widget.source,
                progress: _progress,
                usesAi: _usesAi,
                cancelling: _cancelling,
                onCancel: _cancel,
              ),
            _Phase.success => _SuccessView(
                source: widget.source,
                result: _result!,
                usesAi: _usesAi,
                historySaved: _historySaved,
                exporting: _exporting,
                onExport: _exportToGallery,
                onClose: () => Navigator.of(context).maybePop(),
              ),
            _Phase.failure => _FailureView(
                message: _error ?? '',
                onRetry: _run,
                onClose: () => Navigator.of(context).maybePop(),
              ),
            _Phase.cancelled => _CancelledView(
                onClose: () => Navigator.of(context).maybePop(),
              ),
          },
        ),
      ),
    );
  }
}

class _RunningView extends StatelessWidget {
  const _RunningView({
    required this.source,
    required this.progress,
    required this.usesAi,
    required this.cancelling,
    required this.onCancel,
  });

  final PickedImage source;
  final EngineProgress? progress;
  final bool usesAi;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PixoraPalette palette = PixoraPalette.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final EngineProgress? details = progress;
    final double? fraction = details?.fraction;
    final Duration? remaining = details?.estimatedRemaining;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.file(
              File(source.path),
              fit: BoxFit.contain,
              cacheWidth: 900,
              errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                  ColoredBox(
                color: palette.mutedSurface,
                child: const Center(child: Icon(Icons.image_outlined, size: 48)),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          details == null
              ? l10n.processingPreparing
              : l10n.processingTiles(details.completedTiles, details.totalTiles),
          style: textTheme.titleSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: palette.mutedSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          remaining == null
              ? ''
              : l10n.processingRemaining(remaining.inSeconds.clamp(1, 3600).toInt()),
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.shield_outlined, size: 16, color: palette.accent),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                l10n.processingOnDevice,
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: cancelling ? null : onCancel,
          icon: cancelling
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.stop_circle_outlined, size: 18),
          label: Text(
            cancelling ? l10n.processingCancelling : l10n.processingCancel,
          ),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.source,
    required this.result,
    required this.usesAi,
    required this.historySaved,
    required this.exporting,
    required this.onExport,
    required this.onClose,
  });

  final PickedImage source;
  final ImageProcessingResult result;
  final bool usesAi;
  final bool historySaved;
  final bool exporting;
  final VoidCallback onExport;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PixoraPalette palette = PixoraPalette.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? outputPath = result.outputPath;

    return ListView(
      children: <Widget>[
        if (outputPath != null)
          BeforeAfterView(
            beforePath: source.path,
            afterPath: outputPath,
            aspectRatio: source.aspectRatio,
            beforeLabel: l10n.processingOriginal,
            afterLabel: l10n.processingResult,
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.processingCompareHint,
          style: textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.mutedSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    usesAi ? Icons.auto_awesome_rounded : Icons.tune_rounded,
                    size: 18,
                    color: palette.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    usesAi ? l10n.processingAiBadge : l10n.processingClassicalBadge,
                    style: textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (usesAi) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.processingAiCapabilityNote, style: textTheme.bodySmall),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                historySaved ? l10n.processingSavedToHistory : l10n.processingHistorySaveFailed,
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.processingDuration(
                  (result.duration.inMilliseconds / 1000).clamp(0.1, 3600).toStringAsFixed(1),
                ),
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: exporting || outputPath == null ? null : onExport,
          icon: exporting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_alt_rounded),
          label: Text(exporting ? l10n.processingGallerySaving : l10n.processingGalleryExport),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: onClose,
          child: Text(l10n.processingClose),
        ),
      ],
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.processingFailedTitle, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onRetry, child: Text(l10n.processingTryAgain)),
          const SizedBox(height: AppSpacing.xs),
          TextButton(onPressed: onClose, child: Text(l10n.processingClose)),
        ],
      ),
    );
  }
}

class _CancelledView extends StatelessWidget {
  const _CancelledView({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.stop_circle_outlined, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.processingCancelledTitle, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.processingCancelledBody,
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onClose, child: Text(l10n.processingClose)),
        ],
      ),
    );
  }
}
