import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/features/history/models/history_entry.dart';
import 'package:pixora/features/history/widgets/history_list.dart';
import 'package:pixora/features/history/screens/history_comparison_screen.dart';
import 'package:pixora/features/processing/widgets/before_after_view.dart';

import '../helpers/image_fixtures.dart';

void main() {
  testWidgets('thumbnail row tap selects the saved entry for reopening', (tester) async {
    final Directory dir = await Directory.systemTemp.createTemp('pixora_history_list');
    addTearDown(() async { if (await dir.exists()) await dir.delete(recursive: true); });
    final File image = File('${dir.path}/result.png')..writeAsBytesSync(tinyPng);
    final HistoryEntry entry = HistoryEntry(
      id: 'saved', fileName: 'old-photo.png', imagePath: image.path,
      originalPath: image.path, processedAt: DateTime.utc(2026),
      methodId: 'on-device-ai', originalWidth: 640, originalHeight: 480,
      outputWidth: 2048, outputHeight: 1536,
    );
    HistoryEntry? opened;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: HistoryList(
        entries: <HistoryEntry>[entry],
        onOpen: (e) => opened = e,
        thumbnailBuilder: (_, __) => const SizedBox(width: 64, height: 64),
      )),
    ));
    final InkWell row = tester.widget<InkWell>(find.byType(InkWell));
    row.onTap!();
    expect(opened, entry);
  });

  testWidgets('comparison route renders the stored original and restored pair', (tester) async {
    final Directory dir = await Directory.systemTemp.createTemp('pixora_history_compare');
    addTearDown(() async { if (await dir.exists()) await dir.delete(recursive: true); });
    final File original = File('${dir.path}/original.png')..writeAsBytesSync(tinyPng);
    final File output = File('${dir.path}/restored.png')..writeAsBytesSync(tinyPng);
    final HistoryEntry entry = HistoryEntry(
      id: 'saved', fileName: 'old-photo.png', imagePath: output.path,
      originalPath: original.path, processedAt: DateTime.utc(2026),
      methodId: 'on-device-ai', originalWidth: 640, originalHeight: 480,
      outputWidth: 2048, outputHeight: 1536,
    );
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: HistoryComparisonScreen(
        entry: entry,
        imageBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
      ),
    ));
    expect(find.byType(BeforeAfterView), findsOneWidget);
    expect(find.text('old-photo.png'), findsOneWidget);
  });
}
