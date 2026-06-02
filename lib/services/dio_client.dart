import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'token_service.dart';

/// Centralized Dio client with auth + logging interceptors.
/// Call [DioClient.instance] after [TokenService.getInstance()] resolves.
class DioClient {
  static const String _baseUrl = 'https://bsm-backend-6e0m.onrender.com/api';

  /// Maximum number of automatic retries for transient network errors.
  /// Delays follow exponential back-off: 2 s → 4 s → 8 s.
  static const int _maxRetries = 3;

  static Dio? _dio;

  /// Global handler invoked exactly once per 401 burst.
  /// Wired up from the app layer (e.g. `main.dart`) to perform logout + redirect.
  static Future<void> Function()? onUnauthorized;
  static bool _handlingUnauthorized = false;

  // Prevent instantiation; consumers must call [build].
  DioClient._();

  /// Returns (or lazily creates) the shared Dio instance.
  /// [tokenService] is required the first time so interceptors can be wired up.
  static Dio build(TokenService tokenService) {
    if (_dio != null) return _dio!;

    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // 1️⃣ Auth interceptor — inject JWT on every request
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokenService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          final status = error.response?.statusCode;
          if (status == 401 && !_handlingUnauthorized) {
            _handlingUnauthorized = true;
            // Best-effort: trigger a global logout/redirect.
            // We intentionally do not swallow the error.
            () async {
              try {
                await onUnauthorized?.call();
              } catch (_) {
                // Never allow the handler to crash networking.
              } finally {
                _handlingUnauthorized = false;
              }
            }();
          }
          return handler.next(error);
        },
      ),
    );

    // 2️⃣ Retry interceptor — exponential back-off for transient failures.
    // Retries up to [_maxRetries] times on timeout / connectivity errors.
    // 4xx/5xx responses are intentionally NOT retried (business logic errors).
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, handler) async {
          final isRetryable =
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.connectionError;

          if (!isRetryable) {
            return handler.next(error);
          }

          final attempt =
              (error.requestOptions.extra['_retryCount'] as int?) ?? 0;

          if (attempt >= _maxRetries) {
            // All retries exhausted — propagate the original error.
            return handler.next(error);
          }

          const delays = [2, 4, 8]; // seconds
          final waitSeconds = delays[attempt];

          _log(
            '↺ Retry ${attempt + 1}/$_maxRetries after ${waitSeconds}s '
            '(${error.type}) ${error.requestOptions.method} '
            '${error.requestOptions.uri}',
          );

          await Future<void>.delayed(Duration(seconds: waitSeconds));

          // Stamp the incremented count so the next retry-interception
          // knows which attempt this is.
          error.requestOptions.extra['_retryCount'] = attempt + 1;

          try {
            // Re-run through the full interceptor chain (auth header
            // will be re-injected by interceptor 1️⃣ above).
            final response = await _dio!.fetch<dynamic>(error.requestOptions);
            return handler.resolve(response);
          } on DioException catch (e) {
            return handler.next(e);
          }
        },
      ),
    );

    // 3️⃣ Debug-only logger interceptor (redacts auth tokens).
    // Avoids leaking secrets and reduces overhead in release builds.
    if (!kReleaseMode) {
      _dio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final safeHeaders = _redactHeaders(options.headers);
            _log(
              '→ ${options.method} ${options.uri}\n'
              'headers=$safeHeaders\n'
              'query=${options.queryParameters}\n'
              'data=${_safeToString(options.data)}',
            );
            handler.next(options);
          },
          onResponse: (response, handler) {
            _log(
              '← ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}\n'
              'data=${_safeToString(response.data)}',
            );
            handler.next(response);
          },
          onError: (error, handler) {
            final ro = error.requestOptions;
            final status = error.response?.statusCode;
            _log(
              '⨯ ${status ?? '-'} ${ro.method} ${ro.uri}\n'
              'type=${error.type} message=${error.message}\n'
              'data=${_safeToString(error.response?.data)}',
            );
            handler.next(error);
          },
        ),
      );
    }

    return _dio!;
  }

  /// Resets the cached instance (e.g., after logout so a fresh one is built).
  static void reset() => _dio = null;

  static void _log(String message) {
    // ignore: avoid_print
    print('[DioClient] $message');
  }

  static Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    final redacted = <String, dynamic>{};
    headers.forEach((key, value) {
      final k = key.toString().toLowerCase();
      if (k == 'authorization' || k == 'cookie' || k == 'set-cookie') {
        redacted[key.toString()] = '<redacted>';
      } else {
        redacted[key.toString()] = value;
      }
    });
    return redacted;
  }

  static String _safeToString(Object? value, {int max = 2000}) {
    if (value == null) return 'null';
    final s = value.toString();
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…(${s.length} chars)';
  }
}
