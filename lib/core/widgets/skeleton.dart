import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A grey placeholder shape shown while content loads.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder shaped like an event card.
class EventCardSkeleton extends StatelessWidget {
  const EventCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 64, height: 64, radius: 16),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 12),
                SizedBox(height: 8),
                SkeletonBox(height: 16),
                SizedBox(height: 8),
                SkeletonBox(width: 160, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A few event card placeholders, announced to screen readers as one
/// "Loading" message instead of many empty boxes.
class EventListSkeleton extends StatelessWidget {
  const EventListSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading events',
      child: ExcludeSemantics(
        child: Column(
          children: [for (var i = 0; i < count; i++) const EventCardSkeleton()],
        ),
      ),
    );
  }
}
