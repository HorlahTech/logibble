# logibble

A small debug button for Flutter apps that use [Dio](https://pub.dev/packages/dio). It floats over your
app in debug builds. Tap it to see the requests your app made and what's in local storage.

In the network tab you can filter requests, see status codes and timings, open a request to read its
headers and body, and copy it as a cURL command. The storage tab shows whatever stores you register
(secure storage, shared preferences, a cache) and lets you delete entries.

The button gets an amber dot while a request is in flight, and a red one if the last request failed.

It's off in release builds: `enabled` defaults to `kDebugMode`.

## Install

```sh
flutter pub add logibble
```

## Setup

Add the interceptor wherever you create your Dio instance:

```dart
import 'package:logibble/logibble.dart';

final dio = Dio()..interceptors.add(LogibbleInterceptor());
```

Then wrap your app in `MaterialApp.builder`:

```dart
MaterialApp(
  builder: (context, child) => LogibbleOverlay(child: child!),
  home: const HomePage(),
);
```

Both use `Logibble.instance` by default, so your network code and your app widget don't need to share
anything. It works with `MaterialApp.router` too (go_router, auto_route).

## Interceptor order

Headers are read when the request completes, so anything added by interceptors after this one (like an
auth token) will still show up. I'd put it before your auth interceptor, so a 401 and the retry after a
token refresh both show up in the log:

```dart
dio.interceptors.addAll([
  cacheInterceptor,
  LogibbleInterceptor(),
  authInterceptor,
]);
```

If you refresh tokens with a separate Dio instance, add an interceptor to that one as well.

Requests answered from a cache are marked `cache` if `response.extra['from_cache'] == true`. If your
cache uses a different flag:

```dart
LogibbleInterceptor(isFromCache: (r) => r.extra['cached'] == true)
```

## Storage

logibble doesn't depend on any storage package. Register the stores you want to see, from wherever you
set them up:

```dart
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
  ),
  // or build the entries yourself
  DebugStorage(
    name: 'API cache',
    read: () async => [
      for (final e in apiCache.entries)
        DebugStorageEntry(key: e.key, value: e.value, note: 'expires ${e.expiresAt}'),
    ],
  ),
]);
```

Leave out `delete` or `clear` and those buttons won't appear. JSON values are formatted.

## Options

| | Default | |
|---|---|---|
| `enabled` | `kDebugMode` | When false nothing is recorded and the button isn't shown. Set it before `runApp`. |
| `storage` | `[]` | Storage sections. The tab is hidden if this is empty. |
| `redactHeaders` | `{}` | Header names to hide, e.g. `Logibble.instance.redactHeaders.add('authorization')`. |
| `maxEntries` | `200` | How many requests to keep. Constructor only. |

`LogibbleOverlay` finds your root navigator on its own. You can pass `navigatorKey` if you want to be
explicit.

To open the inspector from somewhere else, like a settings screen:

```dart
Navigator.of(context).push(MaterialPageRoute(builder: (_) => LogibbleInspectorPage()));
```

## Without the global instance

If you use dependency injection, or want a separate log in tests, create your own and pass it to both:

```dart
final logibble = Logibble();

dio.interceptors.add(logibble.interceptor);
LogibbleOverlay(logibble: logibble, child: child!);
```

## Testing

The button has a key you can tap in widget tests:

```dart
await tester.tap(find.byKey(LogibbleOverlay.buttonKey));
```

## Example

There's a small app in [`example/`](example/lib/main.dart):

```sh
cd example && flutter create . && flutter run
```

## License

MIT
