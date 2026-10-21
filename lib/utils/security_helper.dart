import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// SecurityHelper: Centralized cryptographic utilities for password hashing,
/// constant-time verification, and cryptographically secure random number generation.
class SecurityHelper {
  // Constant internal salt for credential hashing
  static const String _salt = 'pf_salt_2026_secure';

  /// Precomputed SHA-256 hash with salt for admin credential
  static const String adminPasswordHash =
      'ccd236d001d541f7de2cf12dd2f06be56a54c2705a7937d49c8caa784c84790b';

  /// Generates salted SHA-256 hash for password
  static String hashPassword(String password) {
    if (password.isEmpty) return '';
    final bytes = utf8.encode('$_salt:$password');
    return sha256.convert(bytes).toString();
  }

  /// Verifies plaintext candidate against stored cryptographic hash in constant-time
  static bool verifyPassword(String inputPassword, String storedHash) {
    if (storedHash.isEmpty || inputPassword.isEmpty) return false;
    final candidateHash = hashPassword(inputPassword);

    if (candidateHash.length != storedHash.length) {
      return false;
    }

    int result = 0;
    for (int i = 0; i < candidateHash.length; i++) {
      result |= candidateHash.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Generates cryptographically secure 6-digit OTP code using Random.secure()
  static String generateSecure6DigitOtp() {
    final rng = Random.secure();
    final number = 100000 + rng.nextInt(900000);
    return number.toString();
  }

  /// Generates a unique security ID starting with '01' using Random.secure()
  static String generateSecureUserId([bool Function(String id)? isIdTaken]) {
    final rng = Random.secure();
    String newId;
    do {
      final num = 100000 + rng.nextInt(900000);
      newId = '01$num';
    } while (isIdTaken != null && isIdTaken(newId));
    return newId;
  }
}
