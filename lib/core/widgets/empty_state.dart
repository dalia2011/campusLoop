import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_theme.dart';

/// Full-area message with an icon, a title, an explanation and (usually) one
/// action. Used for empty lists, errors and the offline state, so every state
/// has explicit copy and a way forward.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Standard "request failed" state with a Retry button. Offline gets its own
  /// wording.
  factory EmptyState.error(
    ApiException error, {
    required VoidCallback onRetry,
  }) {
    final offline = error.isOffline;
    return EmptyState(
      icon: offline ? Icons.cloud_off_outlined : Icons.error_outline,
      title: offline ? 'You are offline' : 'Something went wrong',
      message: offline ? 'Check your connection and try again.' : error.message,
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Container(
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.tint,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 40, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
