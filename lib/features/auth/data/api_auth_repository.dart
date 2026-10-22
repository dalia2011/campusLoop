import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/token_storage.dart';
import 'auth_repository.dart';
import 'models/auth_session.dart';
import 'models/user.dart';

/// Talks to the real backend through [ApiClient].
///
/// Written from the spec's endpoint list. The request and response bodies are
/// ASSUMPTIONS (the spec gives routes, not bodies), so check every `ASSUMPTION`
/// comment against the Swagger before switching USE_MOCK_API off.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  }) : _api = apiClient,
       _tokens = tokenStorage;

  final ApiClient _api;
  final TokenStorage _tokens;

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    // ASSUMPTION: body {displayName, email, password}; 201 returns a session.
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      auth: false,
      body: {
        'displayName': name.trim(),
        'email': email.trim(),
        'password': password,
      },
    );
    return _saveSession(AuthSession.fromJson(json));
  }

  @override
  Future<User> login({required String email, required String password}) async {
    // ASSUMPTION: body {email, password}; 200 returns a session.
    final json = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      auth: false,
      body: {'email': email.trim(), 'password': password},
    );
    return _saveSession(AuthSession.fromJson(json));
  }

  @override
  Future<void> logout() async {
    try {
      // ASSUMPTION: body {refreshToken} so the server can revoke it.
      final refresh = await _tokens.readRefreshToken();
      await _api.post<dynamic>('/auth/logout', body: {'refreshToken': refresh});
    } on ApiException {
      // Ignore: signing out locally must always work, even when offline.
    } finally {
      await _tokens.clear();
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    // TODO: the spec does not list a reset route. Replace the path once the
    // Swagger names it.
    await _api.post<dynamic>(
      '/auth/password-reset',
      auth: false,
      body: {'email': email.trim()},
    );
  }

  @override
  Future<User?> restoreSession() async {
    if (await _tokens.readAccessToken() == null) return null;
    try {
      // TODO: the spec has no "current user" route. Replace '/me' with the
      // real one from the Swagger. A 401 triggers the automatic token refresh.
      final json = await _api.get<Map<String, dynamic>>('/me');
      return User.fromJson(json);
    } on ApiException catch (e) {
      // Offline at startup: keep the tokens, but we cannot show the user yet.
      if (e.isOffline) rethrow;
      return null;
    }
  }

  Future<User> _saveSession(AuthSession session) async {
    await _tokens.save(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    return session.user;
  }
}
