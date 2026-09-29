import 'dart:convert';

/// One HTTP request as recorded by [LogibbleInterceptor].
///
/// Entries are immutable; the log replaces an entry with [copyWith] when its
/// response (or error) arrives.
class NetworkEntry {
  /// Creates an entry. Usually only the interceptor does this.
  const NetworkEntry({
    required this.id,
    required this.method,
    required this.uri,
    required this.startedAt,
    this.requestHeaders = const {},
    this.requestBody,
    this.statusCode,
    this.responseHeaders = const {},
    this.responseBody,
    this.error,
    this.duration,
    this.fromCache = false,
  });

  /// Unique within one [Logibble].
  final int id;

  /// HTTP method, e.g. `GET`.
  final String method;

  /// Full request URL, including query parameters.
  final Uri uri;

  /// When the request was sent.
  final DateTime startedAt;

  /// Headers as they were when the request left (after every interceptor).
  final Map<String, Object?> requestHeaders;

  /// Request payload, as passed to Dio.
  final Object? requestBody;

  /// `null` until a response arrives, and for network errors without one.
  final int? statusCode;

  /// Response headers.
  final Map<String, List<String>> responseHeaders;

  /// Decoded response payload.
  final Object? responseBody;

  /// Dio error type and message, when the request failed.
  final String? error;

  /// Time from send to response or error.
  final Duration? duration;

  /// Whether a caching interceptor answered this request.
  final bool fromCache;

  /// No response and no error yet.
  bool get isPending => statusCode == null && error == null;

  /// Finished with a status below 400.
  bool get isSuccess => error == null && statusCode != null && statusCode! < 400;

  /// Returns a copy with the given fields replaced.
  NetworkEntry copyWith({
    Map<String, Object?>? requestHeaders,
    Object? requestBody,
    int? statusCode,
    Map<String, List<String>>? responseHeaders,
    Object? responseBody,
    String? error,
    Duration? duration,
    bool? fromCache,
  }) => NetworkEntry(
    id: id,
    method: method,
    uri: uri,
    startedAt: startedAt,
    requestHeaders: requestHeaders ?? this.requestHeaders,
    requestBody: requestBody ?? this.requestBody,
    statusCode: statusCode ?? this.statusCode,
    responseHeaders: responseHeaders ?? this.responseHeaders,
    responseBody: responseBody ?? this.responseBody,
    error: error ?? this.error,
    duration: duration ?? this.duration,
    fromCache: fromCache ?? this.fromCache,
  );

  /// Reproduces the request in a terminal.
  String toCurl() {
    final buffer = StringBuffer("curl -X $method '${_shellEscape(uri.toString())}'");
    requestHeaders.forEach((key, value) => buffer.write(" \\\n  -H '${_shellEscape('$key: $value')}'"));
    if (requestBody != null) {
      buffer.write(" \\\n  --data '${_shellEscape(prettyBody(requestBody, indent: false))}'");
    }
    return buffer.toString();
  }

  static String _shellEscape(String text) => text.replaceAll("'", r"'\''");
}

/// JSON-like values pretty-printed; strings that hold JSON are decoded first;
/// anything else via `toString()`.
String prettyBody(Object? body, {bool indent = true}) {
  if (body == null) return '';
  if (body is String) {
    final trimmed = body.trimLeft();
    if (!indent || !(trimmed.startsWith('{') || trimmed.startsWith('['))) return body;
    try {
      return prettyBody(jsonDecode(body));
    } catch (_) {
      return body;
    }
  }
  const pretty = JsonEncoder.withIndent('  ', _fallback);
  const compact = JsonEncoder(_fallback);
  try {
    return (indent ? pretty : compact).convert(body);
  } catch (_) {
    return body.toString();
  }
}

Object? _fallback(Object? value) => value.toString();
