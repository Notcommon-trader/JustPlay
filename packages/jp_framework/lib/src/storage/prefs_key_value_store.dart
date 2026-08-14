import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_store.dart';

/// [KeyValueStore] backed by the platform's own preference store.
///
/// Reads are served from an in-memory cache filled once by [initialise], so the
/// UI never awaits storage while building. Writes go through to disk, and the
/// cache is updated first — a write that fails must not leave the app showing a
/// value it did not manage to save.
class PrefsKeyValueStore implements KeyValueStore {
  PrefsKeyValueStore({this.prefix = 'jp.'});

  /// Namespaces every key. Two features writing `best` into the same store is a
  /// bug that only appears once both ship.
  final String prefix;

  SharedPreferences? _prefs;
  final Map<String, String> _cache = {};

  @override
  Future<void> initialise() async {
    if (_prefs != null) return;

    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _cache.clear();

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final value = prefs.getString(key);
      if (value != null) _cache[key.substring(prefix.length)] = value;
    }
  }

  @override
  String? read(String key) => _cache[key];

  @override
  Future<void> write(String key, String value) async {
    _cache[key] = value;
    await _prefs?.setString('$prefix$key', value);
  }

  @override
  Future<void> delete(String key) async {
    _cache.remove(key);
    await _prefs?.remove('$prefix$key');
  }

  @override
  Iterable<String> keys() => _cache.keys.toList();
}
