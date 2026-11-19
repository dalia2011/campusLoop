import 'package:flutter/foundation.dart';

import 'models/event.dart';
import 'models/event_filters.dart';
import 'models/registration.dart';
import 'models/ticket.dart';

/// The spec says lists come 20 per page.
const kEventsPageSize = 20;

/// One page of Explore results. [nextCursor] is null on the last page.
class EventPage {
  const EventPage({required this.items, this.nextCursor});

  final List<Event> items;
  final String? nextCursor;
}

/// The three tabs of My Events.
enum MyEventsTab { registered, saved, past }

/// Everything the app can ask the events backend to do.
///
/// Screens only know this interface. [MockEventsRepository] (fake data) and
/// [ApiEventsRepository] (real server) both implement it, so switching never
/// touches the UI. Failures are thrown as `ApiException`.
///
/// After any successful write the repository calls [notifyChanged]. Screens
/// that show events (Explore, My Events, detail) listen to [changes] and
/// refresh themselves, so a registration made on one screen is reflected on
/// all the others.
abstract class EventsRepository {
  /// Increases by one after every successful write.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  @protected
  void notifyChanged() => changes.value++;

  /// Published events, soonest first. [query] matches title and description.
  Future<EventPage> listEvents(
    EventFilters filters, {
    String query = '',
    String? cursor,
  });

  Future<Event> getEvent(String id);

  /// Reserves a seat. With [joinWaitlist] true, joins the waitlist when the
  /// event is full.
  ///
  /// Without it, a full event fails with a 409 `EVENT_FULL` error, which is
  /// how the UI knows to show "That spot was just taken. You can join the
  /// waitlist."
  ///
  /// [idempotencyKey] must be created once per user action and reused when
  /// retrying that same action (see ApiClient.newIdempotencyKey).
  Future<Registration> register(
    String eventId, {
    required String idempotencyKey,
    bool joinWaitlist = false,
  });

  /// Cancels a registration or leaves the waitlist.
  Future<void> cancelRegistration(String eventId);

  Future<void> saveEvent(String eventId);
  Future<void> unsaveEvent(String eventId);

  Future<List<Event>> myEvents(MyEventsTab tab);

  /// A fresh signed ticket token for a registered event. Tokens rotate, so the
  /// ticket screen asks again every minute while online.
  Future<Ticket> getTicket(String eventId);
}
