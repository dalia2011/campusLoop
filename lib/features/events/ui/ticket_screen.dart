import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/format/date_format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/events_repository.dart';
import '../data/models/event.dart';
import '../data/models/ticket.dart';
import '../state/events_scope.dart';
import 'registration_helpers.dart';

/// The ticket (design 18): a QR code with the signed token, the short manual
/// code, and the cancel button (which opens the confirmation sheet, design 19).
///
/// While online the token is refreshed every minute. If a refresh fails the
/// last ticket stays on screen with "You are offline. Showing saved ticket from
/// [time]." so it can still be shown at the door.
class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, required this.event});

  final Event event;

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  /// How often the QR token is renewed while online.
  static const refreshEvery = Duration(minutes: 1);

  late final EventsRepository _repository;
  Timer? _timer;
  Ticket? _ticket;
  ApiException? _error; // No ticket to show.
  ApiException? _refreshError; // Showing the last ticket we received.
  bool _cancelling = false;

  Event get _event => widget.event;

  @override
  void initState() {
    super.initState();
    _repository = EventsScope.read(context);
    _load();
    _timer = Timer.periodic(refreshEvery, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ticket = await _repository.getTicket(_event.id);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _error = null;
        _refreshError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final failure = ApiException.from(e);
      setState(() {
        // Connection trouble: keep showing the last ticket we have. Anything
        // else (e.g. the registration was canceled) means it is no longer valid.
        final temporary =
            failure.isOffline || failure.type == ApiErrorType.server;
        if (_ticket != null && temporary) {
          _refreshError = failure;
        } else {
          _ticket = null;
          _error = failure;
        }
      });
    }
  }

  Future<void> _cancel() async {
    if (!await confirmCancelRegistration(context) || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await _repository.cancelRegistration(_event.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      showToastOn(messenger, 'Your registration was canceled.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      showToast(context, actionErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your ticket')),
      body: _body(),
    );
  }

  Widget _body() {
    final ticket = _ticket;
    if (ticket == null) {
      final error = _error;
      if (error == null) {
        return Center(
          child: Semantics(
            label: 'Loading ticket',
            child: const CircularProgressIndicator(),
          ),
        );
      }
      if (error.isOffline || error.type == ApiErrorType.server) {
        return EmptyState.error(error, onRetry: _load);
      }
      return EmptyState(
        icon: Icons.confirmation_number_outlined,
        title: 'No ticket available',
        message: error.message,
        actionLabel: 'Back',
        onAction: () => Navigator.of(context).maybePop(),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final canCancel =
        !ticket.isCheckedIn && _event.startsAt.isAfter(DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (_refreshError != null) ...[
          OfflineBanner(
            error: _refreshError!,
            lastSynced: ticket.issuedAt,
            subject: 'ticket',
            onRetry: _load,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Semantics(
          header: true,
          child: Text(
            _event.title,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatEventRange(_event.startsAt, _event.endsAt),
          style: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        if (ticket.isCheckedIn) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge(
              label: 'Checked in at ${formatTime(ticket.checkedInAt!)}',
              icon: Icons.verified_outlined,
              tone: BadgeTone.success,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Semantics(
                image: true,
                label:
                    'Ticket QR code for ${_event.title}. '
                    'Manual code ${ticket.code}.',
                child: ExcludeSemantics(
                  child: QrImageView(
                    data: ticket.token,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                ticket.code,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _refreshError == null
                    ? 'Token refreshes each minute while you are online'
                    : 'Saved ticket. It can be scanned once you are back online.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (canCancel)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            onPressed: _cancelling ? null : _cancel,
            child: const Text('Cancel registration'),
          )
        else if (!ticket.isCheckedIn)
          Text(
            'Registrations cannot be canceled after the event starts.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
      ],
    );
  }
}
