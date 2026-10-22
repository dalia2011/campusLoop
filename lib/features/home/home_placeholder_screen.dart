import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../auth/state/auth_scope.dart';

/// Temporary landing screen after sign in. The team replaces this with the
/// bottom tabs (Explore, My Events, Alerts, Profile). Keeps a Sign out button
/// so the auth flow can be tried end to end.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).user!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Hi, ${user.displayName}',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${user.email} · ${user.isOrganizer ? 'Organizer' : 'Student'}',
                style: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text('Explore, My Events, Alerts and Profile go here.'),
              const Spacer(),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () => AuthScope.read(context).logout(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
