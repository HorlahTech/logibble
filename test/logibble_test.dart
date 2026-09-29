import 'dart:convert';
import 'dart:typed_data';

import 'package:logibble/logibble.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `/ok` → 200 JSON, `/missing` → 404, `/offline` → connection error.
class _Api implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _, Future<void>? _) async {
    if (options.path == '/offline') {
      throw DioException.connectionError(requestOptions: options, reason: 'no network');
    }
    return ResponseBody.fromString(
      jsonEncode({'path': options.path}),
      options.path == '/ok' ? 200 : 404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(Logibble logibble, {List<Interceptor> after = const []}) =>
    Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = _Api()
      ..interceptors.addAll([logibble.interceptor, ...after]);

void main() {
  test('records request and response, with headers added by later interceptors', () async {
    final logibble = Logibble(enabled: true);
    final dio = _dio(
      logibble,
      after: [
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.next(options..headers['Authorization'] = 'Bearer t'),
        ),
      ],
    );

    await dio.post<dynamic>('/ok', data: {'a': 1});

    final entry = logibble.entries.single;
    expect(entry.method, 'POST');
    expect(entry.statusCode, 200);
    expect(entry.isSuccess, isTrue);
    expect(entry.requestBody, {'a': 1});
    expect(entry.responseBody, {'path': '/ok'});
    expect(entry.requestHeaders['Authorization'], 'Bearer t');
    expect(entry.duration, isNotNull);
    expect(entry.toCurl(), contains("curl -X POST 'https://api.test/ok'"));
    expect(entry.toCurl(), contains(r"""--data '{"a":1}'"""));
  });

  test('records HTTP errors and network errors', () async {
    final logibble = Logibble(enabled: true);
    final dio = _dio(logibble);

    await expectLater(dio.get<dynamic>('/missing'), throwsA(isA<DioException>()));
    await expectLater(dio.get<dynamic>('/offline'), throwsA(isA<DioException>()));

    final [offline, missing] = logibble.entries;
    expect(missing.statusCode, 404);
    expect(missing.isSuccess, isFalse);
    expect(offline.statusCode, isNull);
    expect(offline.error, startsWith('connectionError'));
    expect(offline.isPending, isFalse);
  });

  test('redacts headers, caps the log, and records nothing when disabled', () async {
    final logibble = Logibble(enabled: true, maxEntries: 2, redactHeaders: {'Authorization'});
    final dio = _dio(logibble);
    for (var i = 0; i < 3; i++) {
      await dio.get<dynamic>('/ok', options: Options(headers: {'authorization': 'secret'}));
    }
    expect(logibble.entries, hasLength(2));
    expect(logibble.entries.first.requestHeaders['authorization'], '••••');

    final off = Logibble(enabled: false);
    await _dio(off).get<dynamic>('/ok');
    expect(off.entries, isEmpty);
  });

  test('prettyBody decodes JSON strings and leaves plain text alone', () {
    expect(prettyBody('{"a":1}'), '{\n  "a": 1\n}');
    expect(prettyBody('hello'), 'hello');
    expect(prettyBody(null), '');
  });

  testWidgets('the bubble opens the inspector, shows entries and storage', (tester) async {
    final store = {'token': '{"access":"abc"}', 'theme': 'dark'};
    final logibble = Logibble(
      enabled: true,
      storage: [
        DebugStorage.map(name: 'Prefs', read: () async => store, delete: (key) async => store.remove(key)),
      ],
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => LogibbleOverlay(logibble: logibble, child: child!),
        home: const Scaffold(body: Text('home')),
      ),
    );

    await tester.tap(find.byKey(LogibbleOverlay.buttonKey));
    await tester.pumpAndSettle();
    expect(find.text('No requests yet.'), findsOneWidget);
    expect(find.byKey(LogibbleOverlay.buttonKey), findsNothing); // hidden while open

    await tester.runAsync(() => _dio(logibble).get<dynamic>('/ok'));
    await tester.pumpAndSettle();
    expect(find.text('GET /ok'), findsOneWidget);

    await tester.tap(find.text('GET /ok'));
    await tester.pumpAndSettle();
    expect(find.text('Response body'), findsOneWidget);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Storage'));
    await tester.pumpAndSettle();
    expect(find.text('Prefs (2)'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete theme'));
    await tester.pumpAndSettle();
    expect(find.text('Prefs (1)'), findsOneWidget);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(LogibbleOverlay.buttonKey), findsOneWidget);
  });

  testWidgets('the network layer and the overlay share Logibble.instance by default', (tester) async {
    Logibble.instance.enabled = true;
    addTearDown(Logibble.instance.clear);
    // Configured far from the app root, as a network layer would.
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = _Api()
      ..interceptors.add(LogibbleInterceptor());

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => LogibbleOverlay(child: child!),
        home: const SizedBox(),
      ),
    );
    await tester.runAsync(() => dio.get<dynamic>('/ok'));
    await tester.tap(find.byKey(LogibbleOverlay.buttonKey));
    await tester.pumpAndSettle();
    expect(find.text('GET /ok'), findsOneWidget);
  });

  testWidgets('renders only the child when disabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => LogibbleOverlay(logibble: Logibble(enabled: false), child: child!),
        home: const SizedBox(),
      ),
    );
    expect(find.byKey(LogibbleOverlay.buttonKey), findsNothing);
  });
}
