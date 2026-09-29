/// A draggable in-app debug bubble: inspect Dio network traffic and local
/// storage without leaving the app.
///
/// ```dart
/// // Wherever you build Dio:
/// dio.interceptors.add(LogibbleInterceptor());
///
/// // At the app root:
/// MaterialApp(
///   builder: (context, child) => LogibbleOverlay(child: child!),
/// );
/// ```
library;

export 'src/logibble.dart';
export 'src/debug_storage.dart';
export 'src/network_entry.dart';
export 'src/network_interceptor.dart';
export 'src/ui/logibble_overlay.dart';
export 'src/ui/inspector_page.dart' show LogibbleInspectorPage;
