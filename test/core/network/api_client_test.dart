import 'dart:convert';
import 'dart:typed_data';

import 'package:campus_loop/core/network/api_client.dart';
import 'package:campus_loop/core/network/api_exception.dart';
import 'package:campus_loop/core/network/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake "server": instead of real HTTP, a function decides the reply.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonReply(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  test('adds the bearer token to requests', () async {
    final storage = MemoryTokenStorage();
    await storage.save(accessToken: 'A1', refreshToken: 'R1');
    final adapter = FakeAdapter((_) => jsonReply(200, {'ok': true}));
    final client = ApiClient(
      tokenStorage: storage,
      baseUrl: 'http://test/v1',
      dio: Dio()..httpClientAdapter = adapter,
    );

    await client.get<Map<String, dynamic>>('/events');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer A1');
  });

  test('auth: false does not send a token', () async {
    final storage = MemoryTokenStorage();
    await storage.save(accessToken: 'A1', refreshToken: 'R1');
    final adapter = FakeAdapter((_) => jsonReply(200, {}));
    final client = ApiClient(
      tokenStorage: storage,
      baseUrl: 'http://test/v1',
      dio: Dio()..httpClientAdapter = adapter,
    );

    await client.post<Map<String, dynamic>>('/auth/login', auth: false);

    expect(adapter.requests.single.headers.containsKey('Authorization'), false);
  });

  test('sends the Idempotency-Key header', () async {
    final adapter = FakeAdapter((_) => jsonReply(201, {}));
    final client = ApiClient(
      tokenStorage: MemoryTokenStorage(),
      baseUrl: 'http://test/v1',
      dio: Dio()..httpClientAdapter = adapter,
    );

    await client.post<Map<String, dynamic>>(
      '/events/evt_104/registrations',
      idempotencyKey: 'key-123',
    );

    expect(adapter.requests.single.headers['Idempotency-Key'], 'key-123');
  });

  test('maps the error envelope to ApiException', () async {
    final adapter = FakeAdapter((_) => jsonReply(409, {
          'error': {
            'code': 'EVENT_FULL',
            'message': 'That spot was just taken.',
            'requestId': 'req_1',
          },
        }));
    final client = ApiClient(
      tokenStorage: MemoryTokenStorage(),
      baseUrl: 'http://test/v1',
      dio: Dio()..httpClientAdapter = adapter,
    );

    await expectLater(
      client.post<Map<String, dynamic>>('/events/evt_1/registrations'),
      throwsA(isA<ApiException>()
          .having((e) => e.type, 'type', ApiErrorType.conflict)
          .having((e) => e.code, 'code', 'EVENT_FULL')
          .having((e) => e.requestId, 'requestId', 'req_1')),
    );
  });

  test('refreshes the token on 401 and retries once', () async {
    final storage = MemoryTokenStorage();
    await storage.save(accessToken: 'OLD', refreshToken: 'R1');
    final adapter = FakeAdapter((o) {
      if (o.path.endsWith('/auth/refresh')) {
        return jsonReply(200, {'accessToken': 'NEW', 'refreshToken': 'R2'});
      }
      if (o.headers['Authorization'] == 'Bearer NEW') {
        return jsonReply(200, {'ok': true});
      }
      return jsonReply(401, {
        'error': {'code': 'UNAUTHENTICATED', 'message': 'Expired'},
      });
    });
    final client = ApiClient(
      tokenStorage: storage,
      baseUrl: 'http://test/v1',
      dio: Dio()..httpClientAdapter = adapter,
    );

    final result = await client.get<Map<String, dynamic>>('/me/events');

    expect(result['ok'], true);
    expect(await storage.readAccessToken(), 'NEW');
    expect(await storage.readRefreshToken(), 'R2');
  });

  test('clears tokens and signals expiry when refresh fails', () async {
    final storage = MemoryTokenStorage();
    await storage.save(accessToken: 'OLD', refreshToken: 'R1');
    var expired = false;
    final adapter = FakeAdapter((_) => jsonReply(401, {
          'error': {'code': 'UNAUTHENTICATED', 'message': 'Expired'},
        }));
    final client = ApiClient(
      tokenStorage: storage,
      baseUrl: 'http://test/v1',
      onSessionExpired: () => expired = true,
      dio: Dio()..httpClientAdapter = adapter,
    );

    await expectLater(
      client.get<Map<String, dynamic>>('/me/events'),
      throwsA(isA<ApiException>()
          .having((e) => e.type, 'type', ApiErrorType.unauthorized)),
    );
    expect(expired, true);
    expect(await storage.readAccessToken(), isNull);
  });
}
