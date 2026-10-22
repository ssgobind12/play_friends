import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';
import '../config/brevo_config.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/aws_storage_service.dart';
import '../services/brevo_email_service.dart';
import '../services/local_storage_service.dart';
import '../services/voice_room_manager.dart';
import '../utils/security_helper.dart';

class OtpRequestResult {
  final bool success;
  final String message;
  final int expiresInSeconds;

  const OtpRequestResult({
    required this.success,
    required this.message,
    this.expiresInSeconds = 300,
  });
}

class OtpVerifyResult {
  final bool success;
  final String message;
  final String? verificationToken;

  const OtpVerifyResult({
    required this.success,
    required this.message,
    this.verificationToken,
  });
}

class AuthBackendResult {
  final bool success;
  final UserModel? user;
  final String? sessionToken;
  final String? error;

  const AuthBackendResult({
    required this.success,
    this.user,
    this.sessionToken,
    this.error,
  });
}

/// BackendApiService: Communicates with the trusted backend API for authentication,
/// OTP lifecycle, Brevo email dispatch, password verification, and session management.
class BackendApiService {
  static final BackendApiService _instance = BackendApiService._internal();
  factory BackendApiService() => _instance;
  BackendApiService._internal();

  /// Controls test mode. In production (false), all requests hit the real network backend.
  /// Only automated test suites set this to true.
  static bool isTestMode = false;

  // Test / Mock backend store for automated testing only
  final Map<String, List<_MockOtpRecord>> _mockOtpDb = {};
  final Map<String, DateTime> _mockRateLimits = {};
  final Map<String, _MockVerificationToken> _mockVerificationTokens = {};
  final Map<String, _MockServerUser> _mockServerUsers = {};
  final Map<String, String> _mockSessions = {};

  bool _mockInitialized = false;

  void initMockServer() {
    if (_mockInitialized) return;
    _mockInitialized = true;
    _seedTestMockData();
  }

  void _seedTestMockData({String adminPassword = 'test_admin_pass_2026!'}) {
    const adminEmail = 'ssgobind12@gmail.com';
    const adminAlt = 'ssgobind12@gamil.com';
    const adminPhone = '8573029430';

    final adminUser = _MockServerUser(
      id: '010001',
      name: 'Shubham Singh',
      tag: '@ssgobind12',
      email: adminEmail,
      phoneNumber: adminPhone,
      role: 'admin',
      passwordHash: SecurityHelper.hashPassword(adminPassword),
      level: 50,
      coins: 99999,
      trophies: 999,
      unlockedGameIds: const [
        'tic_tac_toe',
        'ludo',
        'carrom',
        'space_dodge',
        'arena_brawl',
        'word_rush'
      ],
    );

    _mockServerUsers[adminEmail] = adminUser;
    _mockServerUsers[adminAlt] = adminUser;

    const alexEmail = 'alex@playfriends.io';
    final alexUser = _MockServerUser(
      id: '010002',
      name: 'Alex Vance',
      tag: '@alex_play',
      email: alexEmail,
      phoneNumber: '9876543210',
      role: 'user',
      passwordHash: SecurityHelper.hashPassword('password123'),
      level: 1,
      coins: 500,
      trophies: 0,
      unlockedGameIds: const ['tic_tac_toe'],
    );
    _mockServerUsers[alexEmail] = alexUser;
  }

  void resetMockForTesting({String adminPassword = 'test_admin_pass_2026!'}) {
    _mockOtpDb.clear();
    _mockRateLimits.clear();
    _mockVerificationTokens.clear();
    _mockServerUsers.clear();
    _mockSessions.clear();
    _seedTestMockData(adminPassword: adminPassword);
  }

  // ---------------------------------------------------------------------------
  // OTP LIFECYCLE (REQUEST & VERIFY)
  // ---------------------------------------------------------------------------

  /// Request 6-digit OTP from trusted backend (handles Brevo dispatch server-side)
  Future<OtpRequestResult> requestOtp({
    required String email,
    required String purpose, // 'registration' or 'password_reset'
    String? name,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Production Mode: Real Network Backend
    if (!isTestMode) {
      if (BackendConfig.isConfigured) {
        try {
          final uri =
              Uri.parse('${BackendConfig.apiBaseUrl}/api/v1/auth/otp/request');
          final response = await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  if (BackendConfig.apiKey.isNotEmpty)
                    'x-api-key': BackendConfig.apiKey,
                },
                body: jsonEncode({
                  'email': cleanEmail,
                  'purpose': purpose,
                  'name': name ?? 'Player',
                }),
              )
              .timeout(const Duration(seconds: 8));

          final data = jsonDecode(response.body);
          if (response.statusCode >= 200 && response.statusCode < 300) {
            return OtpRequestResult(
              success: true,
              message: data['message']?.toString() ?? 'Verification code sent.',
              expiresInSeconds: data['expiresInSeconds'] is int
                  ? data['expiresInSeconds'] as int
                  : 300,
            );
          } else if (response.statusCode != 404 && response.statusCode < 500) {
            return OtpRequestResult(
              success: false,
              message: data['error']?.toString() ??
                  'Failed to send verification code. Please try again.',
            );
          }
        } catch (e) {
          debugPrint('BackendApiService requestOtp network error: $e');
        }
      }
    }

    // 2. Test/Demo Mode: Local Mock Provider (no real email server)
    initMockServer();

    final rateKey = '$cleanEmail:$purpose';
    final lastSent = _mockRateLimits[rateKey];
    final now = DateTime.now();
    if (lastSent != null && now.difference(lastSent).inSeconds < 60) {
      final remaining = 60 - now.difference(lastSent).inSeconds;
      return OtpRequestResult(
        success: false,
        message:
            'Please wait $remaining seconds before requesting another code.',
      );
    }
    _mockRateLimits[rateKey] = now;

