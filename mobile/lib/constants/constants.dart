/// App-wide constants. The API base URL lives here and only here -
/// no widget, service, or provider should ever hardcode a URL.
class AppConstants {
  AppConstants._();

  static const String appName = 'GHOSTLINK';

  /// Base URL for the ResQMesh AI backend, matching the frozen
  /// OpenAPI contract's `/api` prefix. Change this single value to
  /// point the app at a different backend environment.
  static const String baseUrl = "http://10.201.125.24:8000/api";
  static const Duration apiConnectTimeout = Duration(seconds: 10);
  static const Duration apiReceiveTimeout = Duration(seconds: 10);
  static const Duration apiSendTimeout = Duration(seconds: 10);

  static const Duration splashDuration = Duration(seconds: 2);
}
