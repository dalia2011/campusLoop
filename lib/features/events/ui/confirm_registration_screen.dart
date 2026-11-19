import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/ui/widgets/form_message.dart' show BusyButton, FormMessage;
import '../data/events_repository.dart';
import '../data/models/event.dart';
import '../state/events_scope.dart';
import 'registered_screen.dart';
import 'registration_helpers.dart';
import 'widgets/event_widgets.dart';

/// "Confirm your place" (design 14) with the "spot was just taken" fallback.
///
/// If someone else takes the last seat while the student is confirming, the
/// server answers 409 EVENT_FULL. The screen then shows the spec's copy
/// ("That spot was just taken. You can join the waitlist.") and the button
/// becomes "Join waitlist".
class ConfirmRegistrationScreen extends StatefulWidget {
  const ConfirmRegistrationScreen({super.key, required this.event});

  final Event event;

  @override
  State<ConfirmRegistrationScreen> createState() =>
      _ConfirmRegistrationScreenState();
}

class _ConfirmRegistrationScreenState extends State<ConfirmRegistrationScreen> {
  late final EventsRepository _repository;

  // ONE key for this tap on "Confirm registration". If the request times out
  // and the student taps again, the same key tells the server it is the same
  // registration, never a second one.
  String _idempotencyKey = ApiClient.newIdempotencyKey();

  bool _busy = false;
  bool _offerWaitlist = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _repository = EventsScope.read(context);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await _repository.register(
        widget.event.id,
        idempotencyKey: _idempotencyKey,
        joinWaitlist: _offerWaitlist,
      );
      if (!mounted) return;
      if (result.isWaitlisted) {
        final messenger = ScaffoldMessenger.of(context);
        final position = result.queuePosition;
        Navigator.of(context).pop();
        showToastOn(
          messenger,
          position == null
              ? 'You are on the waitlist.'
              : 'You are on the waitlist. Your position is $position.',
        );
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RegisteredScreen(event: widget.event),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final error = ApiException.from(e);
      setState(() {
        _busy = false;
        if (error.code == 'EVENT_FULL') {
          // A different action now (waitlist), so it gets its own key.
          _offerWaitlist = true;
          _idempotencyKey = ApiClient.newIdempotencyKey();
          _message = 'That spot was just taken. You can join the waitlist.';
        } else {
          _message = actionErrorMessage(error);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _offerWaitlist ? 'Join the waitlist' : 'Confirm your place',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    event.title,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                InfoTile(
                  icon: Icons.schedule,
                  title: formatEventRange(event.startsAt, event.endsAt),
                  subtitle: event.venue,
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _offerWaitlist
                        ? 'You will be added to the end of the waitlist. If a '
                              'student cancels, waitlisted students receive a '
                              'place in order.'
                        : 'A free place will be reserved for you. You can cancel '
                              'before the event starts.',
                    style: textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.sell_outlined,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'No payment required',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_message != null) ...[
                    FormMessage(_message!),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  BusyButton(
                    label: _offerWaitlist
                        ? 'Join waitlist'
                        : (_message == null ? 'Confirm registration' : 'Retry'),
                    busy: _busy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
