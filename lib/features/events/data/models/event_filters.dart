/// Topics from the spec. The id is what the API receives (`topic=technology`).
const kTopics = ['technology', 'arts', 'sports', 'volunteering', 'careers'];

String topicLabel(String id) =>
    id.isEmpty ? id : id[0].toUpperCase() + id.substring(1);

enum DatePreset { today, thisWeek, custom }

const _unset = Object();

/// The Explore filters (topic, date, availability). The search text is kept
/// separately so typing never rebuilds this object.
class EventFilters {
  const EventFilters({
    this.topic,
    this.datePreset,
    this.customFrom,
    this.customTo,
    this.availableOnly = false,
  });

  static const none = EventFilters();

  final String? topic;
  final DatePreset? datePreset;

  /// Only used when [datePreset] is [DatePreset.custom].
  final DateTime? customFrom;
  final DateTime? customTo;
  final bool availableOnly;

  bool get hasDate => datePreset != null;
  bool get isActive => topic != null || hasDate || availableOnly;

  /// Number shown on the Filters button.
  int get activeCount =>
      (topic != null ? 1 : 0) + (hasDate ? 1 : 0) + (availableOnly ? 1 : 0);

  /// Start of the date window in LOCAL time (null = no lower bound).
  DateTime? from(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (datePreset) {
      case DatePreset.today:
      case DatePreset.thisWeek:
        return today;
      case DatePreset.custom:
        final f = customFrom;
        return f == null ? null : DateTime(f.year, f.month, f.day);
      case null:
        return null;
    }
  }

  /// End of the date window in LOCAL time (null = no upper bound).
  /// "This week" runs until the end of Sunday.
  DateTime? to(DateTime now) {
    DateTime endOfDay(DateTime d) =>
        DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
    switch (datePreset) {
      case DatePreset.today:
        return endOfDay(now);
      case DatePreset.thisWeek:
        return endOfDay(
          DateTime(
            now.year,
            now.month,
            now.day + (DateTime.sunday - now.weekday),
          ),
        );
      case DatePreset.custom:
        final t = customTo ?? customFrom;
        return t == null ? null : endOfDay(t);
      case null:
        return null;
    }
  }

  /// Pass [topic]/[datePreset] as null explicitly to clear them.
  EventFilters copyWith({
    Object? topic = _unset,
    Object? datePreset = _unset,
    Object? customFrom = _unset,
    Object? customTo = _unset,
    bool? availableOnly,
  }) => EventFilters(
    topic: identical(topic, _unset) ? this.topic : topic as String?,
    datePreset: identical(datePreset, _unset)
        ? this.datePreset
        : datePreset as DatePreset?,
    customFrom: identical(customFrom, _unset)
        ? this.customFrom
        : customFrom as DateTime?,
    customTo: identical(customTo, _unset)
        ? this.customTo
        : customTo as DateTime?,
    availableOnly: availableOnly ?? this.availableOnly,
  );

  @override
  bool operator ==(Object other) =>
      other is EventFilters &&
      other.topic == topic &&
      other.datePreset == datePreset &&
      other.customFrom == customFrom &&
      other.customTo == customTo &&
      other.availableOnly == availableOnly;

  @override
  int get hashCode =>
      Object.hash(topic, datePreset, customFrom, customTo, availableOnly);
}
