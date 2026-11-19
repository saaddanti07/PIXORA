/// Minimal synchronous key/value contract used by PIXORA preferences.
///
/// Reads are synchronous because both implementations cache their values in
/// memory, which keeps the settings UI free of loading flicker. The abstraction
/// also keeps unit tests independent from any platform plugin.
abstract interface class KeyValueStore {
  String? read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);
}
