/// Form checks shared by the auth screens. Each returns an error message,
/// or null when the value is fine (this is what Flutter's form fields expect).
class AuthValidators {
  static const minPasswordLength = 12;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your full name.';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your campus email.';
    if (!_emailPattern.hasMatch(text)) return 'Enter a valid email address.';
    return null;
  }

  /// Used when creating an account: enforces the 12 character minimum.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a password.';
    if (value.length < minPasswordLength) {
      return 'Use $minPasswordLength or more characters.';
    }
    return null;
  }

  /// Used when signing in: only checks that something was typed, so we never
  /// hint at the real password rules to someone guessing.
  static String? existingPassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    return null;
  }
}
