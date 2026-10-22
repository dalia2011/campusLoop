import 'package:campus_loop/core/network/token_storage.dart';
import 'package:campus_loop/core/theme/app_theme.dart';
import 'package:campus_loop/features/auth/data/mock_auth_repository.dart';
import 'package:campus_loop/features/auth/state/auth_controller.dart';
import 'package:campus_loop/features/auth/state/auth_scope.dart';
import 'package:campus_loop/features/auth/ui/auth_gate.dart';
import 'package:campus_loop/features/auth/ui/create_account_screen.dart';
import 'package:campus_loop/features/auth/ui/reset_password_screen.dart';
import 'package:campus_loop/features/auth/ui/sign_in_screen.dart';
import 'package:campus_loop/features/auth/ui/validators.dart';
import 'package:campus_loop/features/auth/ui/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AuthController _controller([MemoryTokenStorage? storage]) => AuthController(
  MockAuthRepository(
    tokenStorage: storage ?? MemoryTokenStorage(),
    latency: Duration.zero,
  ),
);

Widget _wrap(Widget home, AuthController auth) => AuthScope(
  controller: auth,
  child: MaterialApp(theme: buildAppTheme(), home: home),
);

void main() {
  group('AuthValidators', () {
    test('email', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('nope'), isNotNull);
      expect(AuthValidators.email('a@campus.edu'), isNull);
    });

    test('new password needs 12 characters', () {
      expect(AuthValidators.newPassword('short'), isNotNull);
      expect(AuthValidators.newPassword('123456789012'), isNull);
    });
  });

  testWidgets('welcome -> onboarding 1 -> onboarding 2 -> create account', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const WelcomeScreen(), _controller()));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Find events you’ll love'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Never miss a moment'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Full name'), findsOneWidget);
  });

  testWidgets('sign in shows errors for empty fields', (tester) async {
    await tester.pumpWidget(_wrap(const SignInScreen(), _controller()));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter your campus email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('create account blocks short password and unticked terms', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const CreateAccountScreen(), _controller()));
    await tester.enterText(find.byType(TextFormField).at(0), 'Alex Rivera');
    await tester.enterText(find.byType(TextFormField).at(1), 'alex@campus.edu');
    await tester.enterText(find.byType(TextFormField).at(2), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(find.text('Use 12 or more characters.'), findsOneWidget);
    expect(find.text('You need to agree to continue.'), findsOneWidget);
  });

  testWidgets('reset password shows the same message for any valid email', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ResetPasswordScreen(), _controller()));
    await tester.enterText(find.byType(TextFormField), 'anyone@campus.edu');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('If an account exists'), findsOneWidget);
  });

  group('AuthGate flow', () {
    testWidgets('wrong password shows an error and stays on sign in', (
      tester,
    ) async {
      final auth = _controller();
      await auth.restore();
      await tester.pumpWidget(_wrap(const AuthGate(), auth));

      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'student@campus.edu',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'wrong-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(auth.status, AuthStatus.signedOut);
    });

    testWidgets('sign in then sign out returns to welcome', (tester) async {
      final auth = _controller();
      await auth.restore();
      await tester.pumpWidget(_wrap(const AuthGate(), auth));

      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'student@campus.edu',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        MockAuthRepository.demoPassword,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Hi, Alex Rivera'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('expired session shows the sign in notice', (tester) async {
      final auth = _controller();
      await auth.login(
        email: 'student@campus.edu',
        password: MockAuthRepository.demoPassword,
      );
      await tester.pumpWidget(_wrap(const AuthGate(), auth));
      expect(find.text('Hi, Alex Rivera'), findsOneWidget);

      auth.handleSessionExpired();
      await tester.pumpAndSettle();

      expect(find.text('Please sign in again to continue.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    });
  });
}
