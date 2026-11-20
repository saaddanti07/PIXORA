import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/core/models/image_dimensions.dart';
import 'package:pixora/core/storage/in_memory_key_value_store.dart';
import 'package:pixora/core/utilities/image_format.dart';
import 'package:pixora/features/history/data/history_repository.dart';
import 'package:pixora/features/history/models/history_entry.dart';
import 'package:pixora/features/image_engine/interfaces/image_restoration_service.dart';
import 'package:pixora/features/image_engine/interfaces/progress_aware_processor.dart';
import 'package:pixora/features/image_engine/models/image_processing_request.dart';
import 'package:pixora/features/image_engine/models/image_processing_result.dart';
import 'package:pixora/features/image_engine/models/model_spec.dart';
import 'package:pixora/features/image_engine/models/processing_tool.dart';
import 'package:pixora/features/image_engine/services/native_engine_channel.dart';
import 'package:pixora/features/image_picker/models/picked_image.dart';
import 'package:pixora/features/processing/screens/processing_screen.dart';

import '../helpers/image_fixtures.dart';

/// A processor double that reports one progress event and then finishes.
class FakeRestorationProcessor
    implements ImageRestorationService, ProgressAwareProcessor {
  FakeRestorationProcessor({
    required this.result,
    this.emitProgress = true,
    this.hangUntilCancelled = false,
  });

  final ImageProcessingResult result;
  final bool emitProgress;
  final bool hangUntilCancelled;

  final StreamController<EngineProgress> _events =
      StreamController<EngineProgress>.broadcast();
  final Completer<ImageProcessingResult> _pending =
      Completer<ImageProcessingResult>();

  int calls = 0;
  int cancellations = 0;
  ImageProcessingRequest? lastRequest;

  @override
  ProcessingToolId get toolId => ProcessingToolId.oldPhotoRestoration;

  @override
  ModelAvailability get availability => ModelAvailability.bundled;

  @override
  List<ModelSpec> get models => const <ModelSpec>[];

  @override
  Stream<EngineProgress> get progress => _events.stream;

  @override
  Future<void> cancelActiveJob() async {
    cancellations++;
    if (hangUntilCancelled && !_pending.isCompleted) {
      _pending.complete(const ImageProcessingResult.cancelled());
    }
  }

  @override
  Future<ImageProcessingResult> process(ImageProcessingRequest request) =>
      restore(request);

  @override
  Future<ImageProcessingResult> restore(ImageProcessingRequest request) async {
    calls++;
    lastRequest = request;
    if (emitProgress) {
      _events.add(
        const EngineProgress(
          jobId: 'job',
          completedTiles: 6,
          totalTiles: 24,
          elapsedMs: 9000,
          etaMs: 27000,
        ),
      );
    }
    if (hangUntilCancelled) {
      return _pending.future;
    }
    return result;
  }
}

Future<Directory> _tempDirectory() async =>
    Directory.systemTemp.createTemp('pixora_processing_screen');

