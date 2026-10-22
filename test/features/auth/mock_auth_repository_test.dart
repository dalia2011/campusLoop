import 'package:campus_loop/core/network/api_exception.dart';
import 'package:campus_loop/core/network/token_storage.dart';
import 'package:campus_loop/features/auth/data/mock_auth_repository.dart';
import 'package:campus_loop/features/auth/data/models/user.dart';
import 'package:campus_loop/features/auth/state/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryTokenStorage storage;
  late MockAuthRepository repo;

  setUp(() {
    storage = MemoryTokenStorage();
    repo = MockAuthRepository(tokenStorage: storage, latency: Duration.zero);
  });

  const pass = MockAuthRepository.demoPassword;

  group('MockAuthRepository', () {
    test('logs in the demo student and saves tokens', () async {
      final user = await repo.login(
        email: 'student@campus.edu',
        password: pass,
      );
      expect(user.role, UserRole.student);
      expect(await storage.readAccessToken(), isNotNull);
      expect(await storage.readRefreshToken(), isNotNull);
    });

    test(
      'logs in the demo organizer, ignoring email case and spaces',
      () async {
        final user = await repo.login(
          email: ' Organizer@Campus.edu ',
          password: pass,
        );
        expect(user.role, UserRole.organizer);
      },
    );

    test('wrong password and unknown email give the same error', () async {
      for (final email in ['student@campus.edu', 'nobody@campus.edu']) {
        await expectLater(
          repo.login(email: email, password: 'not-the-password'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.type, 'type', ApiErrorType.unauthorized)
                .having(
                  (e) => e.message,
                  'message',
                  'Incorrect email or password.',
                ),
          ),
        );
      }
      expect(await storage.readAccessToken(), isNull);
    });

    test('register creates a student and signs in', () async {
      final user = await repo.register(
        name: 'Maya Chen',
        email: 'maya@campus.edu',
        password: 'a-long-password',
      );
      expect(user.displayName, 'Maya Chen');
      expect(user.role, UserRole.student);
      // The new account can log in afterwards.
      await repo.login(email: 'maya@campus.edu', password: 'a-long-password');
    });

    test('register rejects short passwords and taken emails', () async {
      await expectLater(
        repo.register(name: 'X', email: 'x@campus.edu', password: 'short'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.type,
            'type',
            ApiErrorType.validation,
          ),
        ),
      );
      await expectLater(
        repo.register(
          name: 'Dup',
          email: 'student@campus.edu',
          password: 'a-long-password',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.type,
            'type',
            ApiErrorType.conflict,
          ),
        ),
      );
    });

    test('restoreSession brings the user back after a restart', () async {
      await repo.login(email: 'organizer@campus.edu', password: pass);

      // A brand new repository sharing the same token storage = app restart.
      final restarted = MockAuthRepository(
        tokenStorage: storage,
        latency: Duration.zero,
      );
      final user = await restarted.restoreSession();
      expect(user?.email, 'organizer@campus.edu');
      expect(user?.role, UserRole.organizer);
    });

    test('restoreSession is null without tokens', () async {
      expect(await repo.restoreSession(), isNull);
    });

    test('logout clears the tokens', () async {
      await repo.login(email: 'student@campus.edu', password: pass);
      await repo.logout();
      expect(await storage.readAccessToken(), isNull);
      expect(await repo.restoreSession(), isNull);
    });

    test('password reset completes for any email', () async {
      await repo.requestPasswordReset('student@campus.edu');
      await repo.requestPasswordReset('nobody@campus.edu');
    });
  });

  group('AuthController', () {
    test('starts unknown, then signedOut when nothing is saved', () async {
      final auth = AuthController(repo);
      expect(auth.status, AuthStatus.unknown);
      await auth.restore();
      expect(auth.status, AuthStatus.signedOut);
    });

    test('restore signs in from a saved session', () async {
      await repo.login(email: 'student@campus.edu', password: pass);
      final auth = AuthController(repo);
      await auth.restore();
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.user?.email, 'student@campus.edu');
    });

    test('login, logout and expiry update the status', () async {
      final auth = AuthController(repo);
      await auth.login(email: 'student@campus.edu', password: pass);
      expect(auth.status, AuthStatus.signedIn);

      auth.handleSessionExpired();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, true);

      await auth.login(email: 'student@campus.edu', password: pass);
      expect(auth.sessionExpired, false);

      await auth.logout();
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, false);
      expect(await storage.readAccessToken(), isNull);
    });

    test('a failed login leaves the controller signed out', () async {
      final auth = AuthController(repo);
      await auth.restore();
      await expectLater(
        auth.login(email: 'student@campus.edu', password: 'bad'),
        throwsA(isA<ApiException>()),
      );
      expect(auth.status, AuthStatus.signedOut);
    });
  });
}
