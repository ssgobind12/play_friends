/// Configuration file for Brevo (formerly Sendinblue) transactional email API.
///
/// SECURITY NOTICE:
/// Privileged credentials (API keys, SMTP passwords) are not hardcoded in the
/// Flutter application source code. They are configured via build-time environment
/// variables (--dart-define=BREVO_API_KEY=...) or through a trusted backend API.
class BrevoConfig {
  /// Brevo REST API Key (loaded from environment or secure backend)
  static const String apiKey =
      String.fromEnvironment('BREVO_API_KEY', defaultValue: '');

  /// Verified custom domain in Brevo (critical for SPF/DKIM inbox delivery)
  static const String domain =
      String.fromEnvironment('BREVO_DOMAIN', defaultValue: 'ssgobind.space');

  /// Verified sender using your domain to avoid Gmail SPF/DMARC spam filters
  static const String senderEmail =
      String.fromEnvironment('BREVO_SENDER_EMAIL', defaultValue: 'noreply@ssgobind.space');

  /// Reply-To address so any replies reach your Gmail inbox
  static const String replyToEmail =
      String.fromEnvironment('BREVO_REPLY_TO', defaultValue: 'playgamefriendes@gmail.com');

  /// Display name that appears in the player's inbox
  static const String senderName = 'Play Friends';

  /// Brevo SMTP master password (loaded from environment; never hardcoded)
  static const String smtpPassword =
      String.fromEnvironment('BREVO_SMTP_PASSWORD', defaultValue: '');

  /// Returns true if valid Brevo credentials have been provided
  static bool get isConfigured =>
      apiKey.trim().isNotEmpty &&
      apiKey.startsWith('xkeysib-') &&
      senderEmail.trim().isNotEmpty &&
      senderEmail.contains('@');
}
