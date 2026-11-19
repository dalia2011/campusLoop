import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/events_repository.dart';
import '../data/models/event.dart';
import '../state/events_scope.dart';
import 'registration_helpers.dart';
import 'ticket_screen.dart';
import 'widgets/event_widgets.dart';

/// "Waitlisted" (design 20): where the student stands in line, with a way out.
///
/// The position is refreshed when the screen opens. If a seat was given to
/// this student in the meantime (promotion), the screen switches to a "You got
/// a spot" message with a button to the ticket instead of showing stale data.
class WaitlistScreen extends StatefulWidget {
  const WaitlistScreen({super.key, required this.event});

  final Event event;

  @override
  State<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends State<WaitlistScreen> {
  late final EventsRepository _repository;
  late Event _event = widget.event;
  ApiException? _refreshError;
  DateTime? _syncedAt;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repository = EventsScope.read(context);
    _repository.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _repository.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final event = await _repository.getEvent(_event.id);
      if (!mounted) return;
      setState(() {
        _event = event;
        _refreshError = null;
        _syncedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _refreshError = ApiException.from(e));
    }
  }

  Future<void> _leave() async {
    if (!await confirmLeaveWaitlist(context) || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.cancelRegistration(_event.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      showToastOn(messenger, 'You left the waitlist.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, actionErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = _event.viewerStatus;

    return Scaffold(
      appBar: AppBar(title: const Text('Waitlist')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_refreshError != null) ...[
            OfflineBanner(
              error: _refreshError!,
              lastSynced: _syncedAt,
              onRetry: _load,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge(
              label: switch (status) {
                ViewerStatus.registered => 'Registered',
                ViewerStatus.waitlisted => 'Waitlisted',
                _ => 'Not on the waitlist',
              },
              icon: status == ViewerStatus.registered
                  ? Icons.check_circle_outline
                  : Icons.hourglass_top,
              tone: status == ViewerStatus.registered
                  ? BadgeTone.success
                  : BadgeTone.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            header: true,
            child: Text(
              _event.title,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          InfoTile(
            icon: Icons.schedule,
            title: formatEventRange(_event.startsAt, _event.endsAt),
            subtitle: _event.venue,
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._stateContent(status, textTheme),
        ],
      ),
    );
  }

  List<Widget> _stateContent(ViewerStatus status, TextTheme textTheme) {
    if (status == ViewerStatus.waitlisted) {
      final position = _event.waitlistPosition;
      return [
        Semantics(
          container: true,
          label: position == null
              ? 'You are on the waitlist'
              : 'Your current position on the waitlist is $position',
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.tint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(
                    position?.toString() ?? '–',
                    style: textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Your current position',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'We will notify you if a place becomes available. Your position may '
          'change.',
          style: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
          ),
          onPressed: _busy ? null : _leave,
          child: const Text('Leave waitlist'),
        ),
      ];
    }

    if (status == ViewerStatus.registered) {
      return [
        Text(
          'Good news! A place opened up and it is yours. Your ticket is ready.',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => TicketScreen(event: _event),
            ),
          ),
          child: const Text('View ticket'),
        ),
      ];
    }

    return [
      Text(
        'You are no longer on the waitlist for this event.',
        style: textTheme.bodyLarge,
      ),
      const SizedBox(height: AppSpacing.md),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('Back'),
      ),
    ];
  }
}
