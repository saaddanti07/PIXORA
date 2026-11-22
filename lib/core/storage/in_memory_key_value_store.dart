import 'package:pixora/core/storage/key_value_store.dart';

/// Non-persistent [KeyValueStore] used by tests and by design previews.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore({Map<String, String> initialValues = const <String, String>{}})
      : _values = <String, String>{...initialValues};

  final Map<String, String> _values;

  /// Read-only copy of the stored values.
  Map<String, String> get values => Map<String, String>.unmodifiable(_values);

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}
