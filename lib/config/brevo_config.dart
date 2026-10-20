/// Configuration file for Brevo (formerly Sendinblue) transactional email API.
class BrevoConfig {
  /// Brevo REST API Key
  static String apiKey =
      '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';

  /// Verified custom domain in Brevo (critical for SPF/DKIM inbox delivery)
  static String domain = 'ssgobind.space';

  /// Verified sender using your domain to avoid Gmail SPF/DMARC spam filters
  static String senderEmail = 'noreply@ssgobind.space';

  /// Reply-To address so any replies reach your Gmail inbox
  static String replyToEmail = 'playgamefriendes@gmail.com';

  /// Display name that appears in the player's inbox
  static String senderName = 'Play Friends';

  /// Brevo SMTP master password
  static String smtpPassword = 'bsk5F5pgxUBQZKo';

  /// Returns true if valid Brevo credentials have been provided
  static bool get isConfigured =>
      apiKey.trim().isNotEmpty &&
      apiKey.startsWith('xkeysib-') &&
      senderEmail.trim().isNotEmpty &&
      senderEmail.contains('@');
}
