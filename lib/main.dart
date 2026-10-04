import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/network/token_storage.dart';

/// App entry point. Flutter starts running here.
///
/// For now this only builds the shared [ApiClient] and shows a placeholder
/// screen. Screens and navigation come in later steps.
void main() {
  final apiClient = ApiClient(tokenStorage: SecureTokenStorage());
  runApp(CampusLoopApp(apiClient: apiClient));
}

class CampusLoopApp extends StatelessWidget {
  const CampusLoopApp({super.key, required this.apiClient});

  /// Created once in main() and handed down to whatever needs the backend.
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusLoop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3C5CF1)),
      ),
      home: const Scaffold(body: Center(child: Text('CampusLoop'))),
    );
  }
}
