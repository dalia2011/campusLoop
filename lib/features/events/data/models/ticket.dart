/// What a registered student shows at the door.
///
/// [token] is the opaque, signed, expiring string the QR code encodes (never
/// personal details). [code] is the short manual code (e.g. "CL-7K4P9Q") the
/// organizer can type if the camera does not work.
class Ticket {
  const Ticket({
    required this.registrationId,
    required this.eventId,
    required this.token,
    required this.code,
    required this.issuedAt,
    this.expiresAt,
    this.checkedInAt,
  });

  final String registrationId;
  final String eventId;
  final String token;
  final String code;

  /// When this token was fetched (the "last synced" time when offline).
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final DateTime? checkedInAt;

  bool get isCheckedIn => checkedInAt != null;

  // ASSUMPTION: the spec describes the signed token but lists no ticket
  // endpoint. We expect GET /events/:id/ticket to return these fields.
  factory Ticket.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final raw = json[key] as String?;
      return raw == null ? null : DateTime.parse(raw).toUtc();
    }

    return Ticket(
      registrationId: json['registrationId'] as String,
      eventId: json['eventId'] as String,
      token: json['token'] as String,
      code: json['code'] as String,
      issuedAt: date('issuedAt') ?? DateTime.now().toUtc(),
      expiresAt: date('expiresAt'),
      checkedInAt: date('checkedInAt'),
    );
  }
}
