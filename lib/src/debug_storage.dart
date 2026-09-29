/// One key/value pair shown in the Storage tab.
class DebugStorageEntry {
  /// Creates an entry. [value] is pretty-printed when it is (or holds) JSON.
  const DebugStorageEntry({required this.key, required this.value, this.note});

  /// Storage key.
  final String key;

  /// Stored value.
  final Object? value;

  /// Extra line under the key, e.g. an expiry time.
  final String? note;
}

/// A section of the Storage tab: secure storage, shared preferences, a cache…
///
/// Implement it, or use [DebugStorage.new] with callbacks. Leave [delete] or
/// [clear] out to make the section read-only.
class DebugStorage {
  /// A storage section backed by callbacks.
  const DebugStorage({required this.name, required this.read, this.delete, this.clear});

  /// Section title.
  final String name;

  /// Loads the current entries. Called each time the tab opens or refreshes.
  final Future<List<DebugStorageEntry>> Function() read;

  /// Removes one key. `null` hides the per-entry delete button.
  final Future<void> Function(String key)? delete;

  /// Removes everything. `null` hides the "Clear" button.
  final Future<void> Function()? clear;

  /// Convenience for a `Map<String, Object?>`-shaped store.
  factory DebugStorage.map({
    required String name,
    required Future<Map<String, Object?>> Function() read,
    Future<void> Function(String key)? delete,
    Future<void> Function()? clear,
  }) => DebugStorage(
    name: name,
    read: () async {
      final map = await read();
      final keys = map.keys.toList()..sort();
      return [for (final key in keys) DebugStorageEntry(key: key, value: map[key])];
    },
    delete: delete,
    clear: clear,
  );
}
