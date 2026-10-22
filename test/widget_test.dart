import 'package:campus_loop/core/network/api_client.dart';
import 'package:campus_loop/core/network/token_storage.dart';
import 'package:campus_loop/features/auth/data/mock_auth_repository.dart';
import 'package:campus_loop/features/auth/state/auth_controller.dart';
import 'package:campus_loop/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App starts on the welcome screen when signed out', (
    tester,
  ) async {
    final storage = MemoryTokenStorage();
    final auth = AuthController(
      MockAuthRepository(tokenStorage: storage, latency: Duration.zero),
    )..restore();
    await tester.pumpWidget(
      CampusLoopApp(
        apiClient: ApiClient(tokenStorage: storage),
        auth: auth,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('App starts on Home when a session was saved', (tester) async {
    final storage = MemoryTokenStorage();
    final repo = MockAuthRepository(
      tokenStorage: storage,
      latency: Duration.zero,
    );
    await repo.login(
      email: 'organizer@campus.edu',
      password: MockAuthRepository.demoPassword,
    );
    final auth = AuthController(repo)..restore();
    await tester.pumpWidget(
      CampusLoopApp(
        apiClient: ApiClient(tokenStorage: storage),
        auth: auth,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hi, Sam Lee'), findsOneWidget);
  });
}
