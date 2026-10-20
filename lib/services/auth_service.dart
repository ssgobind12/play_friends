import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/brevo_email_service.dart';
import '../theme/app_theme.dart';

class OtpRecord {
  final String email;
  final String code;
  final DateTime createdAt;
  final String purpose; // 'registration' or 'forgot_password'
  bool isUsed;

  OtpRecord({
    required this.email,
    required this.code,
    required this.createdAt,
    required this.purpose,
    this.isUsed = false,
  });

  bool get isExpired => DateTime.now().difference(createdAt).inMinutes > 10;
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal() {
    // Default pre-registered users for instant demo testing
    _registeredUsers = [
      const UserModel(
        id: 'u_alex',
        name: 'Alex Vance',
        tag: '@alex_play',
        email: 'alex@playfriends.io',
        password: 'password123',
        phoneNumber: '9876543210',
        countryCode: '+91',
        countryFlag: '🇮🇳',
        avatarColor: AppColors.primaryPurple,
        avatarInitial: 'A',
        level: 14,
        coins: 1450,
        trophies: 28,
        winRate: 68.5,
        totalMatches: 152,
      ),
      const UserModel(
        id: 'u_sarah',
        name: 'Sarah Connor',
        tag: '@sarah_c',
        email: 'sarah@playfriends.io',
        password: 'password123',
        phoneNumber: '9812345678',
        countryCode: '+1',
        countryFlag: '🇺🇸',
        avatarColor: Color(0xFFEC4899),
        avatarInitial: 'S',
        level: 19,
        coins: 2800,
        trophies: 45,
        winRate: 72.0,
        totalMatches: 210,
      ),
    ];

    // Start with Alex Vance logged in by default, but user can log out anytime
    _currentUser = _registeredUsers.first;
  }

  late List<UserModel> _registeredUsers;
  UserModel? _currentUser;
  final List<OtpRecord> _otpRecords = [];

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  List<UserModel> get registeredUsers => List.unmodifiable(_registeredUsers);

  // --------------------------------------------------------------------------
  // OTP GENERATION & VERIFICATION (6-digit One-Time Codes)
  // --------------------------------------------------------------------------

  String _generate6DigitOtp() {
    final rng = Random();
    final number = 100000 + rng.nextInt(900000);
    return number.toString();
  }

  /// Generates and records a 6-digit one-time OTP for email registration
  String generateRegistrationOtp(String email, {String name = ''}) {
    final cleanEmail = email.trim().toLowerCase();
    // Invalidate prior unused registration codes for this email
    for (final record in _otpRecords) {
      if (record.email == cleanEmail && record.purpose == 'registration') {
        record.isUsed = true;
      }
    }

    final code = _generate6DigitOtp();
    _otpRecords.add(
      OtpRecord(
        email: cleanEmail,
        code: code,
        createdAt: DateTime.now(),
        purpose: 'registration',
      ),
    );

    // Trigger Brevo email delivery asynchronously
    BrevoEmailService.sendOtpEmail(
      recipientEmail: cleanEmail,
      recipientName: name,
      otpCode: code,
      purpose: 'registration',
    );

    return code;
  }

  /// Verifies a 6-digit one-time OTP for registration
  bool verifyRegistrationOtp(String email, String otp) {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    for (int i = _otpRecords.length - 1; i >= 0; i--) {
      final record = _otpRecords[i];
      if (record.email == cleanEmail &&
          record.purpose == 'registration' &&
          !record.isUsed &&
          !record.isExpired) {
        if (record.code == cleanOtp) {
          record.isUsed = true; // One-time use enforced
          return true;
        }
      }
    }
    return false;
  }

  /// Generates and sends a 6-digit one-time OTP for forgot password
  String? sendForgotPasswordOtp(String email) {
    final cleanEmail = email.trim().toLowerCase();

    // Check if user exists
    final userIndex = _registeredUsers.indexWhere((u) => u.email.toLowerCase() == cleanEmail);
    if (userIndex == -1) {
      return 'No account found with this email address. Please register.';
    }

    final user = _registeredUsers[userIndex];

    // Invalidate prior unused forgot_password codes for this email
    for (final record in _otpRecords) {
      if (record.email == cleanEmail && record.purpose == 'forgot_password') {
        record.isUsed = true;
      }
    }

    final code = _generate6DigitOtp();
    _otpRecords.add(
      OtpRecord(
        email: cleanEmail,
        code: code,
        createdAt: DateTime.now(),
        purpose: 'forgot_password',
      ),
    );

    // Trigger Brevo email delivery asynchronously
    BrevoEmailService.sendOtpEmail(
      recipientEmail: cleanEmail,
      recipientName: user.name,
      otpCode: code,
      purpose: 'forgot_password',
    );

    return null; // Success
  }