/// Pumps a fixed number of frames.
///
/// `pumpAndSettle` cannot be used while an indeterminate progress indicator is on
/// screen: it animates forever by design, which is exactly what we want the user
/// to see while the engine works.
Future<void> settle(WidgetTester tester, {int frames = 16}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory temp;
  late String imagePath;
  late InMemoryKeyValueStore store;
  late HistoryRepository history;

  setUp(() async {
    temp = await _tempDirectory();
    imagePath = '${temp.path}/photo.png';
    File(imagePath).writeAsBytesSync(tinyPng);
    store = InMemoryKeyValueStore();
    history = HistoryRepository(store);
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  PickedImage picked() => PickedImage(
        path: imagePath,
        fileName: 'photo.png',
        sizeBytes: tinyPng.length,
        format: ImageFormat.png,
        dimensions: const ImageDimensions(width: 800, height: 600),
      );

  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      );

  testWidgets('shows real progress and then the comparison view', (
    WidgetTester tester,
  ) async {
    final File output = File('${temp.path}/result.png')..writeAsBytesSync(tinyPng);
    final FakeRestorationProcessor processor = FakeRestorationProcessor(
      result: ImageProcessingResult(
        status: ImageProcessingStatus.succeeded,
        outputPath: output.path,
        modelId: 'real_esrgan_general_x4v3',
        duration: const Duration(seconds: 42),
      ),
    );

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        ProcessingScreen(
          source: picked(),
          tool: ProcessingToolId.oldPhotoRestoration,
          processor: processor,
          historyRepository: history,
          maxOutputDimension: 2048,
        ),
      ),
    );
    await tester.pump();
    expect(processor.calls, 1);
    expect(processor.lastRequest?.maxOutputDimension, 2048);

    await settle(tester);

    expect(find.text('On-device AI'), findsOneWidget);
    expect(find.text('Drag the handle to compare'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Result'), findsOneWidget);
    expect(find.text('Saved to your History'), findsOneWidget);

    final List<HistoryEntry> entries = history.load();
    expect(entries, hasLength(1));
    expect(entries.single.imagePath, output.path);
    expect(entries.single.toolId, ProcessingToolId.oldPhotoRestoration.name);
  });

  testWidgets('the progress line reports tiles from the engine', (
    WidgetTester tester,
  ) async {
    final Completer<ImageProcessingResult> pending =
        Completer<ImageProcessingResult>();
    final _HangingProcessor processor = _HangingProcessor(pending);

    await tester.pumpWidget(
      wrap(
        ProcessingScreen(
          source: picked(),
          tool: ProcessingToolId.oldPhotoRestoration,
          processor: processor,
          historyRepository: history,
        ),
      ),
    );
    await tester.pump();

    processor.emit(
      const EngineProgress(
        jobId: 'job',
        completedTiles: 6,
        totalTiles: 24,
        elapsedMs: 9000,
        etaMs: 27000,
      ),
    );
    await tester.pump();

    expect(find.text('Tile 6 of 24'), findsOneWidget);
    expect(find.text('About 27 s remaining'), findsOneWidget);
    expect(find.text('Runs entirely on your device. Nothing is uploaded.'),
        findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value,
      closeTo(0.25, 0.0001),
    );

    pending.complete(const ImageProcessingResult.cancelled());
    await settle(tester);
  });

  testWidgets('cancel really asks the processor to stop', (WidgetTester tester) async {
    final FakeRestorationProcessor processor = FakeRestorationProcessor(
      result: const ImageProcessingResult.cancelled(),
      emitProgress: false,
      hangUntilCancelled: true,
    );

    await tester.pumpWidget(
      wrap(
        ProcessingScreen(
          source: picked(),
          tool: ProcessingToolId.oldPhotoRestoration,
          processor: processor,
          historyRepository: history,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(processor.cancellations, 1);

    await settle(tester);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Your original photo is untouched.'), findsOneWidget);
    expect(history.load(), isEmpty);
  });

  testWidgets('a failure is reported honestly and can be retried', (
    WidgetTester tester,
  ) async {
    final FakeRestorationProcessor processor = FakeRestorationProcessor(
      result: ImageProcessingResult.failed('out of memory'),
      emitProgress: false,
    );

    await tester.pumpWidget(
      wrap(
        ProcessingScreen(
          source: picked(),
          tool: ProcessingToolId.oldPhotoRestoration,
          processor: processor,
          historyRepository: history,
        ),
      ),
    );
    await settle(tester);

    expect(find.text('Could not process this photo'), findsOneWidget);
    expect(find.text('out of memory'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(processor.calls, 2);
  });
}

/// Emits progress on demand and finishes when the test says so.
class _HangingProcessor implements ImageRestorationService, ProgressAwareProcessor {
  _HangingProcessor(this._pending);

  final Completer<ImageProcessingResult> _pending;
  final StreamController<EngineProgress> _events =
      StreamController<EngineProgress>.broadcast();

  void emit(EngineProgress progress) => _events.add(progress);

  @override
  ProcessingToolId get toolId => ProcessingToolId.oldPhotoRestoration;

  @override
  ModelAvailability get availability => ModelAvailability.bundled;

  @override
  List<ModelSpec> get models => const <ModelSpec>[];

  @override
  Stream<EngineProgress> get progress => _events.stream;

  @override
  Future<void> cancelActiveJob() async {}

  @override
  Future<ImageProcessingResult> process(ImageProcessingRequest request) =>
      _pending.future;

  @override
  Future<ImageProcessingResult> restore(ImageProcessingRequest request) =>
      _pending.future;
}
