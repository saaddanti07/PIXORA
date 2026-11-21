import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/core/storage/in_memory_key_value_store.dart';
import 'package:pixora/features/history/data/history_repository.dart';
import 'package:pixora/features/history/models/history_entry.dart';
import 'package:pixora/features/history/screens/history_screen.dart';
import 'package:pixora/features/processing/widgets/before_after_view.dart';

import '../helpers/image_fixtures.dart';

void main() {
  testWidgets('newly persisted item appears with thumbnail and reopens comparison',
      (WidgetTester tester) async {
    final Directory dir = await Directory.systemTemp.createTemp('pixora_history_widget');
    addTearDown(() async { if (await dir.exists()) await dir.delete(recursive: true); });
    final File original = File('${dir.path}/original.png')..writeAsBytesSync(tinyPng);
    final File restored = File('${dir.path}/restored.png')..writeAsBytesSync(tinyPng);
    final HistoryRepository repository = HistoryRepository(InMemoryKeyValueStore());
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: HistoryScreen(repository: repository, onStartRestoration: () {}),
    ));
    expect(find.text('No processed photos yet'), findsOneWidget);

    await repository.add(HistoryEntry(
      id: 'one', fileName: 'saved-photo.png', imagePath: restored.path,
      originalPath: original.path, processedAt: DateTime.utc(2026, 5, 2),
      methodId: 'on-device-ai', durationMs: 89700,
      originalWidth: 640, originalHeight: 480,
      outputWidth: 2048, outputHeight: 1536,
    ));
    await tester.pump();
    expect(find.text('saved-photo.png'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('saved-photo.png'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(BeforeAfterView), findsOneWidget);
    repository.dispose();
  });
}
