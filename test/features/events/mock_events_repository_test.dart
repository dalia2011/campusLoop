import 'package:campus_loop/core/network/api_exception.dart';
import 'package:campus_loop/features/events/data/events_repository.dart';
import 'package:campus_loop/features/events/data/mock_events_repository.dart';
import 'package:campus_loop/features/events/data/models/event.dart';
import 'package:campus_loop/features/events/data/models/event_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockEventsRepository repo;

  setUp(() => repo = MockEventsRepository(latency: Duration.zero));

  Future<ApiException> failureOf(Future<Object?> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      return e;
    }
    fail('Expected an ApiException');
  }

  group('listing, search and filters', () {
    test('pages 20 at a time without repeating events', () async {
      final first = await repo.listEvents(EventFilters.none);
      expect(first.items, hasLength(kEventsPageSize));
      expect(first.nextCursor, isNotNull);

      final second = await repo.listEvents(
        EventFilters.none,
        cursor: first.nextCursor,
      );
      expect(second.items, isNotEmpty);
      expect(second.nextCursor, isNull);

      final ids = [...first.items, ...second.items].map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('only lists published, upcoming events, soonest first', () async {
      final first = await repo.listEvents(EventFilters.none);
      final second = await repo.listEvents(
        EventFilters.none,
        cursor: first.nextCursor,
      );
      final all = [...first.items, ...second.items];
      expect(all.every((e) => e.status == EventStatus.published), isTrue);
      expect(
        all.any((e) => e.title == 'Spring Career Fair'),
        isFalse,
      ); // canceled
      expect(
        all.any((e) => e.title == 'Photography Walk'),
        isFalse,
      ); // completed
      for (var i = 1; i < all.length; i++) {
        expect(all[i].startsAt.isBefore(all[i - 1].startsAt), isFalse);
      }
    });

    test('search matches title and description, ignoring case', () async {
      final byTitle = await repo.listEvents(
        EventFilters.none,
        query: 'build NIGHT',
      );
      expect(byTitle.items.map((e) => e.title), contains('Build Night'));

      // "risograph" only appears in Poster Lab's description.
      final byDescription = await repo.listEvents(
        EventFilters.none,
        query: 'risograph',
      );
      expect(byDescription.items.map((e) => e.title), ['Poster Lab']);
    });

    test('topic, date and availability filters compose', () async {
      final arts = await repo.listEvents(const EventFilters(topic: 'arts'));
      expect(arts.items, isNotEmpty);
      expect(arts.items.every((e) => e.topic == 'arts'), isTrue);

      final artsAvailable = await repo.listEvents(
        const EventFilters(topic: 'arts', availableOnly: true),
        query: 'poster',
      );
      expect(artsAvailable.items.map((e) => e.title), ['Poster Lab']);

      final today = await repo.listEvents(
        const EventFilters(datePreset: DatePreset.today),
      );
      final now = DateTime.now();
      for (final e in today.items) {
        final local = e.startsAt.toLocal();
        expect(
          DateTime(local.year, local.month, local.day),
          DateTime(now.year, now.month, now.day),
        );
      }

      final none = await repo.listEvents(
        const EventFilters(topic: 'sports'),
        query: 'zzzz-no-match',
      );
      expect(none.items, isEmpty);
      expect(none.nextCursor, isNull);
    });

    test('availableOnly hides full events', () async {
      final all = await repo.listEvents(
        const EventFilters(availableOnly: true),
        query: 'community garden',
      );
      expect(all.items, isEmpty);
      final withFull = await repo.listEvents(
        EventFilters.none,
        query: 'community garden',
      );
      expect(withFull.items, hasLength(1));
    });
  });

  group('registration', () {
    test('an available seat creates one registration', () async {
      final before = await repo.getEvent('evt_101');
      final result = await repo.register('evt_101', idempotencyKey: 'k1');
      final after = await repo.getEvent('evt_101');

      expect(result.status, ViewerStatus.registered);
      expect(after.viewerStatus, ViewerStatus.registered);
      expect(after.remainingSeats, before.remainingSeats - 1);
    });

    test('the same idempotency key never registers twice', () async {
      final first = await repo.register('evt_101', idempotencyKey: 'same');
      final again = await repo.register('evt_101', idempotencyKey: 'same');
      final event = await repo.getEvent('evt_101');

      expect(again.id, first.id);
      expect(event.remainingSeats, 11); // 12 left, minus ONE registration
    });

    test(
      'a different key for an event you already joined is a conflict',
      () async {
        await repo.register('evt_101', idempotencyKey: 'a');
        final error = await failureOf(
          () => repo.register('evt_101', idempotencyKey: 'b'),
        );
        expect(error.type, ApiErrorType.conflict);
        expect(error.code, 'ALREADY_REGISTERED');
      },
    );

    test(
      'a full event refuses a normal registration with EVENT_FULL',
      () async {
        final error = await failureOf(
          () => repo.register('evt_102', idempotencyKey: 'k'),
        );
        expect(error.code, 'EVENT_FULL');
        expect(
          error.message,
          'That spot was just taken. You can join the waitlist.',
        );
      },
    );

    test('joining the waitlist goes to the back of the line', () async {
      final result = await repo.register(
        'evt_102',
        idempotencyKey: 'k',
        joinWaitlist: true,
      );
      expect(result.status, ViewerStatus.waitlisted);
      expect(result.queuePosition, 4); // 3 students were already waiting

      final event = await repo.getEvent('evt_102');
      expect(event.viewerStatus, ViewerStatus.waitlisted);
      expect(event.waitlistPosition, 4);
    });

    test('someone can take the last seat while you confirm', () async {
      final error = await failureOf(
        () => repo.register('evt_107', idempotencyKey: 'k1'),
      );
      expect(error.code, 'EVENT_FULL');

      final result = await repo.register(
        'evt_107',
        idempotencyKey: 'k2',
        joinWaitlist: true,
      );
      expect(result.status, ViewerStatus.waitlisted);
    });

    test('canceled and finished events refuse registrations', () async {
      for (final id in ['evt_108', 'evt_109']) {
        final error = await failureOf(
          () => repo.register(id, idempotencyKey: id),
        );
        expect(error.code, 'EVENT_CLOSED');
      }
    });
  });

  group('cancel', () {
    test(
      'cancelling a place promotes the next student, not the same seat',
      () async {
        // Startup Pitch Night: registered, 41 of 60 taken.
        await repo.cancelRegistration('evt_105');
        final event = await repo.getEvent('evt_105');
        expect(event.viewerStatus, ViewerStatus.canceled);
        expect(event.remainingSeats, 60 - 40);
      },
    );

    test(
      'a full event keeps the seat for the waitlist when you cancel',
      () async {
        await repo.register('evt_101', idempotencyKey: 'x'); // 11 left
        await repo.cancelRegistration('evt_101');
        expect((await repo.getEvent('evt_101')).remainingSeats, 12);
      },
    );

    test('leaving the waitlist frees the spot in line', () async {
      await repo.cancelRegistration('evt_106'); // waitlisted, position 2
      final event = await repo.getEvent('evt_106');
      expect(event.viewerStatus, ViewerStatus.canceled);
      expect(event.waitlistPosition, isNull);
    });

    test('cancelling without a registration is not found', () async {
      final error = await failureOf(() => repo.cancelRegistration('evt_103'));
      expect(error.type, ApiErrorType.notFound);
    });

    test('the student can register again after cancelling', () async {
      await repo.cancelRegistration('evt_105');
      final result = await repo.register('evt_105', idempotencyKey: 'again');
      expect(result.status, ViewerStatus.registered);
    });
  });

  group('saved events, My Events and tickets', () {
    test('saving and unsaving', () async {
      await repo.saveEvent('evt_101');
      expect((await repo.getEvent('evt_101')).isSaved, isTrue);
      await repo.unsaveEvent('evt_101');
      expect((await repo.getEvent('evt_101')).isSaved, isFalse);
    });

    test('the three tabs are distinct', () async {
      final registered = await repo.myEvents(MyEventsTab.registered);
      final saved = await repo.myEvents(MyEventsTab.saved);
      final past = await repo.myEvents(MyEventsTab.past);

      expect(
        registered.map((e) => e.id),
        unorderedEquals(['evt_105', 'evt_106']),
      );
      expect(saved.map((e) => e.id), unorderedEquals(['evt_103', 'evt_104']));
      expect(past.map((e) => e.id), unorderedEquals(['evt_108', 'evt_109']));
      expect(past.firstWhere((e) => e.id == 'evt_108').isCanceled, isTrue);
      expect(
        past.firstWhere((e) => e.id == 'evt_109').viewerStatus,
        ViewerStatus.checkedIn,
      );
    });

    test('a registered student gets a ticket whose token changes', () async {
      final a = await repo.getTicket('evt_105');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final b = await repo.getTicket('evt_105');
      expect(a.code, startsWith('CL-'));
      expect(a.code, b.code);
      expect(a.token, isNot(b.token));
    });

    test('no ticket without a registration', () async {
      final error = await failureOf(() => repo.getTicket('evt_103'));
      expect(error.code, 'NO_TICKET');
    });

    test('checked in tickets carry the check in time', () async {
      final ticket = await repo.getTicket('evt_109');
      expect(ticket.isCheckedIn, isTrue);
    });
  });

  group('changes and offline', () {
    test('writes notify listeners so screens can refresh', () async {
      var notified = 0;
      repo.changes.addListener(() => notified++);
      await repo.register('evt_101', idempotencyKey: 'k');
      await repo.saveEvent('evt_103');
      await repo.cancelRegistration('evt_101');
      expect(notified, 3);
    });

    test('offline fails every call with a network error', () async {
      repo.offline = true;
      final error = await failureOf(() => repo.listEvents(EventFilters.none));
      expect(error.isOffline, isTrue);
      expect(
        (await failureOf(() => repo.getEvent('evt_101'))).isOffline,
        isTrue,
      );
    });
  });
}
