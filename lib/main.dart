import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/network/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/api_auth_repository.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/mock_auth_repository.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/auth/state/auth_scope.dart';
import 'features/auth/ui/auth_gate.dart';

/// App entry point. Flutter starts running here.
///
/// Builds the shared pieces once: token storage, the [ApiClient], the auth
/// repository (mock or real, see AppConfig.useMockApi) and the
/// [AuthController] that the whole app listens to.
void main() {
  final tokenStorage = SecureTokenStorage();

  // The client needs to tell the controller when the session expires, and the
  // controller needs the repository, which needs the client. `late` breaks
  // the loop: auth is assigned below, before any request can fail.
  late final AuthController auth;
  final apiClient = ApiClient(
    tokenStorage: tokenStorage,
    onSessionExpired: () => auth.handleSessionExpired(),
  );

  final AuthRepository repository = AppConfig.useMockApi
      ? MockAuthRepository(tokenStorage: tokenStorage)
      : ApiAuthRepository(apiClient: apiClient, tokenStorage: tokenStorage);
  auth = AuthController(repository)..restore();

  runApp(CampusLoopApp(apiClient: apiClient, auth: auth));
}

class CampusLoopApp extends StatelessWidget {
  const CampusLoopApp({super.key, required this.apiClient, required this.auth});

  /// Created once in main() and handed down to whatever needs the backend.
  final ApiClient apiClient;

  /// Who is signed in. Available to all screens through [AuthScope].
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: auth,
      child: MaterialApp(
        title: 'CampusLoop',
        theme: buildAppTheme(),
        home: const AuthGate(),
      ),
    );
  }
}
