import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'token_storage.dart';

/// The single entry point for talking to the CampusLoop backend.
///
/// Feature code (auth, events, ...) never uses Dio directly. It calls
/// `apiClient.get(...)`, `post(...)` etc. and only has to handle
/// [ApiException]. That keeps networking rules in one place.
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    void Function()? onSessionExpired,
    String? baseUrl,
    Dio? dio, // Injectable so tests can plug in a fake HTTP adapter.
  }) : _dio = dio ?? Dio() {
    final options = BaseOptions(
      baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Accept': 'application/json'},
    );
    _dio.options = options;

    // Separate client for token refresh (see AuthInterceptor).
    final refreshDio = Dio(options);
    if (dio != null) {
      refreshDio.httpClientAdapter = dio.httpClientAdapter;
    }

    _dio.interceptors.add(
      AuthInterceptor(
        dio: _dio,
        refreshDio: refreshDio,
        tokenStorage: tokenStorage,
        onSessionExpired: onSessionExpired,
      ),
    );
  }

  final Dio _dio;
  static const _uuid = Uuid();

  /// Creates a new random key for the `Idempotency-Key` header.
  ///
  /// Create ONE key per user action (e.g. one tap on "Confirm registration")
  /// and reuse it if you retry that same action. The server then knows a
  /// repeated request is the same registration, not a second one.
  static String newIdempotencyKey() => _uuid.v4();

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) =>
      _send<T>('GET', path, query: query, auth: auth);

  Future<T> post<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    bool auth = true,
  }) =>
      _send<T>('POST', path,
          body: body, idempotencyKey: idempotencyKey, auth: auth);

  Future<T> put<T>(String path, {Object? body}) =>
      _send<T>('PUT', path, body: body);

  Future<T> patch<T>(String path, {Object? body}) =>
      _send<T>('PATCH', path, body: body);

  Future<T> delete<T>(String path) => _send<T>('DELETE', path);

  Future<T> _send<T>(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    String? idempotencyKey,
    bool auth = true,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            'Idempotency-Key': ?idempotencyKey, // only added when non-null
          },
          extra: {skipAuthKey: !auth},
        ),
      );
      // 204 No Content responses have no body, so `data` may be null.
      return response.data as T;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