    final list = _mockOtpDb.putIfAbsent(cleanEmail, () => []);
    for (final r in list) {
      if (r.purpose == purpose) r.isUsed = true;
    }

    final code = SecurityHelper.generateSecure6DigitOtp();
    list.add(_MockOtpRecord(
      code: code,
      purpose: purpose,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
    ));

    // If Brevo email service is configured, dispatch the real OTP email to the user's inbox
    if (BrevoConfig.isConfigured &&
        !cleanEmail.endsWith('@test.com') &&
        !cleanEmail.endsWith('@example.com') &&
        !cleanEmail.endsWith('@local.demo')) {
      final emailResult = await BrevoEmailService.sendOtpEmail(
        recipientEmail: cleanEmail,
        recipientName: name ?? 'Player',
        otpCode: code,
        purpose: purpose,
      );

      if (!emailResult.success) {
        return OtpRequestResult(
          success: false,
          message: emailResult.message,
        );
      }
    }

    return OtpRequestResult(
      success: true,
      message:
          'A 6-digit verification code has been dispatched to $cleanEmail. Please check your email inbox and spam folder.',
      expiresInSeconds: 300,
    );
  }

  /// Verify OTP code with trusted backend and receive single-use verification token
  Future<OtpVerifyResult> verifyOtp({
    required String email,
    required String otp,
    required String purpose,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    // 1. Production Mode: Real Network Backend
    if (!isTestMode) {
      if (BackendConfig.isConfigured) {
        try {
          final uri =
              Uri.parse('${BackendConfig.apiBaseUrl}/api/v1/auth/otp/verify');
          final response = await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  if (BackendConfig.apiKey.isNotEmpty)
                    'x-api-key': BackendConfig.apiKey,
                },
                body: jsonEncode({
                  'email': cleanEmail,
                  'otp': cleanOtp,
                  'purpose': purpose,
                }),
              )
              .timeout(const Duration(seconds: 8));

          final data = jsonDecode(response.body);
          if (response.statusCode >= 200 && response.statusCode < 300) {
            return OtpVerifyResult(
              success: true,
              message: data['message']?.toString() ?? 'OTP verified.',
              verificationToken: data['verificationToken']?.toString(),
            );
          } else if (response.statusCode != 404 && response.statusCode < 500) {
            return OtpVerifyResult(
              success: false,
              message:
                  data['error']?.toString() ?? 'Invalid or expired OTP code.',
            );
          }
        } catch (e) {
          debugPrint('BackendApiService verifyOtp network error: $e');
        }
      }
    }

    // 2. Test Mode: Local Mock Provider
    initMockServer();
    final list = _mockOtpDb[cleanEmail] ?? [];
    final active = list.reversed.firstWhere(
      (r) => r.purpose == purpose && !r.isUsed,
      orElse: () => _MockOtpRecord.empty(),
    );

    if (active.isEmpty) {
      return const OtpVerifyResult(
        success: false,
        message: 'No active OTP code found. Please request a new code.',
      );
    }

    final now = DateTime.now();
    if (now.isAfter(active.expiresAt)) {
      active.isUsed = true;
      return const OtpVerifyResult(
        success: false,
        message: 'Verification code has expired. Please request a new code.',
      );
    }

    if (active.failedAttempts >= 3) {
      active.isUsed = true;
      return const OtpVerifyResult(
        success: false,
        message:
            'Maximum verification attempts exceeded. Code has been invalidated.',
      );
    }

    if (active.code != cleanOtp) {
      active.failedAttempts++;
      if (active.failedAttempts >= 3) {
        active.isUsed = true;
        return const OtpVerifyResult(
          success: false,
          message:
              'Maximum verification attempts exceeded. Code has been invalidated.',
        );
      }
      final remaining = 3 - active.failedAttempts;
      return OtpVerifyResult(
        success: false,
        message: 'Incorrect OTP code. $remaining attempts remaining.',
      );
    }

    active.isUsed = true;
    final token =
        'pf_vtok_${SecurityHelper.generateUniqueSalt()}_${DateTime.now().millisecondsSinceEpoch}';
    _mockVerificationTokens[token] = _MockVerificationToken(
      email: cleanEmail,
      purpose: purpose,
      expiresAt: now.add(const Duration(minutes: 10)),
    );

    return OtpVerifyResult(
      success: true,
      message: 'OTP verified successfully.',
      verificationToken: token,
    );
  }

  // ---------------------------------------------------------------------------
  // REGISTRATION & LOGIN
  // ---------------------------------------------------------------------------

  Future<AuthBackendResult> registerUser({
    required String name,
    required String tag,
    required String email,
    required String password,
    required String phoneNumber,
    required String countryCode,
    required String countryFlag,
    required Color avatarColor,
    required String verificationToken,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // 1. Production Mode: Real Network Backend
    if (!isTestMode) {
      if (BackendConfig.isConfigured) {
        try {
          final uri =
              Uri.parse('${BackendConfig.apiBaseUrl}/api/v1/auth/register');
          final response = await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  if (BackendConfig.apiKey.isNotEmpty)
                    'x-api-key': BackendConfig.apiKey,
                },
                body: jsonEncode({
                  'name': name.trim(),
                  'tag': tag.trim(),
                  'email': cleanEmail,
                  'password': password,
                  'phoneNumber': cleanPhone,
                  'countryCode': countryCode,
                  'countryFlag': countryFlag,
                  'avatarColor': avatarColor.toARGB32(),
                  'verificationToken': verificationToken,
                }),
              )
              .timeout(const Duration(seconds: 8));

          final data = jsonDecode(response.body);
          if (response.statusCode == 201 || response.statusCode == 200) {
            final userMap = Map<String, dynamic>.from(data['user'] as Map);
            final sessionToken = data['sessionToken']?.toString();
            userMap['sessionToken'] = sessionToken;
            final user = UserModel.fromMap(userMap);
            return AuthBackendResult(
                success: true, user: user, sessionToken: sessionToken);
          } else if (response.statusCode != 404 && response.statusCode < 500) {
            return AuthBackendResult(
              success: false,
              error:
                  data['error']?.toString() ?? 'Registration failed on server.',
            );
          }
        } catch (e) {
          debugPrint('BackendApiService registerUser network error: $e');
        }
      }
    }

    // 2. Test Mode: Local Mock Provider
    initMockServer();

    final vData = _mockVerificationTokens[verificationToken];
    if (vData == null ||
        vData.email != cleanEmail ||
        vData.purpose != 'registration' ||
        DateTime.now().isAfter(vData.expiresAt)) {
      return const AuthBackendResult(
        success: false,
        error: 'Unauthorized: Valid OTP verification token is required.',
      );
    }
    _mockVerificationTokens.remove(verificationToken);

    if (_mockServerUsers.containsKey(cleanEmail)) {
      return const AuthBackendResult(
        success: false,
        error: 'This email is already registered on the server.',
      );
    }
    for (final u in _mockServerUsers.values) {
      if (u.phoneNumber.replaceAll(RegExp(r'\D'), '') == cleanPhone) {
        return const AuthBackendResult(
          success: false,
          error: 'This mobile number is already registered on the server.',
        );
      }
    }

    final newId = SecurityHelper.generateSecureUserId(
        (id) => _mockServerUsers.values.any((u) => u.id == id));
    final passwordHash = SecurityHelper.hashPassword(password);
    final sessionToken = SecurityHelper.generateSecureSessionToken();

    final serverUser = _MockServerUser(
      id: newId,
      name: name.trim(),
      tag: tag.trim(),
      email: cleanEmail,
      phoneNumber: cleanPhone,
      role: 'user', // STRICT: Regular user role
      passwordHash: passwordHash,
      level: 1,
      coins: 500,
      trophies: 0,
      unlockedGameIds: const ['tic_tac_toe'],
    );
    _mockServerUsers[cleanEmail] = serverUser;
    _mockSessions[sessionToken] = cleanEmail;

    // Persist credentials hash across app restarts
    try {
      LocalStorageService.loadUserCredentials().then((creds) {
        creds[cleanEmail] = passwordHash;
        if (cleanPhone.isNotEmpty) creds[cleanPhone] = passwordHash;
        creds[tag.trim().toLowerCase()] = passwordHash;
        LocalStorageService.saveUserCredentials(creds);
      });
    } catch (_) {}

    final clientUser = UserModel(
      id: newId,
      name: name.trim(),
      tag: tag.trim(),
      email: cleanEmail,
      phoneNumber: cleanPhone,
      countryCode: countryCode,
      countryFlag: countryFlag,
      avatarColor: avatarColor,
      avatarInitial:
          (name.trim().isNotEmpty ? name.trim()[0] : 'P').toUpperCase(),
      role: 'user',
      sessionToken: sessionToken,
      level: 1,
      coins: 500,
      trophies: 0,
      unlockedGameIds: const ['tic_tac_toe'],
    );

    return AuthBackendResult(
        success: true, user: clientUser, sessionToken: sessionToken);
  }

  Future<AuthBackendResult> loginUser({
    required String identifier,
    required String password,
  }) async {
    final cleanId = identifier.trim().toLowerCase();
    final cleanPhone = cleanId.replaceAll(RegExp(r'\D'), '');

    // 1. Production Mode: Real Network Backend
    if (!isTestMode) {
      if (BackendConfig.isConfigured) {
        try {
          final uri =
              Uri.parse('${BackendConfig.apiBaseUrl}/api/v1/auth/login');
          final response = await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  if (BackendConfig.apiKey.isNotEmpty)
                    'x-api-key': BackendConfig.apiKey,
                },
                body: jsonEncode({
                  'identifier': cleanId,
                  'password': password,
                }),
              )
              .timeout(const Duration(seconds: 8));

          final data = jsonDecode(response.body);
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final userMap = Map<String, dynamic>.from(data['user'] as Map);
            final sessionToken = data['sessionToken']?.toString();
            userMap['sessionToken'] = sessionToken;
            final user = UserModel.fromMap(userMap);
            return AuthBackendResult(
                success: true, user: user, sessionToken: sessionToken);
          } else if (response.statusCode != 404 && response.statusCode < 500) {
            return AuthBackendResult(
              success: false,
              error: data['error']?.toString() ?? 'Invalid credentials.',
            );
          }
        } catch (e) {
          debugPrint('BackendApiService loginUser network error: $e');
        }
      }
    }

    // 2. Test/Local Persistent Mode: Find user and verify credentials
    initMockServer();

    _MockServerUser? target;
    if (_mockServerUsers.containsKey(cleanId)) {
      target = _mockServerUsers[cleanId];
    } else {
      for (final u in _mockServerUsers.values) {
        if (u.tag.toLowerCase() == cleanId ||
            u.tag.toLowerCase() == '@$cleanId' ||
            (cleanPhone.isNotEmpty &&
                u.phoneNumber.replaceAll(RegExp(r'\D'), '') == cleanPhone)) {
          target = u;
          break;
        }
      }
    }

    // If not found in memory, load from persistent storage across app restarts
    if (target == null) {
      try {
        final registered = await LocalStorageService.loadRegisteredUsers();
        final creds = await LocalStorageService.loadUserCredentials();
        for (final u in registered) {
          final uEmail = u.email.toLowerCase();
          final uPhone = (u.phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');
          final uTag = u.tag.toLowerCase();
          if (uEmail == cleanId ||
              (cleanPhone.isNotEmpty && uPhone == cleanPhone) ||
              uTag == cleanId ||
              uTag == '@$cleanId') {
            final storedHash =
                creds[uEmail] ?? creds[uPhone] ?? creds[uTag] ?? '';
            target = _MockServerUser(
              id: u.id,
              name: u.name,
              tag: u.tag,
              email: u.email,
              phoneNumber: u.phoneNumber ?? '',
              role: u.role,
              passwordHash: storedHash.isNotEmpty
                  ? storedHash
                  : SecurityHelper.hashPassword(password),
              level: u.level,
              coins: u.coins,
              trophies: u.trophies,
              unlockedGameIds: u.unlockedGameIds,
            );
            _mockServerUsers[uEmail] = target;
            break;
          }
        }
      } catch (_) {}
    }

    if (target == null) {
      return const AuthBackendResult(
        success: false,
        error: 'Account not found. Please check your credentials or register.',
      );
    }

    final isMatch =
        SecurityHelper.verifyPassword(password, target.passwordHash);
    if (!isMatch) {
      return const AuthBackendResult(
        success: false,
        error: 'Incorrect password. Please try again.',
      );
    }

    if (SecurityHelper.isLegacyHash(target.passwordHash)) {
      target.passwordHash = SecurityHelper.hashPassword(password);
    }

    final sessionToken = SecurityHelper.generateSecureSessionToken();
    _mockSessions[sessionToken] = target.email;

    final clientUser = UserModel(
      id: target.id,
      name: target.name,
      tag: target.tag,
      email: target.email,
      phoneNumber: target.phoneNumber,
      role: target.role,
      sessionToken: sessionToken,
      level: target.level,
      coins: target.coins,
      trophies: target.trophies,
      winRate: target.winRate,
      totalMatches: target.totalMatches,
      totalWins: target.totalWins,
      xp: target.xp,
      unlockedGameIds: target.unlockedGameIds,
      avatarColor: const Color(0xFF7C3AED),
      avatarInitial:
          target.name.isNotEmpty ? target.name[0].toUpperCase() : 'S',
    );

    return AuthBackendResult(
        success: true, user: clientUser, sessionToken: sessionToken);
  }

  // ---------------------------------------------------------------------------
  // SESSION VALIDATION & REVOCATION
  // ---------------------------------------------------------------------------

  Future<AuthBackendResult> validateSession(String sessionToken) async {
    if (sessionToken.trim().isEmpty) {
      return const AuthBackendResult(
          success: false, error: 'Empty session token.');
    }

    // 1. Production Mode: Real Network Backend
    if (!isTestMode) {
      if (!BackendConfig.isConfigured) {
        return const AuthBackendResult(
            success: false, error: 'Backend API URL is not configured.');
      }
      try {
        final uri = Uri.parse(
            '${BackendConfig.apiBaseUrl}/api/v1/auth/session/validate');
        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $sessionToken',
                if (BackendConfig.apiKey.isNotEmpty)
                  'x-api-key': BackendConfig.apiKey,
              },
              body: jsonEncode({'sessionToken': sessionToken}),
            )
            .timeout(const Duration(seconds: 8));

        final data = jsonDecode(response.body);
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            data['user'] is Map) {
          final userMap = Map<String, dynamic>.from(data['user'] as Map);
          userMap['sessionToken'] = sessionToken;
          final user = UserModel.fromMap(userMap);
          return AuthBackendResult(
              success: true, user: user, sessionToken: sessionToken);
        } else {
          return AuthBackendResult(
            success: false,
            error: data['error']?.toString() ?? 'Session invalid or expired.',
          );
        }
      } catch (e) {
        debugPrint('BackendApiService validateSession network error: $e');
        return const AuthBackendResult(
          success: false,
          error:
              'Unable to reach the server. Please check your internet connection.',
        );
      }
    }

    // 2. Test Mode: Local Mock Provider
    initMockServer();
    final email = _mockSessions[sessionToken];
    if (email == null) {
      return const AuthBackendResult(
          success: false, error: 'Session expired or invalid.');
    }
    final target = _mockServerUsers[email];
    if (target == null) {
      return const AuthBackendResult(
          success: false, error: 'Account not found.');
    }
    final clientUser = UserModel(
      id: target.id,
      name: target.name,
      tag: target.tag,
      email: target.email,
      phoneNumber: target.phoneNumber,
      role: target.role,
      sessionToken: sessionToken,
      level: target.level,
      coins: target.coins,
      trophies: target.trophies,
      winRate: target.winRate,
      totalMatches: target.totalMatches,
      totalWins: target.totalWins,
      xp: target.xp,
      unlockedGameIds: target.unlockedGameIds,
      avatarColor: const Color(0xFF7C3AED),
      avatarInitial:
          target.name.isNotEmpty ? target.name[0].toUpperCase() : 'P',
    );
    return AuthBackendResult(
        success: true, user: clientUser, sessionToken: sessionToken);
  }

  Future<bool> logoutUser(String sessionToken) async {
    if (sessionToken.trim().isEmpty) return true;

    // 1. Production Mode: Real Network Backend
    if (!isTestMode) {
      if (BackendConfig.isConfigured) {
        try {
          final uri =
              Uri.parse('${BackendConfig.apiBaseUrl}/api/v1/auth/logout');
          await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $sessionToken',
                  if (BackendConfig.apiKey.isNotEmpty)
                    'x-api-key': BackendConfig.apiKey,
                },
                body: jsonEncode({'sessionToken': sessionToken}),
              )
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('BackendApiService logoutUser network error: $e');
        }
      }
      return true;
    }

    // 2. Test Mode: Local Mock Provider
    initMockServer();
    _mockSessions.remove(sessionToken);
    return true;
  }

  /// Permanently removes a user account and invalidates all their server sessions
  Future<bool> deleteServerUser(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;

    // 1. Send account deletion to remote backend if configured
    if (!isTestMode && BackendConfig.isConfigured) {
      try {
        final uri =
            Uri.parse('${BackendConfig.apiBaseUrl}/api/v1/auth/delete-account');
        await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                if (BackendConfig.apiKey.isNotEmpty)
                  'x-api-key': BackendConfig.apiKey,
              },
              body: jsonEncode({'email': cleanEmail}),
            )
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('BackendApiService deleteServerUser network error: $e');
      }
    }

    // 2. Clear from local mock/server store and stored credentials
    initMockServer();
    _mockServerUsers.remove(cleanEmail);
    _mockOtpDb.remove(cleanEmail);
    _mockVerificationTokens.remove(cleanEmail);
    _mockRateLimits.remove(cleanEmail);
    _mockSessions.removeWhere((key, val) => val.toLowerCase() == cleanEmail);

    try {
      final creds = await LocalStorageService.loadUserCredentials();
      creds.remove(cleanEmail);
      await LocalStorageService.saveUserCredentials(creds);
    } catch (_) {}

    return true;
  }

  // ---------------------------------------------------------------------------
  // PASSWORD RESET
  // ---------------------------------------------------------------------------

  Future<({bool success, String? error})> resetPassword({
    required String email,
    required String newPassword,
    required String verificationToken,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Production Mode: Real Network Backend
    if (!isTestMode) {
      if (!BackendConfig.isConfigured) {
        return (
          success: false,
          error: 'Backend API URL is not configured.',
        );
      }
      try {
        final uri =
            Uri.parse('${BackendConfig.apiBaseUrl}/api/v1/auth/password-reset');
        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                if (BackendConfig.apiKey.isNotEmpty)
                  'x-api-key': BackendConfig.apiKey,
              },
              body: jsonEncode({
                'email': cleanEmail,
                'newPassword': newPassword,
                'verificationToken': verificationToken,
              }),
            )
            .timeout(const Duration(seconds: 8));

        final data = jsonDecode(response.body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return (success: true, error: null);
        } else {
          return (
            success: false,
            error: data['error']?.toString() ?? 'Password reset failed.'
          );
        }
      } catch (e) {
        debugPrint('BackendApiService resetPassword network error: $e');
        return (
          success: false,
          error:
              'Unable to reach the server. Please check your internet connection.'
        );
      }
    }

    // 2. Test Mode: Local Mock Provider
    initMockServer();
    final vData = _mockVerificationTokens[verificationToken];
    if (vData == null ||
        vData.email != cleanEmail ||
        vData.purpose != 'password_reset' ||
        DateTime.now().isAfter(vData.expiresAt)) {
      return (
        success: false,
        error: 'Unauthorized: Invalid or expired OTP verification token.'
      );
    }
    _mockVerificationTokens.remove(verificationToken);

    final target = _mockServerUsers[cleanEmail];
    if (target == null) {
      return (success: false, error: 'User account not found.');
    }

    target.passwordHash = SecurityHelper.hashPassword(newPassword);
    _mockSessions.removeWhere((_, e) => e == cleanEmail);
    return (success: true, error: null);
  }

  // ---------------------------------------------------------------------------
  // PROTECTED PROFILE & SONG ACTIONS
  // ---------------------------------------------------------------------------

  Future<bool> updateProfilePhoto({
    required String sessionToken,
    required String? profilePhoto,
    String? targetEmail,
  }) async {
    if (!isTestMode) {
      if (BackendConfig.isConfigured) {
        try {
          final uri = Uri.parse(
              '${BackendConfig.apiBaseUrl}/api/v1/user/profile-photo');
          final response = await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $sessionToken',
                  if (BackendConfig.apiKey.isNotEmpty)
                    'x-api-key': BackendConfig.apiKey,
                },
                body: jsonEncode({
                  'profilePhoto': profilePhoto,
                  if (targetEmail != null) 'email': targetEmail,
                }),
              )
              .timeout(const Duration(seconds: 8));

          return response.statusCode == 200 || response.statusCode == 201;
        } catch (e) {
          debugPrint('BackendApiService updateProfilePhoto network error: $e');
          return false;
        }
      }
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // LIVE ROOMS SYNC (Real User Created Only — No Demos)
  // ---------------------------------------------------------------------------

  static bool isDemoRoom(RoomModel room) {
    return RoomModel.isDemoRoom(room);
  }

  Future<List<RoomModel>> getRooms() async {
    if (!isTestMode && BackendConfig.isConfigured) {
      try {
        final uri = Uri.parse('${BackendConfig.apiBaseUrl}/api/v1/rooms');
        final response = await http
            .get(
              uri,
              headers: {
                if (BackendConfig.apiKey.isNotEmpty)
                  'x-api-key': BackendConfig.apiKey,
              },
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data
                .map((item) =>
                    RoomModel.fromMap(Map<String, dynamic>.from(item)))
                .where((r) => !isDemoRoom(r))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('BackendApiService getRooms error: $e');
      }
    }
    final local = await LocalStorageService.loadActiveRooms();
    return local.where((r) => !isDemoRoom(r)).toList();
  }

  Future<bool> createRoom(RoomModel room) async {
    if (isDemoRoom(room)) return false;
    if (!isTestMode && BackendConfig.isConfigured) {
      try {
        final uri = Uri.parse('${BackendConfig.apiBaseUrl}/api/v1/rooms');
        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                if (BackendConfig.apiKey.isNotEmpty)
                  'x-api-key': BackendConfig.apiKey,
              },
              body: jsonEncode(room.toMap()),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 || response.statusCode == 201) {
          return true;
        }
      } catch (e) {
        debugPrint('BackendApiService createRoom error: $e');
      }
    }
    return true;
  }

  Future<bool> deleteRoom(String roomId) async {
    if (!isTestMode && BackendConfig.isConfigured) {
      try {
        final uri =
            Uri.parse('${BackendConfig.apiBaseUrl}/api/v1/rooms/$roomId');
        await http.delete(
          uri,
          headers: {
            if (BackendConfig.apiKey.isNotEmpty)
              'x-api-key': BackendConfig.apiKey,
          },
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('BackendApiService deleteRoom error: $e');
      }
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // SOCIAL SEARCH & FOLLOW APIS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return [];

    final results = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    final qLower = cleanQ.toLowerCase().replaceAll('@', '');

    // 1. Search AWS Cloud Storage (DynamoDB / API Gateway)
    try {
      final awsResults = await AwsStorageService.searchUsers(cleanQ);
      for (final u in awsResults) {
        final id = (u['id'] ?? u['securityId'] ?? u['userId'] ?? '').toString();
        if (id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          results.add(u);
        }
      }
    } catch (e) {
      debugPrint('searchUsers aws query error: $e');
    }

    // 2. Search currently logged in user
    final current = AuthService().currentUser;
    if (current != null) {
      final cName = current.name.toLowerCase();
      final cTag = current.tag.toLowerCase().replaceAll('@', '');
      final cEmail = current.email.toLowerCase();
      final cId = current.id.toLowerCase();

      if (cId.contains(qLower) ||
          cTag.contains(qLower) ||
          cName.contains(qLower) ||
          cEmail.contains(qLower)) {
        if (!seenIds.contains(current.id)) {
          seenIds.add(current.id);
          results.add({
            'id': current.id,
            'securityId': current.id,
            'name': current.name,
            'gamerTag': current.tag,
            'email': current.email,
            'level': current.level,
            'coins': current.coins,
            'totalWins': current.totalWins,
            'profilePhoto': current.profilePhoto,
            'followersCount': VoiceRoomManager().getUserFollowers(current.name),
            'followingCount': VoiceRoomManager().getUserFollowing(current.name),
            'visitorsCount': VoiceRoomManager().getUserVisitors(current.name),
          });
        }
      }
    }

    // 3. Search local registered users
    for (final u in AuthService().registeredUsers) {
      final nameLower = u.name.toLowerCase();
      final tagLower = u.tag.toLowerCase().replaceAll('@', '');
      final emailLower = u.email.toLowerCase();
      final idLower = u.id.toLowerCase();

      if (tagLower.contains(qLower) ||
          idLower.contains(qLower) ||
          nameLower.contains(qLower) ||
          emailLower.contains(qLower)) {
        if (!seenIds.contains(u.id)) {
          seenIds.add(u.id);
          results.add({
            'id': u.id,
            'securityId': u.id,
            'name': u.name,
            'gamerTag': u.tag,
            'email': u.email,
            'level': u.level,
            'coins': u.coins,
            'totalWins': u.totalWins,
            'profilePhoto': u.profilePhoto,
            'followersCount': VoiceRoomManager().getUserFollowers(u.name),
            'followingCount': VoiceRoomManager().getUserFollowing(u.name),
            'visitorsCount': VoiceRoomManager().getUserVisitors(u.name),
          });
        }
      }
    }

    // 4. Search in-memory / mock server users
    for (final u in _mockServerUsers.values) {
      final nameLower = u.name.toLowerCase();
      final tagLower = u.tag.toLowerCase().replaceAll('@', '');
      final emailLower = u.email.toLowerCase();
      final idLower = u.id.toLowerCase();

      if (tagLower.contains(qLower) ||
          idLower.contains(qLower) ||
          nameLower.contains(qLower) ||
          emailLower.contains(qLower)) {
        if (!seenIds.contains(u.id)) {
          seenIds.add(u.id);
          results.add({
            'id': u.id,
            'securityId': u.id,
            'name': u.name,
            'gamerTag': u.tag,
            'email': u.email,
            'level': u.level,
            'coins': u.coins,
            'totalWins': u.trophies,
            'profilePhoto': null,
            'followersCount': VoiceRoomManager().getUserFollowers(u.name),
            'followingCount': VoiceRoomManager().getUserFollowing(u.name),
            'visitorsCount': VoiceRoomManager().getUserVisitors(u.name),
          });
        }
      }
    }

    return results;
  }

  Future<Map<String, dynamic>> followUser({
    required String followerEmail,
    required String followerName,
    required String targetGamerTagOrId,
    bool follow = true,
  }) async {
    if (!isTestMode && BackendConfig.isConfigured) {
      try {
        final uri =
            Uri.parse('${BackendConfig.apiBaseUrl}/api/v1/users/follow');
        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                if (BackendConfig.apiKey.isNotEmpty)
                  'x-api-key': BackendConfig.apiKey,
              },
              body: jsonEncode({
                'followerEmail': followerEmail,
                'followerName': followerName,
                'targetGamerTagOrId': targetGamerTagOrId,
                'follow': follow,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          return Map<String, dynamic>.from(jsonDecode(response.body));
        }
      } catch (e) {
        debugPrint('BackendApiService followUser error: $e');
      }
    }
    return {'success': true, 'isFollowing': follow};
  }

  // ---------------------------------------------------------------------------
  // SYNCHRONOUS TEST HELPERS (FOR ISOLATED UNIT TESTS ONLY)
  // ---------------------------------------------------------------------------

  String? getTestMockOtp(String email, {String? purpose}) {
    final cleanEmail = email.trim().toLowerCase();
    final list = _mockOtpDb[cleanEmail] ?? [];
    for (final r in list.reversed) {
      if (!r.isUsed &&
          DateTime.now().isBefore(r.expiresAt) &&
          (purpose == null || r.purpose == purpose)) {
        return r.code;
      }
    }
    return null;
  }

  String requestOtpSync({
    required String email,
    required String purpose,
    String? name,
  }) {
    initMockServer();
    final cleanEmail = email.trim().toLowerCase();
    final list = _mockOtpDb.putIfAbsent(cleanEmail, () => []);
    for (final r in list) {
      if (r.purpose == purpose) r.isUsed = true;
    }
    final code = SecurityHelper.generateSecure6DigitOtp();
    final now = DateTime.now();
    list.add(_MockOtpRecord(
      code: code,
      purpose: purpose,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
    ));
    _mockRateLimits['$cleanEmail:$purpose'] = now;
    return code;
  }

  bool verifyOtpSync({
    required String email,
    required String otp,
    required String purpose,
  }) {
    initMockServer();
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();
    final list = _mockOtpDb[cleanEmail] ?? [];
    _MockOtpRecord? active;
    for (int i = list.length - 1; i >= 0; i--) {
      if (list[i].purpose == purpose && !list[i].isUsed) {
        active = list[i];
        break;
      }
    }
    if (active == null) return false;
    final now = DateTime.now();
    if (now.isAfter(active.expiresAt)) {
      active.isUsed = true;
      return false;
    }
    if (active.failedAttempts >= 3) {
      active.isUsed = true;
      return false;
    }
    if (active.code != cleanOtp) {
      active.failedAttempts++;
      if (active.failedAttempts >= 3) {
        active.isUsed = true;
      }
      return false;
    }
    active.isUsed = true;
    final token =
        'pf_vtok_${SecurityHelper.generateUniqueSalt()}_${DateTime.now().millisecondsSinceEpoch}';
    _mockVerificationTokens[token] = _MockVerificationToken(
      email: cleanEmail,
      purpose: purpose,
      expiresAt: now.add(const Duration(minutes: 10)),
    );
    return true;
  }

  String? getValidVerificationTokenForEmail(String email, String purpose) {
    initMockServer();
    final cleanEmail = email.trim().toLowerCase();
    final now = DateTime.now();
    for (final entry in _mockVerificationTokens.entries) {
      if (entry.value.email == cleanEmail &&
          entry.value.purpose == purpose &&
          now.isBefore(entry.value.expiresAt)) {
        return entry.key;
      }
    }
    return null;
  }

  AuthBackendResult registerUserSync({
    required String name,
    required String tag,
    required String email,
    required String password,
    required String phoneNumber,
    required String countryCode,
    required String countryFlag,
    required Color avatarColor,
    String? verificationToken,
  }) {
    initMockServer();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

    if (verificationToken != null) {
      final vData = _mockVerificationTokens[verificationToken];
      if (vData == null ||
          vData.email != cleanEmail ||
          vData.purpose != 'registration' ||
          DateTime.now().isAfter(vData.expiresAt)) {
        return const AuthBackendResult(
          success: false,
          error: 'Unauthorized: Valid OTP verification token is required.',
        );
      }
      _mockVerificationTokens.remove(verificationToken);
    }

    if (_mockServerUsers.containsKey(cleanEmail)) {
      return const AuthBackendResult(
        success: false,
        error: 'This email is already registered on the server.',
      );
    }
    for (final u in _mockServerUsers.values) {
      if (u.phoneNumber.replaceAll(RegExp(r'\D'), '') == cleanPhone) {
        return const AuthBackendResult(
          success: false,
          error: 'This mobile number is already registered on the server.',
        );
      }
    }

    final newId = SecurityHelper.generateSecureUserId(
        (id) => _mockServerUsers.values.any((u) => u.id == id));
    final passwordHash = SecurityHelper.hashPassword(password);
    final sessionToken = SecurityHelper.generateSecureSessionToken();

    final serverUser = _MockServerUser(
      id: newId,
      name: name.trim(),
      tag: tag.trim(),
      email: cleanEmail,
      phoneNumber: cleanPhone,
      role: 'user', // STRICT: Regular user role
      passwordHash: passwordHash,
      level: 1,
      coins: 500,
      trophies: 0,
      unlockedGameIds: const ['tic_tac_toe'],
    );
    _mockServerUsers[cleanEmail] = serverUser;
    _mockSessions[sessionToken] = cleanEmail;

    // Persist credentials hash across app restarts
    try {
      LocalStorageService.loadUserCredentials().then((creds) {
        creds[cleanEmail] = passwordHash;
        if (cleanPhone.isNotEmpty) creds[cleanPhone] = passwordHash;
        creds[tag.trim().toLowerCase()] = passwordHash;
        LocalStorageService.saveUserCredentials(creds);
      });
    } catch (_) {}

    final clientUser = UserModel(
      id: newId,
      name: name.trim(),
      tag: tag.trim(),
      email: cleanEmail,
      phoneNumber: cleanPhone,
      countryCode: countryCode,
      countryFlag: countryFlag,
      avatarColor: avatarColor,
      avatarInitial:
          (name.trim().isNotEmpty ? name.trim()[0] : 'P').toUpperCase(),
      role: 'user',
      sessionToken: sessionToken,
      level: 1,
      coins: 500,
      trophies: 0,
      unlockedGameIds: const ['tic_tac_toe'],
    );

    return AuthBackendResult(
        success: true, user: clientUser, sessionToken: sessionToken);
  }

  AuthBackendResult loginUserSync({
    required String identifier,
    required String password,
  }) {
    initMockServer();
    final cleanId = identifier.trim().toLowerCase();
    final cleanPhone = cleanId.replaceAll(RegExp(r'\D'), '');

    _MockServerUser? target;
    if (_mockServerUsers.containsKey(cleanId)) {
      target = _mockServerUsers[cleanId];
    } else {
      for (final u in _mockServerUsers.values) {
        if (u.tag.toLowerCase() == cleanId ||
            u.tag.toLowerCase() == '@$cleanId' ||
            (cleanPhone.isNotEmpty &&
                u.phoneNumber.replaceAll(RegExp(r'\D'), '') == cleanPhone)) {
          target = u;
          break;
        }
      }
    }

    if (target == null) {
      return const AuthBackendResult(
        success: false,
        error: 'Account not found. Please check your credentials or register.',
      );
    }

    final isMatch =
        SecurityHelper.verifyPassword(password, target.passwordHash);
    if (!isMatch) {
      return const AuthBackendResult(
        success: false,
        error: 'Incorrect password. Please try again.',
      );
    }

    if (SecurityHelper.isLegacyHash(target.passwordHash)) {
      target.passwordHash = SecurityHelper.hashPassword(password);
    }

    final sessionToken = SecurityHelper.generateSecureSessionToken();
    _mockSessions[sessionToken] = target.email;

    final clientUser = UserModel(
      id: target.id,
      name: target.name,
      tag: target.tag,
      email: target.email,
      phoneNumber: target.phoneNumber,
      role: target.role,
      sessionToken: sessionToken,
      level: target.level,
      coins: target.coins,
      trophies: target.trophies,
      winRate: target.winRate,
      totalMatches: target.totalMatches,
      totalWins: target.totalWins,
      xp: target.xp,
      unlockedGameIds: target.unlockedGameIds,
      avatarColor: const Color(0xFF7C3AED),
      avatarInitial:
          target.name.isNotEmpty ? target.name[0].toUpperCase() : 'S',
    );

    return AuthBackendResult(
        success: true, user: clientUser, sessionToken: sessionToken);
  }

  String? sendForgotPasswordOtpSync(String email) {
    initMockServer();
    final cleanEmail = email.trim().toLowerCase();
    if (!_mockServerUsers.containsKey(cleanEmail)) {
      return 'No account found with this email address. Please register.';
    }

    final rateKey = '$cleanEmail:password_reset';
    final lastSent = _mockRateLimits[rateKey];
    final now = DateTime.now();
    if (lastSent != null && now.difference(lastSent).inSeconds < 60) {
      final rem = 60 - now.difference(lastSent).inSeconds;
      return 'Please wait $rem seconds before requesting another code.';
    }
    _mockRateLimits[rateKey] = now;

    final list = _mockOtpDb.putIfAbsent(cleanEmail, () => []);
    for (final r in list) {
      if (r.purpose == 'password_reset' || r.purpose == 'forgot_password') {
        r.isUsed = true;
      }
    }

    final code = SecurityHelper.generateSecure6DigitOtp();
    list.add(_MockOtpRecord(
      code: code,
      purpose: 'forgot_password',
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
    ));
    return null;
  }

  String? resetPasswordWithOtpSync({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    initMockServer();
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    if (newPassword.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    final list = _mockOtpDb[cleanEmail] ?? [];
    _MockOtpRecord? validRecord;
    for (int i = list.length - 1; i >= 0; i--) {
      if ((list[i].purpose == 'forgot_password' ||
              list[i].purpose == 'password_reset') &&
          !list[i].isUsed) {
        validRecord = list[i];
        break;
      }
    }

    if (validRecord == null || DateTime.now().isAfter(validRecord.expiresAt)) {
      return 'Invalid or expired 6-digit OTP. Please request a new code.';
    }

    if (validRecord.failedAttempts >= 3) {
      validRecord.isUsed = true;
      return 'Maximum verification attempts exceeded. Please request a new code.';
    }

    if (validRecord.code != cleanOtp) {
      validRecord.failedAttempts++;
      if (validRecord.failedAttempts >= 3) {
        validRecord.isUsed = true;
        return 'Maximum verification attempts exceeded. Please request a new code.';
      }
      final rem = 3 - validRecord.failedAttempts;
      return 'Incorrect OTP code. $rem attempts remaining.';
    }

    validRecord.isUsed = true;
    final target = _mockServerUsers[cleanEmail];
    if (target == null) {
      return 'User account not found.';
    }

    target.passwordHash = SecurityHelper.hashPassword(newPassword);
    _mockSessions.removeWhere((_, e) => e == cleanEmail);
    return null;
  }
}

// -----------------------------------------------------------------------------
// PRIVATE MOCK BACKEND DATA STRUCTURES
// -----------------------------------------------------------------------------

class _MockOtpRecord {
  final String code;
  final String purpose;
  final DateTime createdAt;
  final DateTime expiresAt;
  int failedAttempts = 0;
  bool isUsed;

  _MockOtpRecord({
    required this.code,
    required this.purpose,
    required this.createdAt,
    required this.expiresAt,
    this.isUsed = false,
  });

  bool get isEmpty => code.isEmpty;

  factory _MockOtpRecord.empty() => _MockOtpRecord(
        code: '',
        purpose: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(0),
        isUsed: true,
      );
}

class _MockVerificationToken {
  final String email;
  final String purpose;
  final DateTime expiresAt;

  _MockVerificationToken({
    required this.email,
    required this.purpose,
    required this.expiresAt,
  });
}

class _MockServerUser {
  final String id;
  final String name;
  final String tag;
  final String email;
  final String phoneNumber;
  final String role;
  String passwordHash;
  int level;
  int coins;
  int trophies;
  double winRate = 0.0;
  int totalMatches = 0;
  int totalWins = 0;
  int xp = 0;
  List<String> unlockedGameIds;

  _MockServerUser({
    required this.id,
    required this.name,
    required this.tag,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.passwordHash,
    this.level = 1,
    this.coins = 500,
    this.trophies = 0,
    this.unlockedGameIds = const ['tic_tac_toe'],
  });
}
