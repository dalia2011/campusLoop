import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the access/refresh tokens are kept.
///
/// It is an interface (abstract class) so the network code does not care HOW
/// tokens are stored. The real app uses [SecureTokenStorage]; tests use
/// [MemoryTokenStorage].
abstract class TokenStorage {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> save({required String accessToken, required String refreshToken});

  /// Called on sign out / expired session ("sign out clears protected state").
  Future<void> clear();
}

/// Stores tokens in the platform's encrypted storage (Android Keystore /
/// iOS Keychain). Data survives an app restart, which the spec requires.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// Keeps tokens in memory only. Used by tests.
class MemoryTokenStorage implements TokenStorage {
  String? _access;
  String? _refresh;

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}
