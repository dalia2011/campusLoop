import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Layout shared by the Welcome and Onboarding screens: an illustration
/// block, a title, a description and one big button at the bottom.
class IntroPage extends StatelessWidget {
  const IntroPage({
    super.key,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.progress,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;

  /// Optional text button under the main button (e.g. "I already have an account").
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  /// Shown as "1 of 2" for screen readers and as dots on screen.
  final ({int current, int total})? progress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.tint,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                style: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
              const Spacer(),
              if (progress != null) ...[
                Semantics(
                  label: 'Step ${progress!.current} of ${progress!.total}',
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 1; i <= progress!.total; i++)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == progress!.current ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == progress!.current
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
              if (secondaryLabel != null)
                Center(
                  child: TextButton(
                    onPressed: onSecondaryPressed,
                    child: Text(secondaryLabel!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
