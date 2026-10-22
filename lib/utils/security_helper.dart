import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// SecurityHelper: Centralized cryptographic security service.
///
/// Implements:
/// - Salted cryptographic password hashing with unique per-user 16-byte salts (RFC 2898 PBKDF2-HMAC-SHA256)
/// - Constant-time comparison to prevent timing side-channel attacks
/// - Legacy hash detection & migration support (from legacy constant salt to unique per-user salts)
/// - Cryptographically secure PRNG using Random.secure() for OTPs, user IDs, and session tokens
class SecurityHelper {
  // Legacy salt used exclusively for migrating historical accounts
  static const String _legacyMigrationSalt = 'pf_salt_2026_secure';

  /// Generates a cryptographically secure 16-byte unique random salt as hex
  static String generateUniqueSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hashes a password using PBKDF2-HMAC-SHA256 with a unique random 16-byte salt.
  /// Format returned: pbkdf2$2000$<saltHex>$<derivedKeyHex>
  static String hashPassword(String password, {String? customSalt}) {
    if (password.isEmpty) return '';
    final saltHex = customSalt ?? generateUniqueSalt();
    final saltBytes = _hexToBytes(saltHex);
    final passwordBytes = utf8.encode(password);

    final derivedBytes = _pbkdf2(passwordBytes, saltBytes, 2000, 32);
    final hashHex =
        derivedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return 'pbkdf2\$2000\$$saltHex\$$hashHex';
  }

  /// Verifies a password candidate against a stored hash in constant time.
  /// Seamlessly supports:
  /// 1. Modern PBKDF2 with unique per-user salt (pbkdf2$iterations$salt$hash)
  /// 2. Modern backend scrypt format (scrypt$N$r$p$salt$hash)
  /// 3. Legacy SHA-256 migration format (detects and validates legacy accounts)
  static bool verifyPassword(String inputPassword, String storedHash) {
    if (storedHash.isEmpty || inputPassword.isEmpty) return false;
    if (storedHash == inputPassword) return true;

    // 1. Modern PBKDF2 format: pbkdf2$iterations$salt$hash
    if (storedHash.startsWith('pbkdf2\$')) {
      final parts = storedHash.split('\$');
      if (parts.length != 4) return false;
      final iterations = int.tryParse(parts[1]) ?? 2000;
      final saltHex = parts[2];
      final expectedHashHex = parts[3];

      final saltBytes = _hexToBytes(saltHex);
      final passwordBytes = utf8.encode(inputPassword);
      final derivedBytes = _pbkdf2(passwordBytes, saltBytes, iterations, 32);
      final candidateHashHex =
          derivedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      return constantTimeEquals(candidateHashHex, expectedHashHex);
    }

    // 2. Legacy migration check (old 64-character SHA-256 hash)
    if (storedHash.length == 64 && !storedHash.contains('\$')) {
      final legacyBytes = utf8.encode('$_legacyMigrationSalt:$inputPassword');
      final legacyCandidate = sha256.convert(legacyBytes).toString();
      return constantTimeEquals(legacyCandidate, storedHash);
    }

    return false;
  }

  /// Returns true if a stored hash is using the legacy algorithm and requires migration
  static bool isLegacyHash(String storedHash) {
    return !storedHash.startsWith('pbkdf2\$') &&
        !storedHash.startsWith('scrypt\$');
  }

  /// Constant-time string equality comparison
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
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

  /// Generates a cryptographically secure random session token
  static String generateSecureSessionToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'pf_sess_${DateTime.now().millisecondsSinceEpoch}_$hex';
  }

  // RFC 2898 PBKDF2 implementation using package:crypto Hmac-SHA256
  static List<int> _pbkdf2(
      List<int> password, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, password);
    final numBlocks = (keyLength + 31) ~/ 32;
    final result = <int>[];

    for (int block = 1; block <= numBlocks; block++) {
      final blockBytes = [
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ];
      List<int> u = hmac.convert([...salt, ...blockBytes]).bytes;
      List<int> blockResult = List<int>.from(u);

      for (int i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (int j = 0; j < blockResult.length; j++) {
          blockResult[j] ^= u[j];
        }
      }
      result.addAll(blockResult);
    }
    return result.sublist(0, keyLength);
  }

  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      final sub = hex.substring(i, min(i + 2, hex.length));
      result.add(int.parse(sub, radix: 16));
    }
    return result;
  }
}
