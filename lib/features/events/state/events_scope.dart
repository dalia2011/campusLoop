import 'package:flutter/widgets.dart';

import '../data/events_repository.dart';

/// Makes the [EventsRepository] available to every screen below it:
///
///   final repository = EventsScope.read(context);
///
/// Screens never create repositories themselves, so the app (or a test) decides
/// whether they talk to the mock or the real backend.
class EventsScope extends InheritedWidget {
  const EventsScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final EventsRepository repository;

  static EventsRepository read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<EventsScope>();
    assert(scope != null, 'No EventsScope found above this widget.');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(EventsScope oldWidget) =>
      repository != oldWidget.repository;
}
