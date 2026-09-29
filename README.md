# logibble

A draggable bug button that floats over your Flutter app in debug builds. Tap it to see every
[Dio](https://pub.dev/packages/dio) request and your local storage, without leaving the app.

- **Network tab:** filterable list with status badges, timings and cache hits. Tap a request to see its
  full request/response headers and pretty-printed JSON bodies. **Copy as cURL** in one tap.
- **Storage tab:** secure storage, shared preferences, in-memory caches… Plug in any store in a few lines,
  then view, copy, delete or clear its entries.
- **Status at a glance:** the bubble shows an amber dot while a request is in flight and a red dot when
  the latest one failed.
- **Works with any router:** `MaterialApp`, `MaterialApp.router`, go_router, auto_route.
- **Safe by default:** `enabled` defaults to `kDebugMode`. In release builds nothing is recorded and
  the overlay renders only your app. Sensitive headers can be redacted.
- **No wiring across layers:** the interceptor lives in your network code and the overlay at your app
  root. They share `Logibble.instance`, so neither needs a reference to the other.
- **No state-management lock-in:** it's a plain `ChangeNotifier`, and its only dependency is `dio`.
  Prefer DI? Pass your own instance.

## Install

```sh
flutter pub add logibble
```

## Usage

Two lines, in two different places. They don't need to know about each other.

**Where you build Dio** (your API client, network module, DI setup…):

```dart
import 'package:logibble/logibble.dart';

final dio = Dio()..interceptors.add(LogibbleInterceptor());
```

**At the app root:**

```dart
MaterialApp(
  builder: (context, child) => LogibbleOverlay(child: child!),
  home: const HomePage(),
);
```

That's it. Run the app in debug mode and tap the bug. Both lines use the shared `Logibble.instance`, so
requests recorded by the network layer show up in the overlay with no wiring between them.

### Interceptor order

The interceptor reads request headers when the request **finishes**, so headers added by later
interceptors (auth tokens, for example) still show up. Recommended order:

```dart
dio.interceptors.addAll([
  cacheInterceptor,        // cache hits still get logged (see below)
  LogibbleInterceptor(),   // before auth: you'll see the 401 *and* the retry
  authInterceptor,
]);
```

If your auth interceptor refreshes tokens with a second Dio instance, add a `LogibbleInterceptor()` to
that one too.

**Cache hits** are tagged `cache` when `response.extra['from_cache'] == true`. You can change the check:

```dart
LogibbleInterceptor(isFromCache: (r) => r.extra['cached'] == true)
```

### Storage

Register storage sections from wherever that storage code lives, at any time before the inspector opens:

```dart
// e.g. in your storage module
Logibble.instance.storage.addAll([
  // flutter_secure_storage
  DebugStorage.map(
    name: 'Secure storage',
    read: () => secureStorage.readAll(),
    delete: (key) => secureStorage.delete(key: key),
    clear: () => secureStorage.deleteAll(),
  ),
  // shared_preferences
  DebugStorage.map(
    name: 'Preferences',
    read: () async => {for (final k in prefs.getKeys()) k: prefs.get(k)},
    delete: (key) => prefs.remove(key),
    clear: () => prefs.clear(),
  ),
  // Anything else: build the entries yourself. Leave out delete/clear for a read-only section.
  DebugStorage(
    name: 'API cache',
    read: () async => [
      for (final e in apiCache.entries)
        DebugStorageEntry(key: e.key, value: e.value, note: 'expires ${e.expiresAt}'),
    ],
    clear: () async => apiCache.clear(),
  ),
]);
```

Values that are JSON, or strings holding JSON, are pretty-printed.

### Options

All of these are on `Logibble.instance`, and on your own `Logibble(...)` if you create one.

| Option | Default | |
|---|---|---|
| `enabled` | `kDebugMode` | Master switch. When false, nothing is recorded and no bubble is shown. Set it before `runApp`. |
| `storage` | `[]` | Storage tab sections. The tab is hidden when empty. |
| `redactHeaders` | `{}` | Header names (case-insensitive) shown as `••••`, e.g. `Logibble.instance.redactHeaders.add('authorization')`. |
| `maxEntries` | `200` | Oldest requests are dropped past this. Constructor only. |

`LogibbleOverlay` takes an optional `navigatorKey`. Without one, it finds the first `Navigator`
below it, which is your app's root navigator. You can also open the inspector yourself, for example
from a hidden settings entry:

```dart
Navigator.of(context).push(MaterialPageRoute(builder: (_) => LogibbleInspectorPage()));
```

### Using dependency injection instead

If you'd rather not use a global (Riverpod, get_it, or separate logs per test), create your own
instance and pass it to both sides:

```dart
final logibble = Logibble(redactHeaders: {'authorization'});

dio.interceptors.add(logibble.interceptor);
LogibbleOverlay(logibble: logibble, child: child!);
```

With Riverpod, for example:

```dart
final logibbleProvider = Provider((ref) => Logibble());

// network layer
dio.interceptors.add(ref.read(logibbleProvider).interceptor);

// app root
LogibbleOverlay(logibble: ref.read(logibbleProvider), child: child!);
```

### Testing

```dart
await tester.tap(find.byKey(LogibbleOverlay.buttonKey));
```

## Example

See [`example/lib/main.dart`](example/lib/main.dart). To run it:

```sh
cd example && flutter create . && flutter run
```

## License

MIT
