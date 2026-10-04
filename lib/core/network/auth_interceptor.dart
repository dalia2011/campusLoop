import 'package:dio/dio.dart';

import 'token_storage.dart';

/// Request option flag: set `extra: {skipAuth: true}` on calls that must NOT
/// carry a token (login, register, refresh).
const String skipAuthKey = 'skipAuth';

/// Marks a request that was already retried once, to avoid infinite loops.
const String _retriedKey = 'retried';

/// An interceptor is code Dio runs on every request/response. This one:
///  1. adds `Authorization: Bearer <access token>` to outgoing requests;
///  2. when the server answers 401 (access token expired), uses the refresh
///     token to get a new pair, then repeats the original request once;
///  3. if refreshing fails, clears the tokens and calls [onSessionExpired]
///     so the app can show "Please sign in again to continue."
///
/// It extends [QueuedInterceptor] so that when several requests fail with 401
/// at the same moment, they are handled one at a time (one refresh, not many).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.dio,
    required this.refreshDio,
    required this.tokenStorage,
    this.onSessionExpired,
  });

  /// The main client, used to repeat the failed request.
  final Dio dio;

  /// A separate, interceptor-free client used ONLY for /auth/refresh, so the
  /// refresh call can never trigger this interceptor again.
  final Dio refreshDio;

  final TokenStorage tokenStorage;
  final void Function()? onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true) {
      final token = await tokenStorage.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final canRetry =
        request.extra[skipAuthKey] != true && request.extra[_retriedKey] != true;

    if (!isUnauthorized || !canRetry) {
      return handler.next(err);
    }

    // Which token did the failed request carry?
    final sentToken =
        (request.headers['Authorization'] as String?)?.replaceFirst('Bearer ', '');
    final currentToken = await tokenStorage.readAccessToken();

    // If another queued request already refreshed the tokens while we were
    // waiting, the stored token is newer than the one we sent: just retry.
    // Otherwise refresh first.
    if (currentToken == null || currentToken == sentToken) {
      final refreshed = await _refreshTokens();
      if (!refreshed) {
        await tokenStorage.clear();
        onSessionExpired?.call();
        return handler.next(err); // surfaces as a 401 -> "session expired"
      }
    }

    try {
      final retry = await dio.fetch<dynamic>(
        request.copyWith(extra: {...request.extra, _retriedKey: true}),
      );
      handler.resolve(retry);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Returns true if new tokens were obtained and saved.
  Future<bool> _refreshTokens() async {
    final refreshToken = await tokenStorage.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      // ASSUMPTION: the spec lists POST /v1/auth/refresh but not its body.
      // We send {"refreshToken": ...} and expect {"accessToken", "refreshToken"}
      // back (refresh tokens are rotated). Confirm with the backend owner.
      final response = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data!;
      await tokenStorage.save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } on DioException {
      return false;
    }
  }
}
