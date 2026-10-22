/// Configuration for the trusted Play Friends backend API service.
///
/// Handles privileged authentication, scrypt password verification,
/// Brevo transactional email dispatch, and role authorization.
class BackendConfig {
  /// Base URL for the trusted backend API service
  static const String apiBaseUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: 'https://6zsqpcfh9j.execute-api.ap-southeast-2.amazonaws.com',
  );

  /// Optional backend API Gateway API Key for x-api-key header
  static const String apiKey =
      String.fromEnvironment('BACKEND_API_KEY', defaultValue: '');

  /// Returns true if an external backend endpoint URL is configured
  static bool get isConfigured =>
      apiBaseUrl.trim().isNotEmpty && apiBaseUrl.startsWith('http');
}
