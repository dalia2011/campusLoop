import 'package:dio/dio.dart';

/// The categories of failure the UI cares about. Screens can `switch` on this
/// instead of looking at raw HTTP status codes.
enum ApiErrorType {
  network, // no connection / DNS failure -> show the "You are offline" state
  timeout,
  validation, // 400
  unauthorized, // 401 -> session expired
  forbidden, // 403 role or ownership
  notFound, // 404
  conflict, // 409 e.g. EVENT_FULL
  rateLimited, // 429
  server, // 5xx
  unknown,
}

/// The ONE error type the rest of the app has to handle.
///
/// The backend spec says every error looks like:
///   {"error":{"code":"EVENT_FULL","message":"...","requestId":"..."}}
/// This class holds those fields plus the HTTP status and a [type].
class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    this.code,
    this.statusCode,
    this.requestId,
  });

  final ApiErrorType type;

  /// Human readable text. Safe to show to the user.
  final String message;

  /// Machine readable code from the server, e.g. "EVENT_FULL".
  final String? code;

  final int? statusCode;

  /// Handy to quote when reporting a bug; matches the server logs.
  final String? requestId;

  bool get isOffline =>
      type == ApiErrorType.network || type == ApiErrorType.timeout;

  /// Turns a low-level Dio failure into an [ApiException].
  factory ApiException.fromDioException(DioException e) {
    // No response at all: the request never reached the server (or timed out).
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          type: ApiErrorType.timeout,
          message: 'The request took too long. Please try again.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          type: ApiErrorType.network,
          message: 'You are offline.',
        );
      default:
        break;
    }

    final response = e.response;
    if (response == null) {
      return const ApiException(
        type: ApiErrorType.unknown,
        message: 'Something went wrong. Please try again.',
      );
    }

    // Try to read the spec's error envelope; be defensive about its shape.
    String? code;
    String? message;
    String? requestId;
    final body = response.data;
    if (body is Map && body['error'] is Map) {
      final error = body['error'] as Map;
      code = error['code'] as String?;
      message = error['message'] as String?;
      requestId = error['requestId'] as String?;
    }

    final status = response.statusCode;
    return ApiException(
      type: _typeForStatus(status),
      message: message ?? 'Something went wrong. Please try again.',
      code: code,
      statusCode: status,
      requestId: requestId,
    );
  }

  static ApiErrorType _typeForStatus(int? status) {
    switch (status) {
      case 400:
        return ApiErrorType.validation;
      case 401:
        return ApiErrorType.unauthorized;
      case 403:
        return ApiErrorType.forbidden;
      case 404:
        return ApiErrorType.notFound;
      case 409:
        return ApiErrorType.conflict;
      case 429:
        return ApiErrorType.rateLimited;
    }
    if (status != null && status >= 500) return ApiErrorType.server;
    return ApiErrorType.unknown;
  }

  @override
  String toString() => 'ApiException($type, $code, $statusCode): $message';
}
