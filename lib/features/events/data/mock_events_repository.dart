import '../../../core/network/api_exception.dart';
import 'events_repository.dart';
import 'models/event.dart';
import 'models/event_filters.dart';
import 'models/registration.dart';
import 'models/ticket.dart';

/// Fake backend for development: in memory, short delay, fictional data.
///
/// It follows the spec's rules so the UI can be built and tried without a
/// server: one active registration per event, a full event refuses a normal
/// registration (409 EVENT_FULL) but accepts a waitlist join, cancelling
/// promotes the next waitlisted student, and the same Idempotency-Key never
/// creates a second registration.
///
/// Things to try in the demo:
///   Build Night        12 seats left          -> reserve a spot
///   Community Garden   full, 3 waitlisted     -> join the waitlist
///   Last Seat Lab      someone grabs the last seat while you confirm
///                      -> "That spot was just taken."
///   Startup Pitch      already registered     -> ticket
///   Campus Fun Run     already waitlisted #2  -> waitlist screen
///   Design Sprint /
///   Poster Lab         already saved
///
/// Set [offline] to true to make every call fail like a lost connection.
class MockEventsRepository extends EventsRepository {
  MockEventsRepository({
    this.latency = const Duration(milliseconds: 500),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _seed();
  }

  final Duration latency;
  final DateTime Function() _now;

  /// Pretend the network is down.
  bool offline = false;

  final List<_Record> _records = [];
  final Map<String, Registration> _registrationsByKey = {};
  int _registrationCounter = 400;

  Future<void> _delay() async {
    if (latency != Duration.zero) await Future<void>.delayed(latency);
    if (offline) {
      throw const ApiException(
        type: ApiErrorType.network,
        message: 'You are offline.',
      );
    }
  }

  _Record _find(String id) {
    for (final r in _records) {
      if (r.id == id) return r;
    }
    throw const ApiException(
      type: ApiErrorType.notFound,
      message: 'That event could not be found.',
      code: 'EVENT_NOT_FOUND',
      statusCode: 404,
    );
  }

  @override
  Future<EventPage> listEvents(
    EventFilters filters, {
    String query = '',
    String? cursor,
  }) async {
    await _delay();
    final now = _now();
    final q = query.trim().toLowerCase();
    final from = filters.from(now);
    final to = filters.to(now);

    final matches = _records.where((r) {
      if (r.status != EventStatus.published || !r.end.isAfter(now)) {
        return false;
      }
      if (q.isNotEmpty &&
          !r.title.toLowerCase().contains(q) &&
          !r.description.toLowerCase().contains(q)) {
        return false;
      }
      if (filters.topic != null && r.topic != filters.topic) return false;
      if (from != null && r.start.isBefore(from.toUtc())) return false;
      if (to != null && r.start.isAfter(to.toUtc())) return false;
      if (filters.availableOnly && r.remaining <= 0) return false;
      return true;
    }).toList()..sort(_bySoonest);

    // The cursor is simply "how many items to skip".
    final offset = int.tryParse(cursor ?? '') ?? 0;
    final end = offset + kEventsPageSize;
    return EventPage(
      items: [
        for (final r in matches.skip(offset).take(kEventsPageSize)) r.toEvent(),
      ],
      nextCursor: end < matches.length ? '$end' : null,
    );
  }

  static int _bySoonest(_Record a, _Record b) {
    final c = a.start.compareTo(b.start);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  @override
  Future<Event> getEvent(String id) async {
    await _delay();
    return _find(id).toEvent();
  }

  @override
  Future<Registration> register(
    String eventId, {
    required String idempotencyKey,
    bool joinWaitlist = false,
  }) async {
    await _delay();

    // Same key = same user action: return the original result.
    final previous = _registrationsByKey[idempotencyKey];
    if (previous != null) return previous;

    final r = _find(eventId);
    final now = _now();
    if (r.status != EventStatus.published || !r.start.isAfter(now)) {
      throw const ApiException(
        type: ApiErrorType.conflict,
        message: 'This event is no longer accepting registrations.',
        code: 'EVENT_CLOSED',
        statusCode: 409,
      );
    }
    if (r.viewer == ViewerStatus.registered ||
        r.viewer == ViewerStatus.waitlisted ||
        r.viewer == ViewerStatus.checkedIn) {
      throw const ApiException(
        type: ApiErrorType.conflict,
        message: 'You already have a place for this event.',
        code: 'ALREADY_REGISTERED',
        statusCode: 409,
      );
    }

    // Demo: another student takes the last seat while this user is confirming.
    if (r.takeLastSeatOnRegister && !joinWaitlist) {
      r.takeLastSeatOnRegister = false;
      r.taken = r.capacity;
      notifyChanged();
      throw _eventFull();
    }

    late final Registration result;
    if (r.remaining > 0) {
      r.taken++;
      r.viewer = ViewerStatus.registered;
      r.waitlistPosition = null;
      result = Registration(
        id: 'reg_${_registrationCounter++}',
        eventId: r.id,
        status: ViewerStatus.registered,
        ticketAvailable: true,
      );
    } else if (joinWaitlist) {
      r.waitlistCount++;
      r.viewer = ViewerStatus.waitlisted;
      r.waitlistPosition = r.waitlistCount;
      result = Registration(
        id: 'reg_${_registrationCounter++}',
        eventId: r.id,
        status: ViewerStatus.waitlisted,
        queuePosition: r.waitlistPosition,
      );
    } else {
      throw _eventFull();
    }

    _registrationsByKey[idempotencyKey] = result;
    notifyChanged();
    return result;
  }

  ApiException _eventFull() => const ApiException(
    type: ApiErrorType.conflict,
    message: 'That spot was just taken. You can join the waitlist.',
    code: 'EVENT_FULL',
    statusCode: 409,
  );

  @override
  Future<void> cancelRegistration(String eventId) async {
    await _delay();
    final r = _find(eventId);
    if (r.viewer == ViewerStatus.registered) {
      if (!r.start.isAfter(_now())) {
        throw const ApiException(
          type: ApiErrorType.conflict,
          message: 'A registration cannot be canceled after the event starts.',
          code: 'EVENT_STARTED',
          statusCode: 409,
        );
      }
      r.taken--;
      // The earliest waitlisted student (someone else) takes the freed seat.
      if (r.waitlistCount > 0) {
        r.waitlistCount--;
        r.taken++;
      }
    } else if (r.viewer == ViewerStatus.waitlisted) {
      r.waitlistCount--;
    } else {
      throw const ApiException(
        type: ApiErrorType.notFound,
        message: 'You do not have an active registration for this event.',
        code: 'REGISTRATION_NOT_FOUND',
        statusCode: 404,
      );
    }
    r.viewer = ViewerStatus.canceled;
    r.waitlistPosition = null;
    notifyChanged();
  }

  @override
  Future<void> saveEvent(String eventId) async {
    await _delay();
    _find(eventId).saved = true;
    notifyChanged();
  }

  @override
  Future<void> unsaveEvent(String eventId) async {
    await _delay();
    _find(eventId).saved = false;
    notifyChanged();
  }

  @override
  Future<List<Event>> myEvents(MyEventsTab tab) async {
    await _delay();
    final now = _now();
    bool hasPlace(_Record r) =>
        r.viewer == ViewerStatus.registered ||
        r.viewer == ViewerStatus.waitlisted ||
        r.viewer == ViewerStatus.checkedIn;
    bool over(_Record r) =>
        r.status == EventStatus.canceled ||
        r.status == EventStatus.completed ||
        !r.end.isAfter(now);

    switch (tab) {
      case MyEventsTab.registered:
        return [
          for (final r
              in _records.where((r) => hasPlace(r) && !over(r)).toList()
                ..sort(_bySoonest))
            r.toEvent(),
        ];
      case MyEventsTab.saved:
        return [
          for (final r
              in _records.where((r) => r.saved && !over(r)).toList()
                ..sort(_bySoonest))
            r.toEvent(),
        ];
      case MyEventsTab.past:
        return [
          for (final r
              in _records
                  .where((r) => over(r) && (hasPlace(r) || r.saved))
                  .toList()
                ..sort((a, b) => _bySoonest(b, a)))
            r.toEvent(),
        ];
    }
  }

  @override
  Future<Ticket> getTicket(String eventId) async {
    await _delay();
    final r = _find(eventId);
    if (r.viewer != ViewerStatus.registered &&
        r.viewer != ViewerStatus.checkedIn) {
      throw const ApiException(
        type: ApiErrorType.conflict,
        message: 'You do not have a ticket for this event.',
        code: 'NO_TICKET',
        statusCode: 409,
      );
    }
    final issued = _now().toUtc();
    return Ticket(
      registrationId: 'reg_${r.id}',
      eventId: r.id,
      // Looks like an opaque signed token and changes on every call, like the
      // real one (which rotates each minute).
      token: 'mock.${r.id}.${issued.millisecondsSinceEpoch}.signature',
      code: _codeFor(r.id),
      issuedAt: issued,
      expiresAt: issued.add(const Duration(minutes: 2)),
      checkedInAt: r.checkedInAt,
    );
  }

  /// A stable short code per event, e.g. "CL-7K4P9Q".
  static String _codeFor(String id) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    var hash = id.hashCode.abs();
    final buffer = StringBuffer('CL-');
    for (var i = 0; i < 6; i++) {
      buffer.write(alphabet[hash % alphabet.length]);
      hash ~/= alphabet.length;
      if (hash == 0) hash = id.length * 7919 + i * 31;
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------- seed data

  void _seed() {
    final today = _now();
    DateTime at(int dayOffset, int hour) =>
        DateTime(today.year, today.month, today.day + dayOffset, hour).toUtc();

    void add({
      required String id,
      required String title,
      required String topic,
      required String venue,
      required String organizer,
      required int day,
      required int hour,
      int hours = 2,
      required int capacity,
      required int taken,
      String? description,
      EventStatus status = EventStatus.published,
      ViewerStatus viewer = ViewerStatus.none,
      int waitlistCount = 0,
      int? waitlistPosition,
      bool saved = false,
      bool lastSeatRace = false,
      bool checkedIn = false,
    }) {
      final start = at(day, hour);
      _records.add(
        _Record(
          id: id,
          title: title,
          description:
              description ??
              '$title is a friendly campus session open to every student. '
                  'Bring a friend and come curious.',
          topic: topic,
          venue: venue,
          organizer: organizer,
          start: start,
          end: start.add(Duration(hours: hours)),
          capacity: capacity,
          taken: taken,
          status: status,
          viewer: viewer,
          waitlistCount: waitlistCount,
          waitlistPosition: waitlistPosition,
          saved: saved,
          takeLastSeatOnRegister: lastSeatRace,
          checkedInAt: checkedIn ? start.add(const Duration(minutes: 9)) : null,
        ),
      );
    }

    add(
      id: 'evt_101',
      title: 'Build Night',
      topic: 'technology',
      venue: 'Engineering Hall · E204',
      organizer: 'Campus Makers',
      day: 2,
      hour: 16,
      capacity: 40,
      taken: 28,
      description:
          'Meet other makers, form a small team and build a prototype '
          'together. Bring your laptop.',
    );
    add(
      id: 'evt_102',
      title: 'Community Garden Day',
      topic: 'volunteering',
      venue: 'North Lawn',
      organizer: 'Green Campus',
      day: 3,
      hour: 10,
      hours: 3,
      capacity: 25,
      taken: 25,
      waitlistCount: 3,
      description:
          'Help plant, weed and water the campus community garden. Gloves '
          'and snacks are provided.',
    );
    add(
      id: 'evt_103',
      title: 'Design Sprint',
      topic: 'arts',
      venue: 'Studio A',
      organizer: 'Arts Collective',
      day: 2,
      hour: 14,
      hours: 3,
      capacity: 20,
      taken: 12,
      saved: true,
      description:
          'Go from a blank page to a clickable prototype in one afternoon '
          'with a small design team.',
    );
    add(
      id: 'evt_104',
      title: 'Poster Lab',
      topic: 'arts',
      venue: 'Arts Center',
      organizer: 'Arts Collective',
      day: 4,
      hour: 11,
      capacity: 30,
      taken: 12,
      saved: true,
      description:
          'Print, cut and layer your own event poster using the arts '
          'center risograph.',
    );
    add(
      id: 'evt_105',
      title: 'Startup Pitch Night',
      topic: 'careers',
      venue: 'Innovation Hub · Main Hall',
      organizer: 'Career Services',
      day: 5,
      hour: 18,
      capacity: 60,
      taken: 41,
      viewer: ViewerStatus.registered,
      description:
          'Five student teams pitch their ideas to a panel of alumni '
          'founders. Questions welcome.',
    );
    add(
      id: 'evt_106',
      title: 'Campus Fun Run',
      topic: 'sports',
      venue: 'Athletics Track',
      organizer: 'Athletics Club',
      day: 3,
      hour: 8,
      capacity: 50,
      taken: 50,
      waitlistCount: 4,
      viewer: ViewerStatus.waitlisted,
      waitlistPosition: 2,
      description:
          'A relaxed 5 km loop around campus for every pace. Water and '
          'medals at the finish.',
    );
    add(
      id: 'evt_107',
      title: 'Last Seat Lab',
      topic: 'technology',
      venue: 'Lab 3',
      organizer: 'Campus Makers',
      day: 1,
      hour: 15,
      capacity: 15,
      taken: 14,
      lastSeatRace: true,
      description:
          'One seat left! Demo event: another student grabs it while you '
          'confirm, so you can see the "spot was just taken" state.',
    );
    add(
      id: 'evt_108',
      title: 'Spring Career Fair',
      topic: 'careers',
      venue: 'Sports Hall',
      organizer: 'Career Services',
      day: 6,
      hour: 10,
      hours: 5,
      capacity: 200,
      taken: 120,
      status: EventStatus.canceled,
      viewer: ViewerStatus.registered,
      description:
          'Meet employers from across the region. This event was canceled '
          'by the organizer.',
    );
    add(
      id: 'evt_109',
      title: 'Photography Walk',
      topic: 'arts',
      venue: 'Botanical Garden',
      organizer: 'Arts Collective',
      day: -3,
      hour: 9,
      capacity: 25,
      taken: 22,
      status: EventStatus.completed,
      viewer: ViewerStatus.checkedIn,
      checkedIn: true,
      description:
          'Slow down and photograph the garden in morning light. All '
          'cameras and phones welcome.',
    );

    // Filler so Explore has more than one page of results.
    const fillers = [
      ('Intro to Flutter Workshop', 'technology'),
      ('Hack Club Kickoff', 'technology'),
      ('AI Study Group', 'technology'),
      ('Open Source Saturday', 'technology'),
      ('Cybersecurity Basics', 'technology'),
      ('Open Mic Night', 'arts'),
      ('Pottery Studio Session', 'arts'),
      ('Film Club Screening', 'arts'),
      ('Sketch and Chat', 'arts'),
      ('Intramural Volleyball', 'sports'),
      ('Yoga on the Quad', 'sports'),
      ('Climbing Wall Intro', 'sports'),
      ('Pickup Soccer', 'sports'),
      ('Food Bank Shift', 'volunteering'),
      ('Beach Cleanup', 'volunteering'),
      ('Tutoring Night', 'volunteering'),
      ('Resume Review Clinic', 'careers'),
      ('Mock Interview Day', 'careers'),
      ('Alumni Panel', 'careers'),
    ];
    const venues = [
      'Student Union · Room 2',
      'Library Atrium',
      'Science Building · S110',
      'Main Quad',
      'Gym · Court B',
    ];
    const organizers = [
      'Campus Makers',
      'Green Campus',
      'Arts Collective',
      'Career Services',
      'Athletics Club',
    ];
    for (var i = 0; i < fillers.length; i++) {
      final capacity = 20 + (i * 7) % 40;
      add(
        id: 'evt_${120 + i}',
        title: fillers[i].$1,
        topic: fillers[i].$2,
        venue: venues[i % venues.length],
        organizer: organizers[i % organizers.length],
        day: 1 + i % 9,
        hour: 9 + (i * 3) % 10,
        capacity: capacity,
        taken: capacity * (1 + i % 5) ~/ 6,
      );
    }
  }
}

/// Mutable server-side state of one event (the real server keeps this in
/// the database).
class _Record {
  _Record({
    required this.id,
    required this.title,
    required this.description,
    required this.topic,
    required this.venue,
    required this.organizer,
    required this.start,
    required this.end,
    required this.capacity,
    required this.taken,
    required this.status,
    required this.viewer,
    required this.waitlistCount,
    required this.waitlistPosition,
    required this.saved,
    required this.takeLastSeatOnRegister,
    required this.checkedInAt,
  });

  final String id;
  final String title;
  final String description;
  final String topic;
  final String venue;
  final String organizer;
  final DateTime start;
  final DateTime end;
  final int capacity;
  final EventStatus status;
  final DateTime? checkedInAt;

  int taken;
  ViewerStatus viewer;
  int waitlistCount;
  int? waitlistPosition;
  bool saved;
  bool takeLastSeatOnRegister;

  int get remaining => capacity - taken;

  Event toEvent() => Event(
    id: id,
    title: title,
    description: description,
    topic: topic,
    venue: venue,
    startsAt: start,
    endsAt: end,
    capacity: capacity,
    remainingSeats: remaining < 0 ? 0 : remaining,
    status: status,
    viewerStatus: viewer,
    waitlistPosition: waitlistPosition,
    isSaved: saved,
    organizerName: organizer,
    checkedInAt: checkedInAt,
  );
}
