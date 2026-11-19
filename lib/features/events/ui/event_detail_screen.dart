import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/ui/widgets/form_message.dart' show BusyButton;
import '../data/events_repository.dart';
import '../data/models/event.dart';
import '../data/models/event_filters.dart';
import '../state/events_scope.dart';
import 'confirm_registration_screen.dart';
import 'registered_screen.dart';
import 'registration_helpers.dart';
import 'ticket_screen.dart';
import 'widgets/event_widgets.dart';

/// Event details (designs 12 and 13). One screen for every state:
/// seats available, full (waitlist), registered, waitlisted, checked in,
/// canceled, ended and registration closed. Each has its own copy and action.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.initial,
    this.syncedAt,
  });

  final String eventId;

  /// The event as it appeared in the list. Shown immediately while the full
  /// details load.
  final Event? initial;

  /// When [initial] was last received from the server.
  final DateTime? syncedAt;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final EventsRepository _repository;
  Event? _event;
  ApiException? _error; // Nothing to show at all.
  ApiException? _refreshError; // Showing older data.
  DateTime? _syncedAt;
  bool _busy = false;

  // One key per "join waitlist" user action, reused if the same action is
  // retried so the server never creates two registrations.
  String? _waitlistKey;

  @override
  void initState() {
    super.initState();
    _repository = EventsScope.read(context);
    _event = widget.initial;
    _syncedAt = widget.syncedAt;
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
      final event = await _repository.getEvent(widget.eventId);
      if (!mounted) return;
      setState(() {
        _event = event;
        _error = null;
        _refreshError = null;
        _syncedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      final failure = ApiException.from(e);
      setState(() {
        if (_event == null) {
          _error = failure;
        } else {
          _refreshError = failure;
        }
      });
    }
  }

  Future<void> _toggleSave() async {
    final event = _event!;
    final save = !event.isSaved;
    setState(() => _event = event.copyWith(isSaved: save));
    try {
      if (save) {
        await _repository.saveEvent(event.id);
      } else {
        await _repository.unsaveEvent(event.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _event = _event!.copyWith(isSaved: !save)); // Undo.
      showToast(context, actionErrorMessage(e));
    }
  }

  Future<void> _reserve() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConfirmRegistrationScreen(event: _event!),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _joinWaitlist() async {
    final event = _event!;
    setState(() => _busy = true);
    _waitlistKey ??= ApiClient.newIdempotencyKey();
    try {
      final result = await _repository.register(
        event.id,
        idempotencyKey: _waitlistKey!,
        joinWaitlist: true,
      );
      _waitlistKey = null;
      if (!mounted) return;
      if (result.isWaitlisted) {
        final position = result.queuePosition;
        showToast(
          context,
          position == null
              ? 'You are on the waitlist.'
              : 'You are on the waitlist. Your position is $position.',
        );
      } else {
        // A seat opened up at the same moment, so it became a registration.
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RegisteredScreen(event: event),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showToast(context, actionErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leaveWaitlist() async {
    final event = _event!;
    if (!await confirmLeaveWaitlist(context) || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.cancelRegistration(event.id);
      if (!mounted) return;
      showToast(context, 'You left the waitlist.');
    } catch (e) {
      if (!mounted) return;
      showToast(context, actionErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _viewTicket() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TicketScreen(event: _event!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event details'),
        actions: [
          if (event != null)
            IconButton(
              tooltip: event.isSaved ? 'Remove from saved' : 'Save event',
              icon: Icon(event.isSaved ? Icons.star : Icons.star_border),
              color: event.isSaved ? AppColors.primary : null,
              onPressed: _toggleSave,
            ),
        ],
      ),
      body: event == null
          ? (_error != null
                ? EmptyState.error(_error!, onRetry: _load)
                : Center(
                    child: Semantics(
                      label: 'Loading event',
                      child: const CircularProgressIndicator(),
                    ),
                  ))
          : Column(
              children: [
                Expanded(child: _content(event)),
                _actionBar(event),
              ],
            ),
    );
  }

  Widget _content(Event event) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final seatsTitle = event.isFull
        ? 'Full · all ${event.capacity} spots are taken'
        : '${event.remainingSeats} of ${event.capacity} seats left';
    final waitlistOffer =
        event.isFull &&
        event.registrationOpen(now) &&
        (event.viewerStatus == ViewerStatus.none ||
            event.viewerStatus == ViewerStatus.canceled);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      children: [
        if (_refreshError != null) ...[
          OfflineBanner(
            error: _refreshError!,
            lastSynced: _syncedAt,
            onRetry: _load,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _Cover(event),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            StatusBadge(
              label: topicLabel(event.topic),
              icon: topicIcon(event.topic),
              tone: BadgeTone.info,
            ),
            const StatusBadge(label: 'Free', icon: Icons.sell_outlined),
            EventStatusBadge(event),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          header: true,
          child: Text(
            event.title,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (event.organizerName != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 18,
                color: AppColors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${event.organizerName} · Verified organizer',
                  style: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        InfoTile(
          icon: Icons.schedule,
          title: formatEventRange(event.startsAt, event.endsAt),
        ),
        InfoTile(icon: Icons.place_outlined, title: event.venue),
        InfoTile(
          icon: Icons.event_seat_outlined,
          title: seatsTitle,
          subtitle: event.registrationOpen(now)
              ? 'Registration closes at start'
              : null,
        ),
        if (waitlistOffer) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All ${event.capacity} spots are taken. If a student cancels, '
                  'waitlisted students receive a place in order.',
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'We will notify you if you get a spot.',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
        if (event.description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(
              'About',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            event.description,
            style: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  /// The bottom area: one message and one action that fit the viewer's state.
  Widget _actionBar(Event event) {
    final now = DateTime.now();
    final textTheme = Theme.of(context).textTheme;

    Widget notice(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.muted),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(text, style: textTheme.bodyLarge)),
          ],
        ),
      ),
    );

    Widget back(String label) => OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      onPressed: () => Navigator.of(context).maybePop(),
      child: Text(label),
    );

    final List<Widget> children;
    if (event.isCanceled) {
      children = [
        notice(
          Icons.cancel_outlined,
          'This event was canceled by the organizer.',
        ),
        back('Back to events'),
      ];
    } else if (event.viewerStatus == ViewerStatus.checkedIn) {
      final at = event.checkedInAt;
      children = [
        notice(
          Icons.verified_outlined,
          at == null
              ? 'You are checked in.'
              : 'Already checked in at ${formatTime(at)}.',
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: _viewTicket,
          child: const Text('View ticket'),
        ),
      ];
    } else if (event.hasEnded(now)) {
      children = [
        notice(Icons.event_busy_outlined, 'This event has ended.'),
        back('Back to events'),
      ];
    } else if (event.viewerStatus == ViewerStatus.registered) {
      children = [
        notice(
          Icons.check_circle_outline,
          'You are registered for this event.',
        ),
        FilledButton(onPressed: _viewTicket, child: const Text('View ticket')),
      ];
    } else if (event.viewerStatus == ViewerStatus.waitlisted) {
      final position = event.waitlistPosition;
      children = [
        notice(
          Icons.hourglass_top,
          position == null
              ? 'You are on the waitlist. We will notify you if a place opens.'
              : 'You are on the waitlist, position $position. We will notify you '
                    'if a place opens.',
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: _busy ? null : _leaveWaitlist,
          child: const Text('Leave waitlist'),
        ),
      ];
    } else if (!event.registrationOpen(now)) {
      children = [
        notice(
          Icons.lock_outline,
          'Registration is closed. This event has already started.',
        ),
        back('Back to events'),
      ];
    } else if (event.isFull) {
      children = [
        BusyButton(
          label: 'Join waitlist',
          busy: _busy,
          onPressed: _joinWaitlist,
        ),
      ];
    } else {
      children = [
        FilledButton(onPressed: _reserve, child: const Text('Reserve my spot')),
      ];
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Wide image at the top of the detail screen (topic icon when no photo).
class _Cover extends StatelessWidget {
  const _Cover(this.event);

  final Event event;

  @override
  Widget build(BuildContext context) {
    final url = event.imageUrl;
    final fallback = Container(
      color: AppColors.tint,
      alignment: Alignment.center,
      child: Icon(topicIcon(event.topic), size: 56, color: AppColors.primary),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: url == null
              ? fallback
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}
