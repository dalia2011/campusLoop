import 'models/user.dart';

/// Everything the app can ask the auth backend to do.
///
/// Screens and the controller only know this interface. [MockAuthRepository]
/// and [ApiAuthRepository] both implement it, so switching between fake and
/// real data never touches the UI.
///
/// Failures are thrown as `ApiException` (see core/network/api_exception.dart).
/// Implementations save/clear the tokens themselves.
abstract class AuthRepository {
  /// Creates a student account and signs it in.
  Future<User> register({
    required String name,
    required String email,
    required String password,
  });

  Future<User> login({required String email, required String password});

  /// Signs out. Must clear stored tokens even if the server call fails.
  Future<void> logout();

  /// Always completes normally for an unknown email, so the app never reveals
  /// which emails have accounts.
  Future<void> requestPasswordReset(String email);

  /// Called on app start. Returns the signed in user if a saved session is
  /// still valid, otherwise null.
  Future<User?> restoreSession();
}
