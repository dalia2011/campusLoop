import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'events_repository.dart';
import 'models/event.dart';
import 'models/event_filters.dart';
import 'models/registration.dart';
import 'models/ticket.dart';

/// Talks to the real backend through [ApiClient].
///
/// Routes follow the spec's endpoint table. Every place where the spec is
/// silent is marked ASSUMPTION so it is easy to find and fix when the Swagger
/// arrives. All of the adjusting happens in this one file.
class ApiEventsRepository extends EventsRepository {
  ApiEventsRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ASSUMPTION: query names q, topic, from, to, cursor come from the spec.
  // `available=true` (spots available only) is NOT in the spec's list.
  @override
  Future<EventPage> listEvents(
    EventFilters filters, {
    String query = '',
    String? cursor,
  }) async {
    final now = DateTime.now();
    final from = filters.from(now);
    final to = filters.to(now);
    final json = await _api.get<Map<String, dynamic>>(
      '/events',
      query: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'topic': ?filters.topic,
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
        if (filters.availableOnly) 'available': true,
        'cursor': ?cursor,
      },
    );
    return _parse(
      () => EventPage(
        items: [
          for (final item in json['items'] as List)
            Event.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      ),
    );
  }

  @override
  Future<Event> getEvent(String id) async {
    final json = await _api.get<Map<String, dynamic>>('/events/$id');
    return _parse(() => Event.fromJson(json));
  }

  // ASSUMPTION: the body `{"joinWaitlist": bool}` and a 409 EVENT_FULL when the
  // event is full and joinWaitlist is false. The spec only says "Reserve or
  // waitlist; Idempotency-Key required; 201 with status".
  @override
  Future<Registration> register(
    String eventId, {
    required String idempotencyKey,
    bool joinWaitlist = false,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/events/$eventId/registrations',
      body: {'joinWaitlist': joinWaitlist},
      idempotencyKey: idempotencyKey,
    );
    notifyChanged();
    return _parse(() => Registration.fromJson(json));
  }

  @override
  Future<void> cancelRegistration(String eventId) async {
    await _api.delete<dynamic>('/events/$eventId/registration');
    notifyChanged();
  }

  @override
  Future<void> saveEvent(String eventId) async {
    await _api.put<dynamic>('/events/$eventId/save');
    notifyChanged();
  }

  @override
  Future<void> unsaveEvent(String eventId) async {
    await _api.delete<dynamic>('/events/$eventId/save');
    notifyChanged();
  }

  // ASSUMPTION: GET /me/events?filter=registered|saved|past returns
  // {"items": [...]}. The spec only lists "GET /v1/me/events".
  @override
  Future<List<Event>> myEvents(MyEventsTab tab) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/me/events',
      query: {'filter': tab.name},
    );
    return _parse(
      () => [
        for (final item in json['items'] as List)
          Event.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  // ASSUMPTION: GET /events/:id/ticket (not listed in the spec's table).
  @override
  Future<Ticket> getTicket(String eventId) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/events/$eventId/ticket',
    );
    return _parse(() => Ticket.fromJson(json));
  }

  /// A response that does not have the expected shape becomes an
  /// [ApiException] instead of a random crash in the UI.
  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'We could not read the server response. Please try again.',
      );
    }
  }
}
