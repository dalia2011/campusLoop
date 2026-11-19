/// Lifecycle of an event as decided by the server
/// (draft -> published -> canceled; completed happens automatically).
enum EventStatus {
  draft,
  published,
  canceled,
  completed;

  static EventStatus fromString(String? value) {
    switch (value) {
      case 'draft':
        return EventStatus.draft;
      case 'canceled':
      case 'cancelled':
        return EventStatus.canceled;
      case 'completed':
        return EventStatus.completed;
      default:
        return EventStatus.published;
    }
  }
}

/// What the signed in student's relationship to an event is
/// (the spec's registration state machine, seen from the viewer).
enum ViewerStatus {
  none,
  registered,
  waitlisted,
  checkedIn,
  canceled;

  static ViewerStatus fromString(String? value) {
    switch (value?.replaceAll('_', '').toLowerCase()) {
      case 'registered':
        return ViewerStatus.registered;
      case 'waitlisted':
        return ViewerStatus.waitlisted;
      case 'checkedin':
        return ViewerStatus.checkedIn;
      case 'canceled':
      case 'cancelled':
        return ViewerStatus.canceled;
      default:
        return ViewerStatus.none;
    }
  }
}

/// One event, used for list cards and the detail screen.
///
/// The list endpoint may omit heavy fields (description...); they default to
/// empty and the detail endpoint fills them in.
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.topic,
    required this.venue,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    required this.remainingSeats,
    this.description = '',
    this.status = EventStatus.published,
    this.viewerStatus = ViewerStatus.none,
    this.waitlistPosition,
    this.isSaved = false,
    this.organizerName,
    this.imageUrl,
    this.checkedInAt,
  });

  final String id;
  final String title;
  final String description;

  /// Topic id as the server sends it (e.g. "technology").
  final String topic;

  /// Place text, e.g. "Engineering Hall · E204".
  final String venue;

  /// Times are UTC (the server owns all timestamps). Format with
  /// core/format/date_format.dart to show local time.
  final DateTime startsAt;
  final DateTime endsAt;

  final int capacity;
  final int remainingSeats;
  final EventStatus status;
  final ViewerStatus viewerStatus;

  /// 1 = next in line. Only set while [viewerStatus] is waitlisted.
  final int? waitlistPosition;
  final bool isSaved;
  final String? organizerName;
  final String? imageUrl;
  final DateTime? checkedInAt;

  bool get isFull => remainingSeats <= 0;
  bool get isCanceled => status == EventStatus.canceled;

  /// "technology" -> "Technology"
  String get topicLabel =>
      topic.isEmpty ? '' : topic[0].toUpperCase() + topic.substring(1);

  bool hasEnded(DateTime now) =>
      status == EventStatus.completed || !endsAt.isAfter(now);

  bool hasStarted(DateTime now) => !startsAt.isAfter(now);

  /// Registration is only possible for published events before they start.
  bool registrationOpen(DateTime now) =>
      status == EventStatus.published && startsAt.isAfter(now);

  Event copyWith({
    int? remainingSeats,
    ViewerStatus? viewerStatus,
    int? waitlistPosition,
    bool clearWaitlistPosition = false,
    bool? isSaved,
  }) => Event(
    id: id,
    title: title,
    description: description,
    topic: topic,
    venue: venue,
    startsAt: startsAt,
    endsAt: endsAt,
    capacity: capacity,
    remainingSeats: remainingSeats ?? this.remainingSeats,
    status: status,
    viewerStatus: viewerStatus ?? this.viewerStatus,
    waitlistPosition: clearWaitlistPosition
        ? null
        : (waitlistPosition ?? this.waitlistPosition),
    isSaved: isSaved ?? this.isSaved,
    organizerName: organizerName,
    imageUrl: imageUrl,
    checkedInAt: checkedInAt,
  );

  // ASSUMPTION: field names are camelCase like the spec's JSON examples
  // (id, title, startsAt, remainingSeats, viewerStatus). The rest
  // (organizerName, waitlistPosition, isSaved, checkedInAt) follow the data
  // model in the spec. Confirm against the Swagger and adjust here only.
  factory Event.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final raw = json[key] as String?;
      return raw == null ? null : DateTime.parse(raw).toUtc();
    }

    final starts = date('startsAt')!;
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      topic: (json['topic'] as String? ?? '').toLowerCase(),
      venue: json['venue'] as String? ?? '',
      startsAt: starts,
      endsAt: date('endsAt') ?? starts.add(const Duration(hours: 1)),
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      remainingSeats: (json['remainingSeats'] as num?)?.toInt() ?? 0,
      status: EventStatus.fromString(json['status'] as String?),
      viewerStatus: ViewerStatus.fromString(json['viewerStatus'] as String?),
      waitlistPosition: (json['waitlistPosition'] as num?)?.toInt(),
      isSaved: json['isSaved'] as bool? ?? false,
      organizerName: json['organizerName'] as String?,
      imageUrl: json['imageUrl'] as String?,
      checkedInAt: date('checkedInAt'),
    );
  }
}