  /// Verifies 6-digit OTP and resets user password
  String? resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    if (newPassword.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    OtpRecord? validRecord;
    for (int i = _otpRecords.length - 1; i >= 0; i--) {
      final record = _otpRecords[i];
      if (record.email == cleanEmail &&
          record.purpose == 'forgot_password' &&
          !record.isUsed &&
          !record.isExpired) {
        if (record.code == cleanOtp) {
          validRecord = record;
          break;
        }
      }
    }

    if (validRecord == null) {
      return 'Invalid or expired 6-digit OTP. Please request a new code.';
    }

    final userIndex = _registeredUsers.indexWhere((u) => u.email.toLowerCase() == cleanEmail);
    if (userIndex == -1) {
      return 'Account not found.';
    }

    // Update password
    _registeredUsers[userIndex] = _registeredUsers[userIndex].copyWith(password: newPassword);
    validRecord.isUsed = true; // Enforce one-time OTP consumption

    // If currently logged in as this user, update active session
    if (_currentUser?.email.toLowerCase() == cleanEmail) {
      _currentUser = _registeredUsers[userIndex];
    }

    notifyListeners();
    return null; // Success
  }

  /// Helper to get the latest active OTP code for in-app demo email notifications
  String? getLatestOtpForEmail(String email, {String? purpose}) {
    final cleanEmail = email.trim().toLowerCase();
    for (int i = _otpRecords.length - 1; i >= 0; i--) {
      final record = _otpRecords[i];
      if (record.email == cleanEmail &&
          !record.isUsed &&
          !record.isExpired &&
          (purpose == null || record.purpose == purpose)) {
        return record.code;
      }
    }
    return null;
  }

  // --------------------------------------------------------------------------
  // AUTHENTICATION & SESSION MANAGEMENT
  // --------------------------------------------------------------------------

  String? login(String identifier, String password) {
    final cleanId = identifier.trim().toLowerCase();
    final cleanTag = cleanId.startsWith('@') ? cleanId : '@$cleanId';

    UserModel? matchedUser;
    for (final user in _registeredUsers) {
      if (user.email.toLowerCase() == cleanId ||
          user.tag.toLowerCase() == cleanId ||
          user.tag.toLowerCase() == cleanTag) {
        matchedUser = user;
        break;
      }
    }

    if (matchedUser == null) {
      return 'Account not found. Please check your username/email or sign up.';
    }

    if (matchedUser.password != password) {
      return 'Incorrect password. Please try again.';
    }

    _currentUser = matchedUser;
    notifyListeners();
    return null; // Success
  }

  String? validateRegistrationDetails({
    required String name,
    required String tag,
    required String email,
    required String password,
    required String phoneNumber,
  }) {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final formattedTag = tag.trim().startsWith('@') ? tag.trim().toLowerCase() : '@${tag.trim().toLowerCase()}';
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

    if (cleanName.length < 2) {
      return 'Please enter a valid display name.';
    }

    if (formattedTag.length < 3) {
      return 'Gamer tag must be at least 3 characters.';
    }

    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      return 'Please enter a valid email address.';
    }

    if (cleanPhone.length < 7 || cleanPhone.length > 15) {
      return 'Please enter a valid phone number (7-15 digits).';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    for (final user in _registeredUsers) {
      if (user.email.toLowerCase() == cleanEmail) {
        return 'An account with this email already exists.';
      }
      if (user.tag.toLowerCase() == formattedTag) {
        return 'This gamer tag is already taken. Please choose another.';
      }
    }

    return null; // Valid
  }

  String? register({
    required String name,
    required String tag,
    required String email,
    required String password,
    required String phoneNumber,
    required String countryCode,
    required String countryFlag,
    required Color avatarColor,
  }) {
    final validationError = validateRegistrationDetails(
      name: name,
      tag: tag,
      email: email,
      password: password,
      phoneNumber: phoneNumber,
    );

    if (validationError != null) {
      return validationError;
    }

    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final formattedTag = tag.trim().startsWith('@') ? tag.trim().toLowerCase() : '@${tag.trim().toLowerCase()}';

    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : 'G';
    final newUser = UserModel(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      tag: formattedTag,
      email: cleanEmail,
      password: password,
      phoneNumber: phoneNumber.trim(),
      countryCode: countryCode,
      countryFlag: countryFlag,
      avatarColor: avatarColor,
      avatarInitial: initial,
      level: 1,
      coins: 500, // Starter demo coins
      trophies: 5,
      winRate: 0.0,
      totalMatches: 0,
    );

    _registeredUsers.add(newUser);
    _currentUser = newUser;
    notifyListeners();
    return null; // Success
  }

  void loginAsGuest() {
    final randomDigits = 1000 + Random().nextInt(9000);
    final guestUser = UserModel(
      id: 'guest_$randomDigits',
      name: 'Guest Player',
      tag: '@guest_$randomDigits',
      email: 'guest$randomDigits@local.demo',
      password: '',
      phoneNumber: null,
      countryCode: '+91',
      countryFlag: '🇮🇳',
      avatarColor: AppColors.primaryBlueLight,
      avatarInitial: 'G',
      level: 1,
      coins: 300,
      trophies: 0,
      winRate: 0.0,
      totalMatches: 0,
      isGuest: true,
    );

    _currentUser = guestUser;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
