import 'dart:convert';

import '../../../core/network/api_exception.dart';
import '../../../core/network/token_storage.dart';
import 'auth_repository.dart';
import 'models/user.dart';

/// Fake backend for development: no network, a short delay, fixed accounts.
///
/// Demo accounts (password for both: [demoPassword]):
///   student@campus.edu    -> student
///   organizer@campus.edu  -> organizer
/// Accounts created with register() live in memory only, so they disappear
/// when the app is fully closed (the signed in session itself is kept).
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({
    required TokenStorage tokenStorage,
    this.latency = const Duration(milliseconds: 600),
  }) : _tokens = tokenStorage;

  static const demoPassword = 'campusloop123';

  final TokenStorage _tokens;
  final Duration latency;

  final Map<String, User> _users = {
    'student@campus.edu': const User(
      id: 'usr_1',
      email: 'student@campus.edu',
      displayName: 'Alex Rivera',
      role: UserRole.student,
    ),
    'organizer@campus.edu': const User(
      id: 'usr_2',
      email: 'organizer@campus.edu',
      displayName: 'Sam Lee',
      role: UserRole.organizer,
    ),
  };
  final Map<String, String> _passwords = {
    'student@campus.edu': demoPassword,
    'organizer@campus.edu': demoPassword,
  };

  static String _normalize(String email) => email.trim().toLowerCase();

  // With zero latency (tests) skip the timer completely, so tests can await
  // repository calls without having to advance the fake clock.
  Future<void> _delay() => latency == Duration.zero
      ? Future<void>.value()
      : Future<void>.delayed(latency);

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _delay();
    final key = _normalize(email);
    if (password.length < 12) {
      throw const ApiException(
        type: ApiErrorType.validation,
        code: 'VALIDATION_FAILED',
        statusCode: 400,
        message: 'Use 12 or more characters.',
      );
    }
    if (_users.containsKey(key)) {
      throw const ApiException(
        type: ApiErrorType.conflict,
        code: 'EMAIL_TAKEN',
        statusCode: 409,
        message: 'An account with this email already exists.',
      );
    }
    final user = User(
      id: 'usr_${_users.length + 1}',
      email: key,
      displayName: name.trim(),
      role: UserRole.student,
    );
    _users[key] = user;
    _passwords[key] = password;
    await _saveTokens(user);
    return user;
  }

  @override
  Future<User> login({required String email, required String password}) async {
    await _delay();
    final key = _normalize(email);
    final user = _users[key];
    // Same message for "no such email" and "wrong password" on purpose.
    if (user == null || _passwords[key] != password) {
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        code: 'INVALID_CREDENTIALS',
        statusCode: 401,
        message: 'Incorrect email or password.',
      );
    }
    await _saveTokens(user);
    return user;
  }

  @override
  Future<void> logout() async {
    await _delay();
    await _tokens.clear();
  }

  @override
  Future<void> requestPasswordReset(String email) => _delay();

  @override
  Future<User?> restoreSession() async {
    final token = await _tokens.readAccessToken();
    if (token == null || !token.startsWith(_tokenPrefix)) return null;
    try {
      final json = utf8.decode(
        base64Url.decode(token.substring(_tokenPrefix.length)),
      );
      return User.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      await _tokens.clear(); // Garbage token: treat as signed out.
      return null;
    }
  }

  // The fake access token simply contains the user, so the session can be
  // restored after an app restart without remembering anything in memory.
  static const _tokenPrefix = 'mock.';

  Future<void> _saveTokens(User user) {
    final payload = base64Url.encode(utf8.encode(jsonEncode(user.toJson())));
    return _tokens.save(
      accessToken: '$_tokenPrefix$payload',
      refreshToken: 'mock-refresh-${user.id}',
    );
  }
}
