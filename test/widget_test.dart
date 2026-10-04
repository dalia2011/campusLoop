import 'package:campus_loop/core/network/api_client.dart';
import 'package:campus_loop/core/network/token_storage.dart';
import 'package:campus_loop/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App starts and shows the placeholder', (tester) async {
    final client = ApiClient(tokenStorage: MemoryTokenStorage());
    await tester.pumpWidget(CampusLoopApp(apiClient: client));
    expect(find.text('CampusLoop'), findsOneWidget);
  });
}
