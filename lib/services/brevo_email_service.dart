import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/brevo_config.dart';

class EmailSendResult {
  final bool success;
  final String message;
  final String? messageId;
  final bool usedBrevoLiveApi;

  const EmailSendResult({
    required this.success,
    required this.message,
    this.messageId,
    this.usedBrevoLiveApi = false,
  });
}

class BrevoEmailService {
  static const String _brevoSmtpEndpoint = 'https://api.brevo.com/v3/smtp/email';

  /// Sends a 6-digit OTP email via Brevo transactional API with full inbox deliverability features:
  /// - Custom domain sender (SPF/DKIM alignment)
  /// - Multipart MIME (both textContent and htmlContent)
  /// - Reply-To header pointing to user Gmail
  /// - Transactional tags and pre-header optimization
  static Future<EmailSendResult> sendOtpEmail({
    required String recipientEmail,
    required String recipientName,
    required String otpCode,
    required String purpose, // 'registration' or 'forgot_password'
  }) async {
    final isRegistration = purpose == 'registration';
    final name = recipientName.trim().isNotEmpty ? recipientName.trim() : 'Player';

    // Spam-safe natural subject line (avoids spam filter trigger words)
    final subject = isRegistration
        ? 'Your Play Friends verification code is $otpCode'
        : 'Your Play Friends password reset code is $otpCode';

    final htmlContent = _buildHtmlEmail(
      recipientName: name,
      otpCode: otpCode,
      isRegistration: isRegistration,
    );

    final textContent = _buildTextEmail(
      recipientName: name,
      otpCode: otpCode,
      isRegistration: isRegistration,
    );

    // If Brevo API key is not configured, handle safely (never falsely claim success in release)
    if (!BrevoConfig.isConfigured) {
      if (kDebugMode) {
        debugPrint(
          '[DEV MODE] Brevo API is not configured via --dart-define. Simulated delivery for testing: $otpCode -> $recipientEmail',
        );
        return const EmailSendResult(
          success: true,
          message: 'Local development simulation active (Brevo API key not provided).',
          usedBrevoLiveApi: false,
        );
      }
      return const EmailSendResult(
        success: false,
        message: 'Transactional email service is not configured on this client.',
        usedBrevoLiveApi: false,
      );
    }

    try {
      final payload = {
        'sender': {
          'name': BrevoConfig.senderName,
          'email': BrevoConfig.senderEmail.trim(),
        },
        'to': [
          {
            'email': recipientEmail.trim(),
            'name': name,
          }
        ],
        if (BrevoConfig.replyToEmail.trim().isNotEmpty)
          'replyTo': {
            'email': BrevoConfig.replyToEmail.trim(),
            'name': '${BrevoConfig.senderName} Support',
          },
        'subject': subject,
        'htmlContent': htmlContent,
        'textContent': textContent,
        'tags': ['otp', 'transactional', isRegistration ? 'registration' : 'password-reset'],
        'headers': {
          'X-Mailin-Tag': 'otp-verification',
          'X-Entity-Ref-ID': 'pf-${DateTime.now().millisecondsSinceEpoch}',
        },
      };

      final response = await http.post(
        Uri.parse(_brevoSmtpEndpoint),
        headers: {
          'accept': 'application/json',
          'api-key': BrevoConfig.apiKey.trim(),
          'content-type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final messageId = data['messageId'] as String?;
        return EmailSendResult(
          success: true,
          message: 'Real verification email sent to $recipientEmail via Brevo!',
          messageId: messageId,
          usedBrevoLiveApi: true,
        );
      } else {
        String errorDetail = 'Status ${response.statusCode}';
        try {
          final errJson = jsonDecode(response.body);
          if (errJson is Map && errJson.containsKey('message')) {
            errorDetail = errJson['message'].toString();
          }
        } catch (_) {
          errorDetail = response.body;
        }

        if (kDebugMode) {
          debugPrint('Brevo API delivery error: $errorDetail');
        }

        return EmailSendResult(
          success: false,
          message: 'Brevo delivery issue: $errorDetail',
          usedBrevoLiveApi: true,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Network error sending via Brevo: $e');
      }
      return EmailSendResult(
        success: false,
        message: 'Could not connect to Brevo API: $e',
        usedBrevoLiveApi: true,
      );
    }
  }

  /// Builds plain text email fallback (required by spam filters to avoid spam penalty)
  static String _buildTextEmail({
    required String recipientName,
    required String otpCode,
    required bool isRegistration,
  }) {
    final action = isRegistration ? 'complete your registration' : 'reset your password';
    return '''
Play Friends - Verification Code

Hello $recipientName,

Your one-time 6-digit verification code to $action is:

$otpCode

This code is valid for 10 minutes only.
For your security, do not share this code with anyone.

If you did not request this verification, you can safely ignore this email.

Best regards,
Play Friends Gaming Team
https://ssgobind.space
''';
  }

  /// Builds modern gaming-themed responsive HTML email with preheader and anti-spam compliance
  static String _buildHtmlEmail({
    required String recipientName,
    required String otpCode,
    required bool isRegistration,
  }) {
    final title = isRegistration ? 'Verify Your Play Friends Account' : 'Reset Your Play Friends Password';
    final actionDesc = isRegistration
        ? 'Thank you for joining Play Friends! Use the one-time 6-digit verification code below to verify your email address and activate your player profile.'
        : 'We received a request to reset your Play Friends password. Enter the one-time 6-digit code below in the application to create a new password.';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0B0E1B; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #F8FAFC;">
  <!-- Hidden preheader text to prevent spam snippet issues -->
  <span style="display:none;font-size:1px;color:#0B0E1B;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">
    Your Play Friends 6-digit verification code is $otpCode. Valid for 10 minutes.
  </span>

  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #0B0E1B; padding: 30px 15px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width: 540px; background-color: #131A2E; border: 1px solid rgba(139, 92, 246, 0.35); border-radius: 24px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.5);">
          <!-- Header Banner -->
          <tr>
            <td style="background: linear-gradient(135deg, #8B5CF6, #06B6D4); padding: 32px 24px; text-align: center;">
              <h1 style="margin: 0; font-size: 26px; font-weight: 800; color: #FFFFFF; letter-spacing: 1px;">
                🎮 Play Friends
              </h1>
              <p style="margin: 6px 0 0; font-size: 14px; color: rgba(255,255,255,0.95);">
                Social Gaming & Arena Duels
              </p>
            </td>
          </tr>

          <!-- Content Body -->
          <tr>
            <td style="padding: 32px 28px;">
              <h2 style="margin: 0 0 14px; font-size: 20px; color: #FFFFFF; font-weight: 700;">
                $title
              </h2>
              <p style="margin: 0 0 18px; font-size: 14px; line-height: 1.6; color: #94A3B8;">
                Hello <strong>$recipientName</strong>,<br>
                $actionDesc
              </p>

              <!-- OTP Code Display Card -->
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin: 24px 0;">
                <tr>
                  <td align="center" style="background-color: #161F38; border: 2px dashed #8B5CF6; border-radius: 16px; padding: 22px 16px;">
                    <span style="font-size: 12px; text-transform: uppercase; letter-spacing: 2px; color: #38BDF8; font-weight: 700; display: block; margin-bottom: 8px;">
                      Your One-Time 6-Digit Code
                    </span>
                    <span style="font-size: 38px; font-weight: 900; letter-spacing: 10px; color: #FFFFFF; font-family: 'Courier New', monospace; text-shadow: 0 0 12px rgba(139, 92, 246, 0.6);">
                      $otpCode
                    </span>
                    <span style="font-size: 12px; color: #F59E0B; display: block; margin-top: 10px; font-weight: 600;">
                      ⏳ Valid for 10 minutes only
                    </span>
                  </td>
                </tr>
              </table>

              <p style="margin: 20px 0 0; font-size: 13px; line-height: 1.5; color: #64748B;">
                🔒 <strong>Security Notice:</strong> Never share this code with anyone. Play Friends team members will never ask for your verification code. If you did not make this request, you can safely ignore this email.
              </p>
            </td>
          </tr>

          <!-- Footer with anti-spam compliance -->
          <tr>
            <td style="background-color: #0E1424; padding: 20px; text-align: center; border-top: 1px solid rgba(139, 92, 246, 0.15);">
              <p style="margin: 0 0 6px; font-size: 12px; color: #94A3B8;">
                Play Friends Mobile Application • Free-to-Play Social Games
              </p>
              <p style="margin: 0; font-size: 11px; color: #64748B;">
                Domain: <a href="https://ssgobind.space" style="color: #38BDF8; text-decoration: none;">ssgobind.space</a> • Support: <a href="mailto:playgamefriendes@gmail.com" style="color: #38BDF8; text-decoration: none;">playgamefriendes@gmail.com</a><br>
                This is a transactional security notification sent at your request.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }
}
