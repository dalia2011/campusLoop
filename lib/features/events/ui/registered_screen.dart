import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../core/theme/app_theme.dart';
import '../data/models/event.dart';
import 'ticket_screen.dart';
import 'widgets/event_widgets.dart';

/// "You're going!" (design 15), shown right after a successful registration.
class RegisteredScreen extends StatelessWidget {
  const RegisteredScreen({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final registered = event.copyWith(viewerStatus: ViewerStatus.registered);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    ExcludeSemantics(
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F6F0),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 56,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        'You’re going!',
                        style: textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Your spot at ${event.title} is confirmed. Show your '
                      'ticket at the entrance.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InfoTile(
                      icon: Icons.event_available_outlined,
                      title: event.title,
                      subtitle: formatEventRange(event.startsAt, event.endsAt),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.tint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'We’ll send an in-app reminder 24 hours before '
                              'the event.',
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => TicketScreen(event: registered),
                  ),
                ),
                child: const Text('View ticket'),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Back to events'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
