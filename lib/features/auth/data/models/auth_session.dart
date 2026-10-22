import 'user.dart';

/// What the server returns after a successful register or login.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final User user;

  // ASSUMPTION: {"accessToken","refreshToken","user":{...}}. The spec lists the
  // auth routes but not their response bodies. Confirm against the Swagger.
  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    user: User.fromJson(json['user'] as Map<String, dynamic>),
  );
}
