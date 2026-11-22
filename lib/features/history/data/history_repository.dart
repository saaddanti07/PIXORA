import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pixora/core/storage/key_value_store.dart';
import 'package:pixora/core/storage/preferences_keys.dart';
import 'package:pixora/features/history/models/history_entry.dart';

/// Offline history ledger. Writes are serialized and listeners are notified
/// only after the backing store acknowledges the write.
class HistoryRepository extends ChangeNotifier {
  HistoryRepository(this._store);

  final KeyValueStore _store;
  Completer<void>? _activeMutation;

  List<HistoryEntry> load() {
    final String? raw = _store.read(PreferencesKeys.historyEntries);
    if (raw == null || raw.isEmpty) return <HistoryEntry>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <HistoryEntry>[];
      final List<HistoryEntry> entries = <HistoryEntry>[];
      for (final Object? item in decoded) {
        if (item is Map<String, dynamic>) {
          final HistoryEntry? entry = HistoryEntry.fromJson(item);
          if (entry != null) entries.add(entry);
        }
      }
      entries.sort((a, b) => b.processedAt.compareTo(a.processedAt));
      return entries;
    } on FormatException {
      return <HistoryEntry>[];
    }
  }

  Future<void> add(HistoryEntry entry) => _enqueue(() async {
        final List<HistoryEntry> entries = load();
        if (entries.any((HistoryEntry current) => current.id == entry.id)) return;
        await _write(<HistoryEntry>[entry, ...entries]);
      });

  Future<void> save(List<HistoryEntry> entries) => _enqueue(() async {
        await _write(entries);
      });

  Future<void> clear() => _enqueue(() async {
        await _store.remove(PreferencesKeys.historyEntries);
        notifyListeners();
      });

  Future<void> _write(List<HistoryEntry> entries) async {
    final String encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _store.write(PreferencesKeys.historyEntries, encoded);
    notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() operation) async {
    while (_activeMutation != null) {
      await _activeMutation!.future;
    }
    final Completer<void> gate = Completer<void>();
    _activeMutation = gate;
    try {
      await operation();
    } finally {
      _activeMutation = null;
      gate.complete();
    }
  }
}
