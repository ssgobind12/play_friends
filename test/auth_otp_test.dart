import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:play_friends/config/brevo_config.dart';
import 'package:play_friends/models/country_code.dart';
import 'package:play_friends/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService().resetStatsForTesting();
  });

  group('AuthService OTP & Phone Registration Tests', () {
    final auth = AuthService();

    test('generateRegistrationOtp generates 6-digit one-time code', () {
      final code = auth.generateRegistrationOtp('player1@test.com');
      expect(code.length, 6);
      expect(int.tryParse(code), isNotNull);

      // Verify OTP succeeds
      final verified = auth.verifyRegistrationOtp('player1@test.com', code);
      expect(verified, isTrue);

      // One-time check: second attempt with same OTP must fail
      final secondTry = auth.verifyRegistrationOtp('player1@test.com', code);
      expect(secondTry, isFalse);
    });

    test('verifyRegistrationOtp rejects incorrect OTP', () {
      auth.generateRegistrationOtp('player2@test.com');
      final verified = auth.verifyRegistrationOtp('player2@test.com', '000000');
      expect(verified, isFalse);
    });

    test('Registration requires phone number validation and blocks duplicate phone numbers', () {
      final invalidPhone = auth.validateRegistrationDetails(
        name: 'Gamer One',
        tag: '@gamer1',
        email: 'gamer1@test.com',
        password: 'password123',
        phoneNumber: '123', // Too short
      );
      expect(invalidPhone, contains('phone number'));

      // Existing phone number 9876543210 belongs to Alex Vance
      final duplicatePhone = auth.validateRegistrationDetails(
        name: 'Gamer One',
        tag: '@gamer1',
        email: 'gamer1@test.com',
        password: 'password123',
        phoneNumber: '9876543210',
      );
      expect(duplicatePhone, contains('already used'));

      // New unique phone number
      final validPhone = auth.validateRegistrationDetails(
        name: 'Gamer One',
        tag: '@gamer1',
        email: 'gamer1@test.com',
        password: 'password123',
        phoneNumber: '9123456789',
      );
      expect(validPhone, isNull);
    });

    test('Register completes successfully with country code and phone', () {
      const email = 'newhero@playfriends.io';
      final otp = auth.generateRegistrationOtp(email);
      expect(auth.verifyRegistrationOtp(email, otp), isTrue);

      final error = auth.register(
        name: 'New Hero',
        tag: '@new_hero',
        email: email,
        password: 'password123',
        phoneNumber: '9876500000',
        countryCode: '+91',
        countryFlag: '🇮🇳',
        avatarColor: const Color(0xFF10B981),
      );

      expect(error, isNull);
      expect(auth.currentUser?.email, email);
      expect(auth.currentUser?.phoneNumber, '9876500000');
      expect(auth.currentUser?.countryCode, '+91');
      expect(auth.currentUser?.coins, 500);
    });

    test('Forgot Password OTP generation and password reset', () {
      // Unknown email fails
      final unknownErr = auth.sendForgotPasswordOtp('unknown@nobody.io');
      expect(unknownErr, contains('No account found'));

      // Existing email succeeds
      final sendErr = auth.sendForgotPasswordOtp('alex@playfriends.io');
      expect(sendErr, isNull);

      final resetOtp = auth.getLatestOtpForEmail('alex@playfriends.io', purpose: 'forgot_password');
      expect(resetOtp, isNotNull);
      expect(resetOtp!.length, 6);

      // Wrong OTP fails with remaining attempts counter
      final wrongOtpErr = auth.resetPasswordWithOtp(
        email: 'alex@playfriends.io',
        otp: '999999',
        newPassword: 'myNewPassword456',
      );
      expect(wrongOtpErr, contains('Incorrect OTP code'));

      // Correct OTP succeeds
      final success = auth.resetPasswordWithOtp(
        email: 'alex@playfriends.io',
        otp: resetOtp,
        newPassword: 'myNewPassword456',
      );
      expect(success, isNull);

      // User can now log in with new password
      final loginResult = auth.login('alex@playfriends.io', 'myNewPassword456');
      expect(loginResult, isNull);
      expect(auth.currentUser?.name, 'Alex Vance');

      // Old password fails
      final oldPasswordResult = auth.login('alex@playfriends.io', 'password123');
      expect(oldPasswordResult, contains('Incorrect password'));

      // One-time check: Reusing reset OTP fails
      final reuseErr = auth.resetPasswordWithOtp(
        email: 'alex@playfriends.io',
        otp: resetOtp,
        newPassword: 'anotherPassword789',
      );
      expect(reuseErr, contains('Invalid or expired'));
    });

    test('CountryCode default list contains popular countries with codes', () {
      expect(CountryCode.defaultCountries.isNotEmpty, isTrue);
      final india = CountryCode.defaultCountries.firstWhere((c) => c.code == '+91');
      expect(india.flag, '🇮🇳');
      expect(india.name, 'India');

      final us = CountryCode.defaultCountries.firstWhere((c) => c.code == '+1' && c.name == 'United States');
      expect(us.flag, '🇺🇸');
    });

    test('BrevoConfig security audit: no raw credentials hardcoded in codebase', () async {
      // API Key must not be hardcoded in client source code
      expect(BrevoConfig.apiKey, isEmpty);
      expect(BrevoConfig.smtpPassword, isEmpty);
      expect(BrevoConfig.isConfigured, isFalse);
      expect(BrevoConfig.senderEmail, 'noreply@ssgobind.space');
      expect(BrevoConfig.replyToEmail, 'playgamefriendes@gmail.com');
      expect(BrevoConfig.domain, 'ssgobind.space');
    });

    test('Security: Max 3 failed OTP attempts invalidates code', () {
      final code = auth.generateRegistrationOtp('lockout@test.com');
      expect(auth.verifyRegistrationOtp('lockout@test.com', '111111'), isFalse);
      expect(auth.verifyRegistrationOtp('lockout@test.com', '222222'), isFalse);
      expect(auth.verifyRegistrationOtp('lockout@test.com', '333333'), isFalse); // 3rd failed attempt

      // Now even the correct code must fail because max attempts was exceeded
      expect(auth.verifyRegistrationOtp('lockout@test.com', code), isFalse);
    });

    test('Security: Passwords stored as salted SHA-256 hash and not plaintext', () {
      auth.register(
        name: 'Hash Tester',
        tag: '@hash_tester',
        email: 'hash@playfriends.io',
        password: 'PlaintextPassword#99',
        phoneNumber: '9123499999',
        countryCode: '+91',
        countryFlag: '🇮🇳',
        avatarColor: const Color(0xFF10B981),
      );

      final user = auth.currentUser!;
      // Plaintext password is never stored
      expect(user.passwordHash, isNotEmpty);
      expect(user.passwordHash, isNot(contains('PlaintextPassword#99')));
      expect(user.passwordHash.length, 64); // Standard SHA-256 64-character hex length

      // Serialized map for SharedPreferences & network never contains plaintext password
      final map = user.toMap();
      expect(map.containsKey('password'), isFalse);
      expect(map['passwordHash'], equals(user.passwordHash));
    });

    test('AWS Storage checkUserExists blocks duplicate email and mobile number', () async {
      // Register a user
      auth.register(
        name: 'Cloud Player',
        tag: '@cloud_play',
        email: 'cloud@ssgobind.space',
        password: 'password123',
        phoneNumber: '9988776655',
        countryCode: '+91',
        countryFlag: '🇮🇳',
        avatarColor: const Color(0xFF8B5CF6),
      );

      // Attempting to register again with same email
      final emailCheck = await auth.validateRegistrationDetailsAsync(
        name: 'Another Player',
        tag: '@another_tag',
        email: 'cloud@ssgobind.space',
        password: 'password123',
        phoneNumber: '9111222333',
      );
      expect(emailCheck, contains('email is already used'));

      // Attempting to register again with same phone number
      final phoneCheck = await auth.validateRegistrationDetailsAsync(
        name: 'Another Player',
        tag: '@another_tag',
        email: 'unique_new@ssgobind.space',
        password: 'password123',
        phoneNumber: '9988776655',
      );
      expect(phoneCheck, contains('mobile number is already used'));
    });
  });
}
