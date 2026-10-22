import 'package:flutter/material.dart';

import '../../home/home_placeholder_screen.dart';
import '../state/auth_controller.dart';
import '../state/auth_scope.dart';
import 'sign_in_screen.dart';
import 'welcome_screen.dart';

/// Picks the first screen from the sign in state:
///   starting up  -> spinner
///   signed in    -> the app (placeholder Home for now)
///   signed out   -> Welcome (or Sign in with a notice if the session expired)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.signedIn:
        return const HomePlaceholderScreen();
      case AuthStatus.signedOut:
        return auth.sessionExpired
            ? const SignInScreen(notice: 'Please sign in again to continue.')
            : const WelcomeScreen();
    }
  }
}
