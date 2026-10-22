/// PrivacyFilterService: Prevents sharing of sensitive personal details
/// (phone numbers, WhatsApp, Instagram, Facebook, Telegram, Snapchat, emails, external IDs)
/// to ensure user security and anti-scam protection.
class PrivacyCheckResult {
  final bool isAllowed;
  final String? reason;
  final String? matchedType;

  const PrivacyCheckResult({
    required this.isAllowed,
    this.reason,
    this.matchedType,
  });
}

class PrivacyFilterService {
  // Regex to detect phone numbers with optional country codes, spaces, dots, or dashes
  // e.g., "8573029430", "+91 85730 29430", "9876-543-210", "9 8 7 6 5 4 3 2 1 0"
  static final RegExp _phoneNumberRegex = RegExp(
    r'(\+?\d{1,4}[\s\-\.]?)?(\(?\d{2,5}\)?[\s\-\.]?)?\d{3,5}[\s\-\.]?\d{3,5}',
  );

  // Regex for normalized continuous digits of length 8 or more
  static final RegExp _digitSequenceRegex = RegExp(r'\d{8,}');

  // Regex for email addresses
  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  // Keywords and patterns for social media handles and personal IDs
  static final List<Map<String, dynamic>> _socialPatterns = [
    {
      'type': 'Instagram',
      'regex': RegExp(
          r'\b(instagram|insta\s*id|ig\s*id|ig\s*:|@[\w\.-]+|insta)\b',
          caseSensitive: false),
    },
    {
      'type': 'Facebook',
      'regex': RegExp(r'\b(facebook|fb\s*id|fb\s*:|fb\.com|facebook\.com)\b',
          caseSensitive: false),
    },
    {
      'type': 'WhatsApp',
      'regex': RegExp(r'\b(whatsapp|wa\.me|whats\s*app|wp\s*no|wa\s*no)\b',
          caseSensitive: false),
    },
    {
      'type': 'Telegram',
      'regex':
          RegExp(r'\b(telegram|t\.me|tg\s*id|tg\s*:)\b', caseSensitive: false),
    },
    {
      'type': 'Snapchat',
      'regex':
          RegExp(r'\b(snapchat|snap\s*id|snap\s*:)\b', caseSensitive: false),
    },
    {
      'type': 'External Link',
      'regex': RegExp(r'(https?:\/\/|www\.)[^\s]+', caseSensitive: false),
    },
  ];

  /// Checks if a chat message or room text violates privacy & safety policies.
  static PrivacyCheckResult checkMessage(String text) {
    final clean = text.trim();
    if (clean.isEmpty) {
      return const PrivacyCheckResult(isAllowed: true);
    }

    // 1. Check for email
    if (_emailRegex.hasMatch(clean)) {
      return const PrivacyCheckResult(
        isAllowed: false,
        reason:
            'Security Alert: Sharing personal email addresses is prohibited for your safety.',
        matchedType: 'Email Address',
      );
    }

    // 2. Check for phone number (strip whitespace and common separators)
    final digitsOnly = clean.replaceAll(RegExp(r'[^0-9]'), '');
    if (_digitSequenceRegex.hasMatch(digitsOnly) && digitsOnly.length >= 8) {
      return const PrivacyCheckResult(
        isAllowed: false,
        reason:
            'Security Alert: Sharing mobile or phone numbers is strictly prohibited to prevent scams.',
        matchedType: 'Phone Number',
      );
    }

    if (_phoneNumberRegex.hasMatch(clean) && digitsOnly.length >= 8) {
      return const PrivacyCheckResult(
        isAllowed: false,
        reason:
            'Security Alert: Sharing mobile or phone numbers is strictly prohibited to prevent scams.',
        matchedType: 'Phone Number',
      );
    }

    // 3. Check for social media handles and IDs
    for (final pattern in _socialPatterns) {
      final reg = pattern['regex'] as RegExp;
      final type = pattern['type'] as String;
      if (reg.hasMatch(clean)) {
        return PrivacyCheckResult(
          isAllowed: false,
          reason:
              'Security Alert: Sharing $type IDs, handles, or links is prohibited.',
          matchedType: type,
        );
      }
    }

    return const PrivacyCheckResult(isAllowed: true);
  }
}
