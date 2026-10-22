import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../data/models/user.dart';

enum AuthStatus {
  /// App just started; still checking for a saved session.
  unknown,
  signedOut,
  signedIn,
}

/// Holds "who is signed in" for the whole app. Widgets listen to it and
/// rebuild when [status] changes (that is what [ChangeNotifier] is for).
///
/// Screens call [login] / [register]; each throws `ApiException` on failure so
/// the screen can show the message next to its own form.
class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  bool _sessionExpired = false;

  AuthStatus get status => _status;
  User? get user => _user;

  /// True when the user was signed out because the server rejected their
  /// session (not because they tapped Sign out).
  bool get sessionExpired => _sessionExpired;

  /// Run once at app start. If the saved session cannot be checked (offline,
  /// storage error, slow server), the user is sent to sign in rather than
  /// being stuck on the startup spinner.
  Future<void> restore() async {
    User? user;
    try {
      user = await _repository.restoreSession().timeout(
        const Duration(seconds: 8),
      );
    } catch (_) {
      user = null;
    }
    _setUser(user);
  }

  Future<void> login({required String email, required String password}) async {
    final user = await _repository.login(email: email, password: password);
    _setUser(user);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final user = await _repository.register(
      name: name,
      email: email,
      password: password,
    );
    _setUser(user);
  }

  Future<void> logout() async {
    await _repository.logout();
    _setUser(null);
  }

  Future<void> requestPasswordReset(String email) =>
      _repository.requestPasswordReset(email);

  /// Called by the network layer when a refresh fails (see main.dart). The
  /// tokens are already cleared there.
  void handleSessionExpired() {
    if (_status != AuthStatus.signedIn) return;
    _user = null;
    _status = AuthStatus.signedOut;
    _sessionExpired = true;
    notifyListeners();
  }

  void _setUser(User? user) {
    _user = user;
    _status = user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    _sessionExpired = false;
    notifyListeners();
  }
}
