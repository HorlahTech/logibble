import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'debug_storage.dart';
import 'network_entry.dart';
import 'network_interceptor.dart';

/// Holds everything the bubble shows: the network log and the storage
/// sections.
///
/// Most apps use the shared [Logibble.instance]: [LogibbleInterceptor] and
/// [LogibbleOverlay] fall back to it, so your network layer and `main.dart`
/// never need a reference to each other. Create your own instance only for
/// dependency injection or tests.
class Logibble extends ChangeNotifier {
  /// Creates a separate log. Prefer [Logibble.instance] unless you inject it.
  ///
  /// With [enabled] false (the default in release builds) nothing is recorded
  /// and [LogibbleOverlay] renders only its child.
  Logibble({
    this.enabled = kDebugMode,
    this.maxEntries = 200,
    List<DebugStorage> storage = const [],
    Set<String> redactHeaders = const {},
  }) : storage = List.of(storage),
       redactHeaders = Set.of(redactHeaders);

  /// The shared log used whenever no [Logibble] is passed explicitly.
  ///
  /// Configure it from wherever the relevant code lives:
  ///
  /// ```dart
  /// Logibble.instance
  ///   ..redactHeaders.add('authorization')
  ///   ..storage.add(DebugStorage.map(name: 'Prefs', read: readPrefs));
  /// ```
  static final instance = Logibble();

  /// Master switch. Defaults to [kDebugMode]; set it before `runApp` to change
  /// it (e.g. to inspect a profile build).
  bool enabled;

  /// Oldest entries are dropped past this many.
  final int maxEntries;

  /// Sections of the Storage tab, in order. The tab is hidden while this is
  /// empty. Add to it from anywhere, e.g. next to your storage code.
  final List<DebugStorage> storage;

  /// Header names (case-insensitive) whose values are shown as `••••`,
  /// e.g. `{'authorization', 'cookie'}`. Add to it from anywhere.
  final Set<String> redactHeaders;

  List<NetworkEntry> _entries = const [];
  var _nextId = 0;

  /// Recorded requests, newest first.
  List<NetworkEntry> get entries => _entries;

  /// A new interceptor that records into this bubble. Add it to every Dio
  /// instance you want to inspect; see [LogibbleInterceptor] for ordering.
  LogibbleInterceptor get interceptor => LogibbleInterceptor(logibble: this);

  /// Records the start of a request and returns its entry id.
  int start(RequestOptions options) {
    final entry = NetworkEntry(
      id: _nextId++,
      method: options.method,
      uri: options.uri,
      startedAt: DateTime.now(),
    );
    _entries = [entry, ..._entries.take(maxEntries - 1)];
    notifyListeners();
    return entry.id;
  }

  /// Replaces entry [id] with `update(entry)`. No-op if it was dropped.
  void finish(int id, NetworkEntry Function(NetworkEntry entry) update) {
    _entries = [for (final entry in _entries) entry.id == id ? update(entry) : entry];
    notifyListeners();
  }

  /// Looks an entry up by id.
  NetworkEntry? entry(int id) => _entries.where((entry) => entry.id == id).firstOrNull;

  /// Empties the network log.
  void clear() {
    _entries = const [];
    notifyListeners();
  }

  /// Applies [redactHeaders].
  Map<String, Object?> redact(Map<String, Object?> headers) {
    if (redactHeaders.isEmpty) return headers;
    final hidden = {for (final name in redactHeaders) name.toLowerCase()};
    return {
      for (final MapEntry(:key, :value) in headers.entries)
        key: hidden.contains(key.toLowerCase()) ? '••••' : value,
    };
  }
}
