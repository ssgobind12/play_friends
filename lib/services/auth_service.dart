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

  static const UserModel adminUser = UserModel(
    id: '010001',
    name: 'Shubham Singh',
    tag: '@ssgobind12',
    email: 'ssgobind12@gamil.com',
    password: 'Shubham@003',
    phoneNumber: '8573029430',
    countryCode: '+91',
    countryFlag: '🇮🇳',
    avatarColor: AppColors.primaryPurple,
    avatarInitial: 'S',
    level: 50,
    coins: 99999,
    trophies: 999,
    winRate: 100.0,
    totalMatches: 200,
    totalWins: 200,
    xp: 20000,
    isAdmin: true,
    unlockedGameIds: ['tic_tac_toe', 'ludo', 'carrom', 'space_dodge', 'arena_brawl', 'word_rush'],
    friends: [],
  );

  AuthService._internal() {
    // Only the official Admin user pre-exists; all other users register with security ID starting with '01'
    _registeredUsers = [adminUser];
    _currentUser = adminUser;
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

  /// Generates a unique security ID starting with '01'
  String _generateSecurityId() {
    final rng = Random();
    String newId;
    do {
      final num = 100000 + rng.nextInt(900000);
      newId = '01$num';
    } while (_registeredUsers.any((u) => u.id == newId));
    return newId;
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
    final cleanPhone = identifier.replaceAll(RegExp(r'\D'), '');

    // 1. Direct Admin User Login
    final isAdminMatch = cleanId == 'ssgobind12@gamil.com' ||
        cleanId == 'ssgobind12@gmail.com' ||
        cleanPhone == '8573029430' ||
        cleanTag == '@ssgobind12';

    if (isAdminMatch) {
      if (password == 'Shubham@003') {
        _currentUser = adminUser;
        if (!_registeredUsers.any((u) => u.id == adminUser.id)) {
          _registeredUsers.add(adminUser);
        }
        notifyListeners();
        return null; // Success
      } else {
        return 'Incorrect password for Admin account.';
      }
    }

    UserModel? matchedUser;
    for (final user in _registeredUsers) {
      if (user.email.toLowerCase() == cleanId ||
          user.tag.toLowerCase() == cleanId ||
          user.tag.toLowerCase() == cleanTag ||
          (user.phoneNumber != null && user.phoneNumber!.replaceAll(RegExp(r'\D'), '') == cleanPhone)) {
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
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final newId = _generateSecurityId();
    final isAdmin = cleanEmail == 'ssgobind12@gamil.com' ||
        cleanEmail == 'ssgobind12@gmail.com' ||
        cleanPhone == '8573029430';

    final newUser = UserModel(
      id: newId,
      name: cleanName,
      tag: formattedTag,
      email: cleanEmail,
      password: password,
      phoneNumber: phoneNumber.trim(),
      countryCode: countryCode,
      countryFlag: countryFlag,
      avatarColor: avatarColor,
      avatarInitial: initial,
      level: isAdmin ? 50 : 1,
      coins: isAdmin ? 99999 : 500, // Starter coins
      trophies: isAdmin ? 999 : 5,
      winRate: 0.0,
      totalMatches: 0,
      totalWins: isAdmin ? 200 : 0,
      xp: isAdmin ? 20000 : 0,
      isAdmin: isAdmin,
      unlockedGameIds: isAdmin
          ? const ['tic_tac_toe', 'ludo', 'carrom', 'space_dodge', 'arena_brawl', 'word_rush']
          : const ['tic_tac_toe'],
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
    // Game 5: Neon Arena Brawl unlocks at Level 20 or 80 wins!
    if ((newLevel >= 20 || newWins >= 80) && !updatedUnlockedGames.contains('arena_brawl')) {
      updatedUnlockedGames.add('arena_brawl');
      newlyUnlockedTitle ??= 'Neon Arena Brawl';
    }
    // Game 6: Word Sprint Rush unlocks at Level 25 or 100 wins!
    if ((newLevel >= 25 || newWins >= 100) && !updatedUnlockedGames.contains('word_rush')) {
      updatedUnlockedGames.add('word_rush');
      newlyUnlockedTitle ??= 'Word Sprint';
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
    // Admin user has all games unlocked by default!
    if (_currentUser!.isAdmin) return true;
    if (_currentUser!.unlockedGameIds.contains(gameId)) return true;
    if (gameId == 'tic_tac_toe') return true;
    if (gameId == 'ludo') return _currentUser!.level >= 5 || _currentUser!.totalWins >= 20;
    if (gameId == 'carrom') return _currentUser!.level >= 10 || _currentUser!.totalWins >= 40;
    if (gameId == 'space_dodge') return _currentUser!.level >= 15 || _currentUser!.totalWins >= 60;
    if (gameId == 'arena_brawl') return _currentUser!.level >= 20 || _currentUser!.totalWins >= 80;
    if (gameId == 'word_rush') return _currentUser!.level >= 25 || _currentUser!.totalWins >= 100;
    return false;
  }

  /// Instantly unlocks all games (useful for testing and admin play)
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

  /// Update active player profile photo or avatar preset
  void updateProfilePhoto(String? photo) {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      profilePhoto: photo,
      clearProfilePhoto: photo == null,
    );
    final idx = _registeredUsers.indexWhere((u) => u.id == _currentUser!.id);
    if (idx != -1) {
      _registeredUsers[idx] = _currentUser!;
    }
    notifyListeners();
  }

  /// Update active player display name and gamer tag
  void updateProfileDetails({required String name, required String tag}) {
    if (_currentUser == null) return;
    final cleanName = name.trim();
    final cleanTag = tag.trim().startsWith('@') ? tag.trim().toLowerCase() : '@${tag.trim().toLowerCase()}';
    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : _currentUser!.avatarInitial;
    _currentUser = _currentUser!.copyWith(
      name: cleanName,
      tag: cleanTag,
      avatarInitial: initial,
    );
    final idx = _registeredUsers.indexWhere((u) => u.id == _currentUser!.id);
    if (idx != -1) {
      _registeredUsers[idx] = _currentUser!;
    }
    notifyListeners();
  }

  /// Permanently deletes only the active user's own account
  bool deleteCurrentUser() {
    if (_currentUser == null) return false;
    final currentUserId = _currentUser!.id;
    _registeredUsers.removeWhere((u) => u.id == currentUserId);
    _currentUser = null;
    notifyListeners();
    return true;
  }

  /// Deducts coins for sending gifts or entry fees
  bool spendCoins(int amount) {
    if (_currentUser == null || _currentUser!.coins < amount) return false;
    _currentUser = _currentUser!.copyWith(coins: _currentUser!.coins - amount);
    final idx = _registeredUsers.indexWhere((u) => u.id == _currentUser!.id);
    if (idx != -1) {
      _registeredUsers[idx] = _currentUser!;
    }
    notifyListeners();
    return true;
  }

  /// Adds coins for bonuses, rewards, or recharges
  void addCoins(int amount) {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(coins: _currentUser!.coins + amount);
    final idx = _registeredUsers.indexWhere((u) => u.id == _currentUser!.id);
    if (idx != -1) {
      _registeredUsers[idx] = _currentUser!;
    }
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

  static const List<RoomModel> defaultPartyRooms = [
    RoomModel(
      id: 'r_seed_1',
      roomCode: 'PF-8821',
      gameTitle: '🎵 Bollywood & Gaming Beats',
      hostName: 'Kabir 👑',
      currentPlayers: 142,
      maxPlayers: 250,
      isPrivate: false,
      status: 'Live Voice Party',
      giftPoints: 3400,
    ),
    RoomModel(
      id: 'r_seed_2',
      roomCode: 'PF-4912',
      gameTitle: '🎲 Ludo Friends & Gift Party',
      hostName: 'Aanya 🌸',
      currentPlayers: 88,
      maxPlayers: 150,
      isPrivate: false,
      status: 'Live Voice Party',
      giftPoints: 1850,
    ),
    RoomModel(
      id: 'r_seed_3',
      roomCode: 'PF-1034',
      gameTitle: '✨ Chill Lounge & Songs',
      hostName: 'Rohan 🎧',
      currentPlayers: 195,
      maxPlayers: 500,
      isPrivate: false,
      status: 'Live Voice Party',
      giftPoints: 5200,
    ),
  ];

  final List<RoomModel> _activeRooms = [];
  List<RoomModel> get activeRooms => List.unmodifiable(_activeRooms);

  void addRoom(RoomModel room) {
    _activeRooms.insert(0, room);
    notifyListeners();
  }

  void resetStatsForTesting() {
    const testAlex = UserModel(
      id: '010002',
      email: 'alex@playfriends.io',
      password: 'password123',
      phoneNumber: '9876543210',
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
    _currentUser = testAlex;
    _registeredUsers = [adminUser, testAlex];
    _activeRooms.clear();
    _localFriends.clear();
    _otpRecords.clear();
    notifyListeners();
  }
}
