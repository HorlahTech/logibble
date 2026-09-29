import 'package:dio/dio.dart';

import 'logibble.dart';

/// Records every request/response into a [Logibble].
///
/// Headers are captured when the request *finishes*, so they include whatever
/// later interceptors (e.g. auth) added. Put this interceptor before your auth
/// interceptor to see a 401 before auth recovers from it, and add it to the
/// Dio instance that performs the refresh/retry too.
///
/// ```dart
/// dio.interceptors.add(LogibbleInterceptor()); // records into Logibble.instance
/// ```
class LogibbleInterceptor extends Interceptor {
  /// Records into [logibble], or [Logibble.instance] when omitted.
  LogibbleInterceptor({Logibble? logibble, this.isFromCache = defaultIsFromCache})
    : logibble = logibble ?? Logibble.instance;

  /// Where entries go.
  final Logibble logibble;

  /// Decides whether a response came from a cache (shown as a "cache" tag).
  final bool Function(Response<dynamic> response) isFromCache;

  /// Looks for `response.extra['from_cache'] == true`.
  static bool defaultIsFromCache(Response<dynamic> response) => response.extra['from_cache'] == true;

  static const _idKey = 'logibble_id';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (logibble.enabled) options.extra[_idKey] = logibble.start(options);
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _finish(
      response.requestOptions,
      statusCode: response.statusCode,
      headers: response.headers.map,
      body: response.data,
      fromCache: isFromCache(response),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _finish(
      err.requestOptions,
      statusCode: err.response?.statusCode,
      headers: err.response?.headers.map ?? const {},
      body: err.response?.data,
      error: '${err.type.name}${err.message == null ? '' : ': ${err.message}'}',
    );
    handler.next(err);
  }

  void _finish(
    RequestOptions options, {
    int? statusCode,
    required Map<String, List<String>> headers,
    Object? body,
    String? error,
    bool fromCache = false,
  }) {
    if (!logibble.enabled) return;
    // A cache interceptor placed earlier may resolve before our onRequest ran.
    final id = options.extra[_idKey] as int? ?? logibble.start(options);
    logibble.finish(
      id,
      (entry) => entry.copyWith(
        requestHeaders: logibble.redact(Map.of(options.headers)),
        requestBody: options.data,
        statusCode: statusCode,
        responseHeaders: {
          for (final MapEntry(:key, :value) in logibble.redact(headers).entries)
            key: value is List<String> ? value : ['$value'],
        },
        responseBody: body,
        error: error,
        fromCache: fromCache,
        duration: DateTime.now().difference(entry.startedAt),
      ),
    );
  }
}
