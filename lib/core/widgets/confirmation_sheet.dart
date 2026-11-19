import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A bottom sheet that asks "are you sure?" and returns true only when the user
/// confirms. Dismissing the sheet, tapping outside or pressing the keep button
/// returns false.
///
/// Used for cancelling a registration and leaving the waitlist. Set
/// [destructive] to colour the confirm button as a warning.
Future<bool> showConfirmationSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String keepLabel,
  bool destructive = true,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final textTheme = Theme.of(sheetContext).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                    : null,
                onPressed: () => Navigator.pop(sheetContext, true),
                child: Text(confirmLabel),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () => Navigator.pop(sheetContext, false),
                child: Text(keepLabel),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
