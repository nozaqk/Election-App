/// Static app configuration.
class AppConfig {
  /// Display name shown in the app bar and launcher.
  static const String appName = 'Student Election';

  /// Production API base URL (same backend the web app used).
  static const String apiBase =
      'https://students-election-system.onrender.com';

  /// Android application id / MethodChannel namespace.
  static const String appId = 'com.studentelection.vote';

  /// How often overview / election detail feeds are refreshed.
  static const Duration pollInterval = Duration(seconds: 10);

  /// Session lifetime granted by the backend (11 hours).
  static const Duration sessionLifetime = Duration(hours: 11);
}
