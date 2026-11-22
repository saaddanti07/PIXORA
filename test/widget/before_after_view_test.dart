import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/features/processing/widgets/before_after_view.dart';

void main() {
  testWidgets('comparison paints the actual result path separately from source', (
    WidgetTester tester,
  ) async {
    const String original = '/private/pixora/source.jpg';
    const String result = '/private/pixora/output.jpg';
    final Set<String> renderedPaths = <String>{};
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BeforeAfterView(
          beforePath: original,
          afterPath: result,
          aspectRatio: 4 / 3,
          beforeLabel: 'Original',
          afterLabel: 'Result',
          imageBuilder: (_, path, _) {
            renderedPaths.add(path);
            return const ColoredBox(color: Colors.black);
          },
        ),
      ),
    ));

    expect(renderedPaths, <String>{result, original});
    expect(renderedPaths, hasLength(2));
  });

  test('comparison rejects the same source and result file path', () {
    expect(
      () => BeforeAfterView(
        beforePath: '/private/pixora/source.jpg',
        afterPath: '/private/pixora/source.jpg',
        aspectRatio: 4 / 3,
        beforeLabel: 'Original',
        afterLabel: 'Result',
      ),
      throwsAssertionError,
    );
  });
}
