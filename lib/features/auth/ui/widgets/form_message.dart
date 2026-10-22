import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';

/// Text shown for a failed auth request. Offline gets the spec's wording;
/// everything else uses the server's own (safe to show) message.
String messageForError(Object error) {
  if (error is ApiException) {
    if (error.isOffline) {
      return 'You are offline. Check your connection and retry.';
    }
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}

/// A message box above a form. Screen readers announce it when it appears
/// (liveRegion), and the icon means it is not shown by colour alone.
class FormMessage extends StatelessWidget {
  const FormMessage(this.text, {super.key, this.isError = true});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.primary;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: color,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

/// A button that shows a spinner and ignores taps while [busy].
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}
