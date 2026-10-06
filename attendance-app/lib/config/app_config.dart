class AppConfig {
  /// Backend base URL. Override at build time: --dart-define=API_BASE_URL=https://api.example.com
  /// The operator can also change it on the sign-in screen (stored on the device).
  static const defaultApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:4000');

  /// The event this build records attendance for. The server validates it.
  static const eventId = String.fromEnvironment('EVENT_ID', defaultValue: 'FLEDGE26');

  /// Ignore re-detections of the same barcode for this long.
  static const scanCooldown = Duration(seconds: 3);

  /// How long the success / duplicate banner stays before the scanner resumes.
  static const successDisplay = Duration(milliseconds: 1600);
  static const duplicateDisplay = Duration(milliseconds: 2600);

  static const requestTimeout = Duration(seconds: 8);
  static const syncInterval = Duration(seconds: 20);
  static const snapshotRefreshInterval = Duration(minutes: 5);
  static const recordsPageSize = 30;
}
