import 'package:flutter/material.dart';

import '../format/date_format.dart';
import '../network/api_exception.dart';
import '../theme/app_theme.dart';

/// Shown above content that is still on screen but may be out of date because
/// the latest refresh failed.
///
/// Uses the spec's copy: "You are offline. Showing saved information from
/// [time]." with a Retry action.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.error,
    required this.onRetry,
    this.lastSynced,
    this.subject = 'information',
  });

  final ApiException error;
  final DateTime? lastSynced;
  final VoidCallback onRetry;

  /// What is being shown: "information" or "ticket".
  final String subject;

  @override
  Widget build(BuildContext context) {
    final time = lastSynced == null ? '' : ' from ${formatSynced(lastSynced!)}';
    final text = error.isOffline
        ? 'You are offline. Showing saved $subject$time.'
        : 'We could not refresh. Showing saved $subject$time.';
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(
          left: AppSpacing.sm,
          top: AppSpacing.xs,
          bottom: AppSpacing.xs,
          right: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.tint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(text)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
