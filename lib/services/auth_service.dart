import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/friend_model.dart';
import '../models/room_model.dart';
import '../services/aws_storage_service.dart';
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
    // Default clean users
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
        level: 1,
        coins: 500,
        trophies: 0,
        winRate: 0.0,
        totalMatches: 0,
        totalWins: 0,
        xp: 0,
        unlockedGameIds: ['tic_tac_toe'],
        friends: [],
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
        return 'This email is already used / registered. Please sign in or use another email.';
      }
      if (user.phoneNumber != null && user.phoneNumber!.replaceAll(RegExp(r'\D'), '') == cleanPhone) {
        return 'This mobile number is already used / registered. Please sign in or use another mobile number.';
      }
      if (user.tag.toLowerCase() == formattedTag) {
        return 'This gamer tag is already taken. Please choose another.';
      }
    }

    return null; // Valid
  }

  /// Async validation that also checks AWS Cloud Storage (DynamoDB / API Gateway)
  Future<String?> validateRegistrationDetailsAsync({
    required String name,
    required String tag,
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    final localError = validateRegistrationDetails(
      name: name,
      tag: tag,
      email: email,
      password: password,
      phoneNumber: phoneNumber,
    );
    if (localError != null) return localError;

    // Check AWS cloud storage
    final awsCheck = await AwsStorageService.checkUserExists(
      email: email,
      phoneNumber: phoneNumber,
    );
    if (awsCheck.exists) {
      return awsCheck.message ?? 'This email or mobile number is already registered in AWS.';
    }

    return null;
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
      coins: 500, // Starter coins
      trophies: 5,
      winRate: 0.0,
      totalMatches: 0,
    );

    _registeredUsers.add(newUser);
    _currentUser = newUser;

    // Persist to AWS Cloud Storage / DynamoDB
    AwsStorageService.storeUser(newUser);

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

  // --------------------------------------------------------------------------
  // GAME PROGRESSION & LEVEL UNLOCK SYSTEM
  // --------------------------------------------------------------------------

  /// Records match result, calculates XP/Coins/Wins, promotes player level,
  /// and automatically unlocks new games when reaching required level/wins.
  /// Returns title of newly unlocked game, or null if no new unlock occurred.
  String? recordMatchResult({required String gameId, required bool won}) {
    if (_currentUser == null) return null;

    final user = _currentUser!;
    final newMatches = user.totalMatches + 1;
    final newWins = user.totalWins + (won ? 1 : 0);
    final newCoins = user.coins + (won ? 50 : 15);
    final newTrophies = user.trophies + (won ? 1 : 0);
    final newXp = user.xp + (won ? 100 : 30);
    final newWinRate = newMatches > 0 ? ((newWins / newMatches) * 100) : 0.0;

    // Level progression: Player increases level every 4 wins!
    // Level 1: 0-3 wins
    // Level 2: 4-7 wins
    // Level 3: 8-11 wins
    // Level 4: 12-15 wins
    // Level 5: 16-19 wins (or 20 wins)
    final calculatedLevel = 1 + (newWins ~/ 4);
    final newLevel = calculatedLevel > user.level ? calculatedLevel : user.level;

    final updatedUnlockedGames = List<String>.from(user.unlockedGameIds);
    String? newlyUnlockedTitle;

    // Check unlocks:
    // Game 2: Ludo Friends unlocks at Level 5 or 20 wins!
    if ((newLevel >= 5 || newWins >= 20) && !updatedUnlockedGames.contains('ludo')) {
      updatedUnlockedGames.add('ludo');
      newlyUnlockedTitle = 'Ludo Friends';
    }
    // Game 3: Carrom Clash unlocks at Level 10 or 40 wins!
    if ((newLevel >= 10 || newWins >= 40) && !updatedUnlockedGames.contains('carrom')) {
      updatedUnlockedGames.add('carrom');
      newlyUnlockedTitle ??= 'Carrom Clash';
    }
    // Game 4: Cyber Space Dodge unlocks at Level 15 or 60 wins!
    if ((newLevel >= 15 || newWins >= 60) && !updatedUnlockedGames.contains('space_dodge')) {
      updatedUnlockedGames.add('space_dodge');
      newlyUnlockedTitle ??= 'Cyber Space Dodge';
    }

    _currentUser = user.copyWith(
      totalMatches: newMatches,
      totalWins: newWins,
      coins: newCoins,
      trophies: newTrophies,
      xp: newXp,
      level: newLevel,
      winRate: double.parse(newWinRate.toStringAsFixed(1)),
      unlockedGameIds: updatedUnlockedGames,
    );

    notifyListeners();
    return newlyUnlockedTitle;
  }

  /// Checks if a specific game is unlocked for the current player
  bool isGameUnlocked(String gameId) {
    if (_currentUser == null) return gameId == 'tic_tac_toe';
    if (_currentUser!.unlockedGameIds.contains(gameId)) return true;
    if (gameId == 'tic_tac_toe') return true;
    if (gameId == 'ludo') return _currentUser!.level >= 5 || _currentUser!.totalWins >= 20;
    if (gameId == 'carrom') return _currentUser!.level >= 10 || _currentUser!.totalWins >= 40;
    if (gameId == 'space_dodge') return _currentUser!.level >= 15 || _currentUser!.totalWins >= 60;
    return false;
  }

  /// Instantly unlocks all games (useful for testing and instant play)
  void unlockAllGames() {
    if (_currentUser == null) return;
    final allGames = ['tic_tac_toe', 'ludo', 'carrom', 'space_dodge', 'arena_brawl', 'word_rush'];
    _currentUser = _currentUser!.copyWith(
      unlockedGameIds: allGames,
      level: _currentUser!.level < 5 ? 5 : _currentUser!.level,
      totalWins: _currentUser!.totalWins < 20 ? 20 : _currentUser!.totalWins,
    );
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // REAL FRIENDS MANAGEMENT (Fresh & Real)
  // --------------------------------------------------------------------------

  List<FriendModel> get friends => _currentUser?.friends ?? _localFriends;
  final List<FriendModel> _localFriends = [];

  void addFriend({required String name, required String tag}) {
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Player';
    final cleanTag = tag.trim().startsWith('@') ? tag.trim().toLowerCase() : '@${tag.trim().toLowerCase()}';
    final initial = cleanName[0].toUpperCase();
    const colors = [
      AppColors.primaryPurple,
      AppColors.primaryBlueLight,
      AppColors.onlineGreen,
      AppColors.accentCyan,
      AppColors.coinAmber,
    ];
    final color = colors[Random().nextInt(colors.length)];

    final newFriend = FriendModel(
      id: 'f_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      tag: cleanTag,
      initial: initial,
      avatarColor: color,
      level: 1,
      isOnline: true,
      statusText: 'Online (Ready to Play)',
      favoriteGame: 'Tic-Tac-Toe',
    );

    if (_currentUser != null) {
      final updated = List<FriendModel>.from(_currentUser!.friends)..add(newFriend);
      _currentUser = _currentUser!.copyWith(friends: updated);
    } else {
      _localFriends.add(newFriend);
    }
    notifyListeners();
  }

  void removeFriend(String friendId) {
    if (_currentUser != null) {
      final updated = List<FriendModel>.from(_currentUser!.friends)..removeWhere((f) => f.id == friendId);
      _currentUser = _currentUser!.copyWith(friends: updated);
    } else {
      _localFriends.removeWhere((f) => f.id == friendId);
    }
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // REAL ROOMS MANAGEMENT (Fresh & Real)
  // --------------------------------------------------------------------------

  final List<RoomModel> _activeRooms = [];
  List<RoomModel> get activeRooms => List.unmodifiable(_activeRooms);

  void addRoom(RoomModel room) {
    _activeRooms.insert(0, room);
    notifyListeners();
  }

  void resetStatsForTesting() {
    _currentUser = const UserModel(
      id: 'u_alex',
      email: 'alex@playfriends.io',
      password: 'password123',
      name: 'Alex Vance',
      tag: '@alex_play',
      avatarColor: Color(0xFF8B5CF6),
      avatarInitial: 'A',
      level: 1,
      xp: 0,
      coins: 500,
      trophies: 0,
      totalMatches: 0,
      totalWins: 0,
      winRate: 0.0,
      unlockedGameIds: ['tic_tac_toe'],
      friends: [],
    );
    _activeRooms.clear();
    _localFriends.clear();
    notifyListeners();
  }
}
