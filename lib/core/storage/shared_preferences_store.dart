import 'package:pixora/core/storage/key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [KeyValueStore] backed by Android `SharedPreferences`.
///
/// This is the only storage implementation used in production. It never
/// leaves the device and never stores image bytes — only preferences and small
/// metadata records.
class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore._(this._preferences);

  final SharedPreferences _preferences;

  static Future<SharedPreferencesStore> open() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return SharedPreferencesStore._(preferences);
  }

  @override
  String? read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _preferences.remove(key);
  }
}
