/// Somewhere to put small pieces of data that outlive the process.
///
/// A port, not an implementation. Everything the app persists today is a handful
/// of strings per game, and committing to a database now would buy build tooling
/// and generated code against a need that has not arrived. When statistics
/// outgrow this — queries over history, per-day aggregates — only the adapter
/// changes, because nothing above this line knows how the bytes are stored.
abstract class KeyValueStore {
  /// Loads whatever the backend needs before the first read. Safe to call twice.
  Future<void> initialise();

  String? read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  /// Every key currently held. Used to enumerate records without keeping a
  /// separate index that could drift out of step with the data.
  Iterable<String> keys();
}

/// In-memory store, for tests and for a first run before anything is saved.
///
/// Reads are synchronous and writes complete immediately, which is exactly what
/// makes it usable in a widget test without pumping timers.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? seed])
      : _values = {...?seed};

  final Map<String, String> _values;

  @override
  Future<void> initialise() async {}

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Iterable<String> keys() => _values.keys.toList();
}
