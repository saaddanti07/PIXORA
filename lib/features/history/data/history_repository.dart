import 'dart:convert';

import 'package:pixora/core/storage/key_value_store.dart';
import 'package:pixora/core/storage/preferences_keys.dart';
import 'package:pixora/features/history/models/history_entry.dart';

/// Local, offline history ledger.
///
/// Only lightweight metadata is stored (never image bytes), newest first. The
/// repository is intentionally tolerant: corrupted or hand-edited data yields
/// an empty list rather than a crash on start-up.
class HistoryRepository {
  HistoryRepository(this._store);

  final KeyValueStore _store;

  List<HistoryEntry> load() {
    final String? raw = _store.read(PreferencesKeys.historyEntries);
    if (raw == null || raw.isEmpty) {
      return <HistoryEntry>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <HistoryEntry>[];
      }
      final List<HistoryEntry> entries = <HistoryEntry>[];
      for (final Object? item in decoded) {
        if (item is Map<String, dynamic>) {
          final HistoryEntry? entry = HistoryEntry.fromJson(item);
          if (entry != null) {
            entries.add(entry);
          }
        }
      }
      entries.sort(
        (HistoryEntry a, HistoryEntry b) => b.processedAt.compareTo(a.processedAt),
      );
      return entries;
    } on FormatException {
      return <HistoryEntry>[];
    }
  }

  Future<void> save(List<HistoryEntry> entries) async {
    final String encoded = jsonEncode(
      entries.map((HistoryEntry entry) => entry.toJson()).toList(),
    );
    await _store.write(PreferencesKeys.historyEntries, encoded);
  }

  Future<void> add(HistoryEntry entry) async {
    final List<HistoryEntry> entries = load()
      ..insert(0, entry);
    await save(entries);
  }

  Future<void> clear() async {
    await _store.remove(PreferencesKeys.historyEntries);
  }
}
