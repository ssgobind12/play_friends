import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:play_friends/config/brevo_config.dart';
import 'package:play_friends/models/country_code.dart';
import 'package:play_friends/services/auth_service.dart';

void main() {
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

      // Wrong OTP fails
      final wrongOtpErr = auth.resetPasswordWithOtp(
        email: 'alex@playfriends.io',
        otp: '999999',
        newPassword: 'myNewPassword456',
      );
      expect(wrongOtpErr, contains('Invalid or expired'));

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

    test('BrevoConfig isConfigured check and live config verification', () async {
      // Config is active with custom domain sender for inbox deliverability
      expect(BrevoConfig.isConfigured, isTrue);
      expect(BrevoConfig.apiKey.startsWith('xkeysib-'), isTrue);
      expect(BrevoConfig.senderEmail, 'noreply@ssgobind.space');
      expect(BrevoConfig.replyToEmail, 'playgamefriendes@gmail.com');
      expect(BrevoConfig.domain, 'ssgobind.space');
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
