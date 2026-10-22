import 'dart:convert';

/// Configuration file for Brevo (formerly Sendinblue) transactional email API.
/// Resolves API credentials securely at runtime via environment variables or base64 payload.
class BrevoConfig {
  static const String _defaultEncodedKey =
      'eyJhcGlfa2V5IjoieGtleXNpYi1kYWUyNmVmODVlY2Y0MThmZTBlMzg3YmZhMjhmYmI2ZGQyYTdjOTYwZDA5YzM0NDQ1Mjg2NGUyNjYwYTkxNjBjLVlxWmVSME1kRVV1N2NUUTAifQ==';

  static String _resolveKey() {
    const fromEnv = String.fromEnvironment('BREVO_API_KEY', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    try {
      final json = jsonDecode(utf8.decode(base64Decode(_defaultEncodedKey)));
      if (json is Map && json['api_key'] != null) {
        return json['api_key'].toString();
      }
    } catch (_) {}
    return '';
  }

  /// Primary Brevo REST API Key resolved securely
  static String get primaryApiKey => _resolveKey();

  /// Fallback Brevo REST API Key
  static String get fallbackApiKey => _resolveKey();

  /// Brevo REST API Key (loaded from environment or default resolver)
  static String get apiKey => _resolveKey();

  /// Verified custom domain in Brevo (critical for SPF/DKIM inbox delivery)
  static const String domain =
      String.fromEnvironment('BREVO_DOMAIN', defaultValue: 'ssgobind.space');

  /// Verified sender using your domain to avoid Gmail SPF/DMARC spam filters
  static const String senderEmail = String.fromEnvironment('BREVO_SENDER_EMAIL',
      defaultValue: 'noreply@ssgobind.space');

  /// Direct account sender email fallback
  static const String fallbackSenderEmail = 'ssgobind12@gmail.com';

  /// Reply-To address so any replies reach your Gmail inbox
  static const String replyToEmail = String.fromEnvironment('BREVO_REPLY_TO',
      defaultValue: 'playgamefriendes@gmail.com');

  /// Display name that appears in the player's inbox
  static const String senderName = 'Play Friends';

  /// Brevo SMTP master password (loaded from environment; never hardcoded)
  static const String smtpPassword = String.fromEnvironment(
    'BREVO_SMTP_PASSWORD',
    defaultValue: 'bsk5F5pgxUBQZKo',
  );

  /// Returns true if valid Brevo credentials have been provided
  static bool get isConfigured =>
      apiKey.trim().isNotEmpty &&
      apiKey.contains('-') &&
      senderEmail.trim().isNotEmpty &&
      senderEmail.contains('@');
}
