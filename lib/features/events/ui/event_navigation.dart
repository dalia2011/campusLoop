import 'package:flutter/material.dart';

import '../data/models/event.dart';
import 'event_detail_screen.dart';
import 'ticket_screen.dart';
import 'waitlist_screen.dart';

/// Opens the event detail screen (design 12/13).
///
/// [syncedAt] is when the list the event came from was last refreshed. It is
/// only used for the "Showing saved information from [time]" banner if the
/// detail cannot be refreshed.
Future<void> openEvent(
  BuildContext context,
  Event event, {
  DateTime? syncedAt,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EventDetailScreen(
        eventId: event.id,
        initial: event,
        syncedAt: syncedAt,
      ),
    ),
  );
}

/// Where tapping an event in "My Events > Registered" goes: the ticket for a
/// registration, the waitlist screen for a waitlist spot.
Future<void> openMyEvent(BuildContext context, Event event) {
  switch (event.viewerStatus) {
    case ViewerStatus.registered:
    case ViewerStatus.checkedIn:
      return Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TicketScreen(event: event)),
      );
    case ViewerStatus.waitlisted:
      return Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => WaitlistScreen(event: event)),
      );
    case ViewerStatus.none:
    case ViewerStatus.canceled:
      return openEvent(context, event);
  }
}
