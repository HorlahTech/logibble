import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logibble/logibble.dart';

/// Stand-in for SharedPreferences / flutter_secure_storage.
final prefs = <String, String>{
  'onboarding_done': 'true',
  'user': '{"id": 42, "name": "Ada", "roles": ["admin"]}',
};

// --- Storage module: registers itself with the shared inspector. ---
void registerPrefsWithLogibble() => Logibble.instance.storage.add(
  DebugStorage.map(
    name: 'Preferences',
    read: () async => prefs,
    delete: (key) async => prefs.remove(key),
    clear: () async => prefs.clear(),
  ),
);

// --- Network layer: knows nothing about the UI. ---
final dio = Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'))
  ..interceptors.addAll([
    LogibbleInterceptor(),
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.next(options..headers['Authorization'] = 'Bearer demo-token'),
    ),
  ]);

void main() {
  Logibble.instance.redactHeaders.add('authorization');
  registerPrefsWithLogibble();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'logibble example',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange),
      darkTheme: ThemeData(colorSchemeSeed: Colors.deepOrange, brightness: Brightness.dark),
      builder: (context, child) => LogibbleOverlay(child: child!),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _send(Future<Object?> Function() request) async {
    try {
      await request();
    } on DioException {
      // Shown in the inspector.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('logibble')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Fire some requests, then tap the bug.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => _send(() => dio.get<dynamic>('/todos/1')), child: const Text('GET 200')),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _send(() => dio.post<dynamic>('/posts', data: {'title': 'Hello', 'userId': 1})),
            child: const Text('POST 201'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _send(() => dio.get<dynamic>('/does-not-exist')),
            child: const Text('GET 404'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _send(() => dio.get<dynamic>('https://nope.invalid/')),
            child: const Text('Network error'),
          ),
        ],
      ),
    );
  }
}
