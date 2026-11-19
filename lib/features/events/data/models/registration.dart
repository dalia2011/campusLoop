import 'event.dart';

/// Result of "reserve a spot" / "join waitlist".
///
/// Matches the spec example:
///   201 {"id":"reg_417","status":"registered","eventId":"evt_104",
///        "ticketAvailable":true,"updatedAt":"..."}
class Registration {
  const Registration({
    required this.id,
    required this.eventId,
    required this.status,
    this.queuePosition,
    this.ticketAvailable = false,
  });

  final String id;
  final String eventId;

  /// registered or waitlisted.
  final ViewerStatus status;

  /// Only for waitlisted registrations (1 = next in line).
  final int? queuePosition;
  final bool ticketAvailable;

  bool get isWaitlisted => status == ViewerStatus.waitlisted;

  factory Registration.fromJson(Map<String, dynamic> json) => Registration(
    id: json['id'] as String,
    eventId: json['eventId'] as String,
    status: ViewerStatus.fromString(json['status'] as String?),
    queuePosition: (json['queuePosition'] as num?)?.toInt(),
    ticketAvailable: json['ticketAvailable'] as bool? ?? false,
  );
}
