import 'package:campus_loop/core/network/api_client.dart';
import 'package:campus_loop/core/network/token_storage.dart';
import 'package:campus_loop/features/auth/data/mock_auth_repository.dart';
import 'package:campus_loop/features/auth/state/auth_controller.dart';
import 'package:campus_loop/features/events/data/mock_events_repository.dart';
import 'package:campus_loop/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Phone-sized widget tests for the student event journeys, run against the
/// mock repository with zero latency.
Future<MockEventsRepository> pumpSignedIn(
  WidgetTester tester, {
  bool offline = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final storage = MemoryTokenStorage();
  final authRepo = MockAuthRepository(
    tokenStorage: storage,
    latency: Duration.zero,
  );
  await authRepo.login(
    email: 'student@campus.edu',
    password: MockAuthRepository.demoPassword,
  );
  final auth = AuthController(authRepo)..restore();
  final events = MockEventsRepository(latency: Duration.zero)
    ..offline = offline;

  await tester.pumpWidget(
    CampusLoopApp(
      apiClient: ApiClient(tokenStorage: storage),
      auth: auth,
      events: events,
    ),
  );
  await tester.pumpAndSettle();
  return events;
}

Finder tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// Types in the search field and waits for the results. pumpAndSettle alone
/// is not enough: a pending Timer (the 300 ms debounce) schedules no frame, so
/// the clock has to be moved forward explicitly.
Future<void> typeQuery(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

/// Opens Search from Explore, types [query] and opens the [title] result.
Future<void> searchAndOpen(
  WidgetTester tester,
  String query,
  String title,
) async {
  await tester.tap(find.text('Search events or topics'));
  await tester.pumpAndSettle();
  await typeQuery(tester, query);
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Explore shows the feed with search, topics and filters', (
    tester,
  ) async {
    await pumpSignedIn(tester);
    expect(find.text('Find your next campus moment.'), findsOneWidget);
    expect(find.text('Search events or topics'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Last Seat Lab'), findsOneWidget); // soonest event
  });

  testWidgets('reserve a spot: detail, confirm, success and ticket', (
    tester,
  ) async {
    final repo = await pumpSignedIn(tester);
    await searchAndOpen(tester, 'build night', 'Build Night');

    expect(find.text('12 of 40 seats left'), findsOneWidget);
    await tester.tap(find.text('Reserve my spot'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm your place'), findsOneWidget);
    expect(find.text('No payment required'), findsOneWidget);
    await tester.tap(find.text('Confirm registration'));
    await tester.pumpAndSettle();

    expect(find.text('You’re going!'), findsOneWidget);
    expect((await repo.getEvent('evt_101')).remainingSeats, 11);

    await tester.tap(find.text('View ticket'));
    await tester.pumpAndSettle();
    expect(find.text('Your ticket'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('CL-'), findsOneWidget);
  });

  testWidgets('full event: join the waitlist from the detail screen', (
    tester,
  ) async {
    await pumpSignedIn(tester);
    await searchAndOpen(tester, 'community garden', 'Community Garden Day');

    expect(find.textContaining('All 25 spots are taken'), findsOneWidget);
    await tester.tap(find.text('Join waitlist'));
    await tester.pumpAndSettle();

    expect(
      find.text('You are on the waitlist. Your position is 4.'),
      findsOneWidget,
    );
    expect(find.text('Leave waitlist'), findsOneWidget);
  });

  testWidgets('the last seat is taken while confirming: offered the waitlist', (
    tester,
  ) async {
    await pumpSignedIn(tester);
    await searchAndOpen(tester, 'last seat', 'Last Seat Lab');

    await tester.tap(find.text('Reserve my spot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm registration'));
    await tester.pumpAndSettle();

    expect(
      find.text('That spot was just taken. You can join the waitlist.'),
      findsOneWidget,
    );
    expect(find.text('Confirm registration'), findsNothing);

    await tester.tap(find.text('Join waitlist'));
    await tester.pumpAndSettle();

    // Back on the detail screen, now waitlisted.
    expect(find.text('Leave waitlist'), findsOneWidget);
  });

  testWidgets('search with no matches shows the empty state and clears', (
    tester,
  ) async {
    await pumpSignedIn(tester);
    await tester.tap(find.text('Search events or topics'));
    await tester.pumpAndSettle();
    await typeQuery(tester, 'zzzzqqqq');

    expect(find.text('Nothing matched'), findsOneWidget);
    expect(
      find.textContaining('No events match these filters.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing matched'), findsNothing);
    expect(find.text('Recent searches'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('recent searches are remembered', (tester) async {
    await pumpSignedIn(tester);
    await tester.tap(find.text('Search events or topics'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'poster');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('poster'), findsOneWidget);
  });

  testWidgets('filters sheet applies a topic and Filters shows the count', (
    tester,
  ) async {
    await pumpSignedIn(tester);
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Filter events'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sports').last);
    await tester.tap(find.text('Spots available'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show events'));
    await tester.pumpAndSettle();

    expect(find.text('Filters (2)'), findsOneWidget);
    expect(find.text('Intramural Volleyball'), findsOneWidget);
    expect(find.text('Last Seat Lab'), findsNothing);
  });

  testWidgets('filters survive opening an event and coming back', (
    tester,
  ) async {
    await pumpSignedIn(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Arts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Design Sprint'));
    await tester.pumpAndSettle();
    expect(find.text('Event details'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    final arts = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Arts'),
    );
    expect(arts.selected, isTrue);
    expect(find.text('Design Sprint'), findsOneWidget);
    expect(find.text('Last Seat Lab'), findsNothing);
  });

  testWidgets('offline Explore shows a retry that recovers', (tester) async {
    final repo = await pumpSignedIn(tester, offline: true);
    expect(find.text('You are offline'), findsOneWidget);

    repo.offline = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('You are offline'), findsNothing);
    expect(find.text('Last Seat Lab'), findsOneWidget);
  });

  testWidgets('My Events: registered, saved and past tabs', (tester) async {
    await pumpSignedIn(tester);
    await tester.tap(tab('My Events'));
    await tester.pumpAndSettle();

    // Registered: a place and a waitlist spot.
    expect(find.text('Startup Pitch Night'), findsOneWidget);
    expect(find.text('Campus Fun Run'), findsOneWidget);
    expect(find.text('Waitlisted · Position 2'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Design Sprint'), findsOneWidget);
    expect(find.text('Poster Lab'), findsOneWidget);
    expect(find.text('Startup Pitch Night'), findsNothing);

    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    expect(find.text('Photography Walk'), findsOneWidget);
    expect(find.text('Checked in'), findsOneWidget);
    expect(find.text('Spring Career Fair'), findsOneWidget);
    expect(find.text('Canceled'), findsOneWidget);
  });

  testWidgets('unsaving from the Saved tab removes the event', (tester) async {
    await pumpSignedIn(tester);
    await tester.tap(tab('My Events'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove Poster Lab from saved'));
    await tester.pumpAndSettle();

    expect(find.text('Poster Lab'), findsNothing);
    expect(find.text('Design Sprint'), findsOneWidget);
  });

  testWidgets('cancel a registration from the ticket', (tester) async {
    await pumpSignedIn(tester);
    await tester.tap(tab('My Events'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Startup Pitch Night'));
    await tester.pumpAndSettle();

    expect(find.text('Your ticket'), findsOneWidget);
    await tester.tap(find.text('Cancel registration'));
    await tester.pumpAndSettle();

    // The confirmation sheet (design 19).
    expect(find.text('Cancel registration?'), findsOneWidget);
    await tester.tap(find.text('Keep my place'));
    await tester.pumpAndSettle();
    expect(find.text('Your ticket'), findsOneWidget);

    await tester.tap(find.text('Cancel registration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, cancel my place'));
    await tester.pumpAndSettle();

    expect(find.text('Your registration was canceled.'), findsOneWidget);
    expect(find.text('Startup Pitch Night'), findsNothing);
  });

  testWidgets('leave the waitlist from the waitlist screen', (tester) async {
    await pumpSignedIn(tester);
    await tester.tap(tab('My Events'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Campus Fun Run'));
    await tester.pumpAndSettle();

    expect(find.text('Your current position'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Leave waitlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, leave waitlist'));
    await tester.pumpAndSettle();

    expect(find.text('You left the waitlist.'), findsOneWidget);
    expect(find.text('Campus Fun Run'), findsNothing);
  });
}
