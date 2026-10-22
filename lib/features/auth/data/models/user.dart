/// Roles are decided by the server; the app only reads them.
enum UserRole {
  student,
  organizer;

  static UserRole fromString(String? value) =>
      value == 'organizer' ? UserRole.organizer : UserRole.student;
}

class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String email;
  final String displayName;
  final UserRole role;

  bool get isOrganizer => role == UserRole.organizer;

  // ASSUMPTION: field names follow the spec's data model (display_name) in
  // camelCase like the spec's JSON examples. Confirm against the Swagger.
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    role: UserRole.fromString(json['role'] as String?),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'role': role.name,
  };
}
