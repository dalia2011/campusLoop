/// App-wide settings that can change between machines/environments.
///
/// The API address is NOT hard-coded in the code that makes requests. Instead
/// it is read from a "compile-time define", so you can point the app at a
/// different server without editing code:
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/v1
class AppConfig {
  AppConfig._(); // Private constructor: this class is only a holder of constants.

  /// Base URL of the CampusLoop backend (all routes start with /v1).
  ///
  /// The default `10.0.2.2` is how the Android emulator reaches the computer
  /// it runs on ("localhost" inside the emulator would be the emulator itself).
  /// The iOS simulator can use `http://localhost:3000/v1` instead.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
