import 'package:flutter_test/flutter_test.dart';
import 'package:pixora/core/storage/in_memory_key_value_store.dart';
import 'package:pixora/core/storage/preferences_keys.dart';
import 'package:pixora/features/history/data/history_repository.dart';
import 'package:pixora/features/history/models/history_entry.dart';

HistoryEntry _entry(String id, DateTime at) => HistoryEntry(
      id: id,
      fileName: '$id.jpg',
      imagePath: '/local/$id.jpg',
      processedAt: at,
      toolId: 'pixel_art',
    );

void main() {
  test('a fresh install has an empty history', () {
    final HistoryRepository repository =
        HistoryRepository(InMemoryKeyValueStore());

    expect(repository.load(), isEmpty);
  });

  test('entries round-trip through local storage, newest first', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final HistoryRepository repository = HistoryRepository(store);

    await repository.add(_entry('older', DateTime.utc(2026, 1, 1)));
    await repository.add(_entry('newer', DateTime.utc(2026, 6, 1)));

    final List<HistoryEntry> loaded = repository.load();
    expect(loaded, hasLength(2));
    expect(loaded.first.id, 'newer');
    expect(loaded.last.id, 'older');
    expect(loaded.first.fileName, 'newer.jpg');

    // A restart reads the same ledger from the same store.
    expect(HistoryRepository(store).load().first.id, 'newer');
  });

  test('clearing removes the ledger', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final HistoryRepository repository = HistoryRepository(store);

    await repository.add(_entry('one', DateTime.utc(2026, 1, 1)));
    await repository.clear();

    expect(repository.load(), isEmpty);
    expect(store.read(PreferencesKeys.historyEntries), isNull);
  });

  test('corrupted or partial data never throws', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final HistoryRepository repository = HistoryRepository(store);

    await store.write(PreferencesKeys.historyEntries, 'not-json');
    expect(repository.load(), isEmpty);

    await store.write(PreferencesKeys.historyEntries, '[{"id": "x"}]');
    expect(repository.load(), isEmpty);

    await store.write(
      PreferencesKeys.historyEntries,
      '[{"id": "ok", "fileName": "a.jpg", "imagePath": "/a.jpg", '
          '"processedAt": "2026-02-03T00:00:00.000Z"}]',
    );
    expect(repository.load().single.fileName, 'a.jpg');
  });
}
