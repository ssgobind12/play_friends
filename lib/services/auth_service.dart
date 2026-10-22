import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/friend_model.dart';
import '../models/room_model.dart';
import '../services/aws_storage_service.dart';
import '../services/backend_api_service.dart';
import '../services/in_app_music_service.dart';
import '../services/local_storage_service.dart';
import '../services/voice_room_manager.dart';
import '../theme/app_theme.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  static const UserModel adminUser = UserModel(
    id: '010001',
    name: 'Shubham Singh',
    tag: '@ssgobind12',
    email: 'ssgobind12@gmail.com',
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
    role: 'admin',
    sessionToken: 'pf_admin_verified_session',
    unlockedGameIds: [
      'tic_tac_toe',
      'ludo',
      'carrom',
      'space_dodge',
      'arena_brawl',
      'word_rush'
    ],
    friends: [],
  );

  AuthService._internal() {
    _registeredUsers = [];
    _currentUser = null; // Unauthenticated on initial launch
  }

  late List<UserModel> _registeredUsers;
  UserModel? _currentUser;
  bool _initialized = false;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  List<UserModel> get registeredUsers => List.unmodifiable(_registeredUsers);

  /// Loads persisted user, registered accounts, custom rooms, and songs from disk
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final savedUsers = await LocalStorageService.loadRegisteredUsers();
      if (savedUsers.isNotEmpty) {
        _registeredUsers = savedUsers;
      }

      final savedCurrent = await LocalStorageService.loadCurrentUser();
      if (savedCurrent != null &&
          savedCurrent.sessionToken != null &&
          savedCurrent.sessionToken!.isNotEmpty) {
        // Restore saved session immediately so user is never logged out on app restart/close
        _currentUser = savedCurrent;
        final idx = _registeredUsers.indexWhere((u) => u.id == savedCurrent.id);
        if (idx != -1) {
          _registeredUsers[idx] = savedCurrent;
        } else {
          _registeredUsers.add(savedCurrent);
        }

        // Validate asynchronously if online, but never log out user on network drops or offline restarts
        try {
          final validation = await BackendApiService()
              .validateSession(savedCurrent.sessionToken!);
          if (validation.success && validation.user != null) {
            _currentUser = validation.user;
            final uIdx =
                _registeredUsers.indexWhere((u) => u.id == validation.user!.id);
            if (uIdx != -1) {
              _registeredUsers[uIdx] = validation.user!;
            } else {
              _registeredUsers.add(validation.user!);
            }
          }
        } catch (_) {}
      } else {
        _currentUser = null; // Unauthenticated
      }

      final savedRooms = await LocalStorageService.loadActiveRooms();
      _activeRooms.clear();
      _activeRooms.addAll(savedRooms.where((r) => !RoomModel.isDemoRoom(r)));
      LocalStorageService.saveActiveRooms(_activeRooms);

      await VoiceRoomManager().init();

      if (_currentUser != null) {
        _syncCurrentUserToRegisteredUsers();
        await InAppMusicService().loadUserSongs(_currentUser!.id);
      }
    } catch (e) {
      debugPrint('AuthService init error: $e');
    }
    notifyListeners();
  }

  void _syncCurrentUserToRegisteredUsers() {
    if (_currentUser == null) return;
    final idx = _registeredUsers.indexWhere((u) => u.id == _currentUser!.id);
    if (idx != -1) {
      _registeredUsers[idx] = _currentUser!;
    } else {
      _registeredUsers.add(_currentUser!);
    }
    LocalStorageService.saveRegisteredUsers(_registeredUsers);
  }

  void _persistState() {
    LocalStorageService.saveCurrentUser(_currentUser);
    LocalStorageService.saveRegisteredUsers(_registeredUsers);
    LocalStorageService.saveActiveRooms(_activeRooms);
  }

  // --------------------------------------------------------------------------
  // OTP GENERATION & VERIFICATION (Cryptographically Secure 6-digit One-Time Codes)
  // --------------------------------------------------------------------------

  /// Generates and records a 6-digit one-time OTP for email registration
  String generateRegistrationOtp(String email, {String name = ''}) {
    return BackendApiService().requestOtpSync(
      email: email,
      purpose: 'registration',
      name: name,
    );
  }

  /// Async OTP request dispatching through trusted backend (with Brevo)
  Future<OtpRequestResult> generateRegistrationOtpAsync(String email,
      {String name = ''}) async {
    return BackendApiService().requestOtp(
      email: email,
      purpose: 'registration',
      name: name,
    );
  }

  /// Verifies a 6-digit one-time OTP for registration (Single-use, max 3 attempts, 5-min expiry)
  bool verifyRegistrationOtp(String email, String otp) {
    return BackendApiService().verifyOtpSync(
      email: email,
      otp: otp,
      purpose: 'registration',
    );
  }

  /// Async OTP verification against trusted backend
  Future<OtpVerifyResult> verifyRegistrationOtpAsync(
      String email, String otp) async {
    return BackendApiService().verifyOtp(
      email: email,
      otp: otp,
      purpose: 'registration',
    );
  }

  /// Generates and sends a 6-digit one-time OTP for forgot password
  String? sendForgotPasswordOtp(String email) {
    return BackendApiService().sendForgotPasswordOtpSync(email);
  }

  /// Async forgot password OTP request dispatching through trusted backend.
  /// Returns null on success, or an error message string on failure.
  /// If in demo mode, success message starts with "DEMO_OTP:" followed by the code.
  Future<OtpRequestResult> sendForgotPasswordOtpAsync(String email) async {
    return BackendApiService().requestOtp(
      email: email,
      purpose: 'password_reset',
    );
  }

  /// Verifies 6-digit OTP and resets user password with unique salt PBKDF2/scrypt
  String? resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    final err = BackendApiService().resetPasswordWithOtpSync(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
    if (err == null) {
      if (_currentUser?.email.toLowerCase() == email.trim().toLowerCase()) {
        _currentUser = null;
      }
      _persistState();
      notifyListeners();
    }
    return err;
  }

  /// Async password reset with trusted backend
  Future<String?> resetPasswordWithOtpAsync({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final verifyRes = await BackendApiService().verifyOtp(
      email: cleanEmail,
      otp: otp,
      purpose: 'password_reset',
    );
    if (!verifyRes.success || verifyRes.verificationToken == null) {
      return verifyRes.message;
    }

    final resetRes = await BackendApiService().resetPassword(
      email: cleanEmail,
      newPassword: newPassword,
      verificationToken: verifyRes.verificationToken!,
    );
    if (!resetRes.success) {
      return resetRes.error ?? 'Password reset failed.';
    }

    if (_currentUser?.email.toLowerCase() == cleanEmail) {
      _currentUser = null;
    }
    _persistState();
    notifyListeners();
    return null;
  }

  /// Helper to get the latest active OTP code for test/debug verification (visible for testing only)
  @visibleForTesting
  String? getLatestOtpForEmail(String email, {String? purpose}) {
    return BackendApiService().getTestMockOtp(email, purpose: purpose);
  }

  // --------------------------------------------------------------------------
  // AUTHENTICATION & SESSION MANAGEMENT
  // --------------------------------------------------------------------------

  String? login(String identifier, String password) {
    final result = BackendApiService().loginUserSync(
      identifier: identifier,
      password: password,
    );
    if (!result.success || result.user == null) {
      return result.error ?? 'Invalid credentials.';
    }

    _currentUser = result.user;
    final idx = _registeredUsers.indexWhere((u) => u.id == result.user!.id);
    if (idx != -1) {
      _registeredUsers[idx] = result.user!;
    } else {
      _registeredUsers.add(result.user!);
    }

    InAppMusicService().loadUserSongs(_currentUser!.id);
    _persistState();
    notifyListeners();
    return null; // Success
  }

  Future<String?> loginAsync(String identifier, String password) async {
    final result = await BackendApiService().loginUser(
      identifier: identifier,
      password: password,
    );
    if (!result.success || result.user == null) {
      return result.error ?? 'Invalid credentials.';
    }

    _currentUser = result.user;
    final idx = _registeredUsers.indexWhere((u) => u.id == result.user!.id);
    if (idx != -1) {
      _registeredUsers[idx] = result.user!;
    } else {
      _registeredUsers.add(result.user!);
    }

    await InAppMusicService().loadUserSongs(_currentUser!.id);
    _persistState();
    notifyListeners();
    return null; // Success
  }

  /// Generates a strictly unique Gamer Tag from the user's email ID (1 Email ID = 1 Gamer Tag, zero duplicates).
  String generateUniqueTagFromEmail(String email) {
    final cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail.contains('@')) return '@gamer';

    final prefix = cleanEmail.split('@').first;
    // Keep letters, digits, and underscores
    var cleanPrefix = prefix.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    cleanPrefix = cleanPrefix.replaceAll(RegExp(r'_+'), '_');
    if (cleanPrefix.startsWith('_')) cleanPrefix = cleanPrefix.substring(1);
    if (cleanPrefix.endsWith('_')) {
      cleanPrefix = cleanPrefix.substring(0, cleanPrefix.length - 1);
    }
    if (cleanPrefix.length < 3) cleanPrefix = '${cleanPrefix}_play';
    if (cleanPrefix.length > 15) cleanPrefix = cleanPrefix.substring(0, 15);

    final candidate = '@${cleanPrefix.toLowerCase()}';

    // If this email is already registered, return their existing tag
    for (final u in _registeredUsers) {
      if (u.email.toLowerCase() == cleanEmail) {
        return u.tag.toLowerCase();
      }
    }

    // Ensure zero duplicate gamer tags across all accounts
    var finalTag = candidate;
    var suffix = 1;
    while (_registeredUsers.any((u) =>
        u.tag.toLowerCase() == finalTag &&
        u.email.toLowerCase() != cleanEmail)) {
      finalTag = '$candidate$suffix';
      suffix++;
    }
    return finalTag;
  }

  void addRegisteredUserForTesting(UserModel user) {
    _registeredUsers.add(user);
  }

  void setCurrentUserForTesting(UserModel? user) {
    _currentUser = user;
    if (user != null) {
      final idx = _registeredUsers.indexWhere((u) => u.id == user.id);
      if (idx == -1) {
        _registeredUsers.add(user);
      } else {
        _registeredUsers[idx] = user;
      }
    }
    notifyListeners();
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
    final formattedTag = tag.trim().startsWith('@')
        ? tag.trim().toLowerCase()
        : '@${tag.trim().toLowerCase()}';
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
      if (user.phoneNumber != null &&
          user.phoneNumber!.replaceAll(RegExp(r'\D'), '') == cleanPhone) {
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
      return awsCheck.message ??
          'This email or mobile number is already registered in AWS.';
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
    String? verificationToken,
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

    final token = verificationToken ??
        BackendApiService().getValidVerificationTokenForEmail(
            email.trim().toLowerCase(), 'registration');

    final result = BackendApiService().registerUserSync(
      name: name,
      tag: tag,
      email: email,
      password: password,
      phoneNumber: phoneNumber,
      countryCode: countryCode,
      countryFlag: countryFlag,
      avatarColor: avatarColor,
      verificationToken: token,
    );

    if (!result.success || result.user == null) {
      return result.error ?? 'Registration failed.';
    }

    final newUser = result.user!;
    _registeredUsers.add(newUser);
    _currentUser = newUser;

    // Persist to AWS Cloud Storage / DynamoDB
    AwsStorageService.storeUser(newUser);

    _persistState();
    notifyListeners();
    return null; // Success
  }

  /// Async registration validating uniqueness with AWS and registering via trusted backend
  Future<String?> registerAsync({
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
    final validationError = await validateRegistrationDetailsAsync(
      name: name,
      tag: tag,
      email: email,
      password: password,
      phoneNumber: phoneNumber,
    );

    if (validationError != null) {
      return validationError;
    }

    final result = await BackendApiService().registerUser(
      name: name,
      tag: tag,
      email: email,
      password: password,
      phoneNumber: phoneNumber,
      countryCode: countryCode,
      countryFlag: countryFlag,
      avatarColor: avatarColor,
      verificationToken: verificationToken,
    );

    if (!result.success || result.user == null) {
      return result.error ?? 'Registration failed on server.';
    }

    final newUser = result.user!;
    _registeredUsers.add(newUser);
    _currentUser = newUser;

    await AwsStorageService.storeUser(newUser);

    _persistState();
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
      role: 'user',
      sessionToken: 'guest_session_$randomDigits',
    );

    _currentUser = guestUser;
    _syncCurrentUserToRegisteredUsers();
    _persistState();
    notifyListeners();
  }

  void logout() {
    final token = _currentUser?.sessionToken;
    _currentUser = null;
    LocalStorageService.saveCurrentUser(null);
    if (token != null && token.isNotEmpty) {
      BackendApiService().logoutUser(token);
    }
    notifyListeners();
  }

  Future<void> logoutAsync() async {
    final token = _currentUser?.sessionToken;
    _currentUser = null;
    await LocalStorageService.saveCurrentUser(null);
    if (token != null && token.isNotEmpty) {
      await BackendApiService().logoutUser(token);
    }
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
    final newLevel =
        calculatedLevel > user.level ? calculatedLevel : user.level;

    final updatedUnlockedGames = List<String>.from(user.unlockedGameIds);
    String? newlyUnlockedTitle;

    // Check unlocks:
    // Game 2: Ludo Friends unlocks at Level 5 or 20 wins!
    if ((newLevel >= 5 || newWins >= 20) &&
        !updatedUnlockedGames.contains('ludo')) {
      updatedUnlockedGames.add('ludo');
      newlyUnlockedTitle = 'Ludo Friends';
    }
    // Game 3: Carrom Clash unlocks at Level 10 or 40 wins!
    if ((newLevel >= 10 || newWins >= 40) &&
        !updatedUnlockedGames.contains('carrom')) {
      updatedUnlockedGames.add('carrom');
      newlyUnlockedTitle ??= 'Carrom Clash';
    }
    // Game 4: Cyber Space Dodge unlocks at Level 15 or 60 wins!
    if ((newLevel >= 15 || newWins >= 60) &&
        !updatedUnlockedGames.contains('space_dodge')) {
      updatedUnlockedGames.add('space_dodge');
      newlyUnlockedTitle ??= 'Cyber Space Dodge';
    }
    // Game 5: Neon Arena Brawl unlocks at Level 20 or 80 wins!
    if ((newLevel >= 20 || newWins >= 80) &&
        !updatedUnlockedGames.contains('arena_brawl')) {
      updatedUnlockedGames.add('arena_brawl');
      newlyUnlockedTitle ??= 'Neon Arena Brawl';
    }
    // Game 6: Word Sprint Rush unlocks at Level 25 or 100 wins!
    if ((newLevel >= 25 || newWins >= 100) &&
        !updatedUnlockedGames.contains('word_rush')) {
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

    _persistState();
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
    if (gameId == 'ludo') {
      return _currentUser!.level >= 5 || _currentUser!.totalWins >= 20;
    }
    if (gameId == 'carrom') {
      return _currentUser!.level >= 10 || _currentUser!.totalWins >= 40;
    }
    if (gameId == 'space_dodge') {
      return _currentUser!.level >= 15 || _currentUser!.totalWins >= 60;
    }
    if (gameId == 'arena_brawl') {
      return _currentUser!.level >= 20 || _currentUser!.totalWins >= 80;
    }
    if (gameId == 'word_rush') {
      return _currentUser!.level >= 25 || _currentUser!.totalWins >= 100;
    }
    return false;
  }

  /// Instantly unlocks all games (useful for testing and admin play)
  void unlockAllGames() {
    if (_currentUser == null) return;
    final allGames = [
      'tic_tac_toe',
      'ludo',
      'carrom',
      'space_dodge',
      'arena_brawl',
      'word_rush'
    ];
    _currentUser = _currentUser!.copyWith(
      unlockedGameIds: allGames,
      level: _currentUser!.level < 5 ? 5 : _currentUser!.level,
      totalWins: _currentUser!.totalWins < 20 ? 20 : _currentUser!.totalWins,
    );
    _persistState();
    notifyListeners();
  }

  /// Update active player profile photo or avatar preset
  void updateProfilePhoto(String? photo) {
    if (_currentUser == null) return;
    final userId = _currentUser!.id;
    final email = _currentUser!.email;
    final sessionToken = _currentUser!.sessionToken;

    _currentUser = _currentUser!.copyWith(
      profilePhoto: photo,
      clearProfilePhoto: photo == null,
    );
    final idx = _registeredUsers.indexWhere((u) => u.id == _currentUser!.id);
    if (idx != -1) {
      _registeredUsers[idx] = _currentUser!;
    }

    // Sync to backend with session token authorization
    if (sessionToken != null && sessionToken.isNotEmpty) {
      BackendApiService().updateProfilePhoto(
        sessionToken: sessionToken,
        profilePhoto: photo,
        targetEmail: email,
      );
    }

    // Sync to AWS cloud storage server (saves or removes from server)
    AwsStorageService.updateUserProfilePhoto(
      userId: userId,
      email: email,
      profilePhoto: photo,
    );

    _persistState();
    notifyListeners();
  }

  /// Update active player display name and gamer tag
  void updateProfileDetails({required String name, required String tag}) {
    if (_currentUser == null) return;
    final cleanName = name.trim();
    final cleanTag = tag.trim().startsWith('@')
        ? tag.trim().toLowerCase()
        : '@${tag.trim().toLowerCase()}';
    final initial = cleanName.isNotEmpty
        ? cleanName[0].toUpperCase()
        : _currentUser!.avatarInitial;
    _currentUser = _currentUser!.copyWith(
      name: cleanName,
      tag: cleanTag,
      avatarInitial: initial,
    );
    final idx = _registeredUsers.indexWhere((u) => u.id == _currentUser!.id);
    if (idx != -1) {
      _registeredUsers[idx] = _currentUser!;
    }
    _persistState();
    notifyListeners();
  }

  /// Permanently deletes only the active user's own account and all associated data everywhere
  /// Update extended account profile attributes (gender, birthday, interests, education, etc.)
  void updateExtendedProfile({
    String? name,
    String? gender,
    String? birthday,
    List<String>? interests,
    String? education,
    String? school,
    String? occupation,
    String? spokenLanguages,
    String? aboutMe,
    String? sportsAnswer,
    String? musicAnswer,
    String? foodAnswer,
  }) {
    if (_currentUser == null) return;
    final cleanName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : _currentUser!.name;
    final initial = cleanName.isNotEmpty
        ? cleanName[0].toUpperCase()
        : _currentUser!.avatarInitial;

    _currentUser = _currentUser!.copyWith(
      name: cleanName,
      avatarInitial: initial,
      gender: gender ?? _currentUser!.gender,
      birthday: birthday ?? _currentUser!.birthday,
      interests: interests ?? _currentUser!.interests,
      education: education ?? _currentUser!.education,
      school: school ?? _currentUser!.school,
      occupation: occupation ?? _currentUser!.occupation,
      spokenLanguages: spokenLanguages ?? _currentUser!.spokenLanguages,
      aboutMe: aboutMe ?? _currentUser!.aboutMe,
      sportsAnswer: sportsAnswer ?? _currentUser!.sportsAnswer,
      musicAnswer: musicAnswer ?? _currentUser!.musicAnswer,
      foodAnswer: foodAnswer ?? _currentUser!.foodAnswer,
    );

    final idx = _registeredUsers.indexWhere((u) => u.id == _currentUser!.id);
    if (idx != -1) {
      _registeredUsers[idx] = _currentUser!;
    }
    _persistState();
    notifyListeners();
  }

  bool deleteCurrentUser() {
    if (_currentUser == null) return false;
    final currentUserId = _currentUser!.id;
    final currentUserEmail = _currentUser!.email;
    final currentUserName = _currentUser!.name;

    // 1. Remove from registered users list
    _registeredUsers.removeWhere((u) =>
        u.id == currentUserId ||
        u.email.toLowerCase() == currentUserEmail.toLowerCase());

    // 2. Remove all active rooms created by this user
    _activeRooms.removeWhere((r) =>
        r.hostName == currentUserName ||
        r.hostName == '$currentUserName 👑' ||
        r.hostName.startsWith(currentUserName));

    // 3. Leave room if currently in a room
    VoiceRoomManager().leaveRoom();

    // 4. Remove custom songs uploaded by this user
    InAppMusicService().clearUserSongs(currentUserId);
    LocalStorageService.saveUserSongs(currentUserId, []);

    // 5. Remove user profile photo and cloud data
    AwsStorageService.deleteUserProfilePhoto(
      userId: currentUserId,
      email: currentUserEmail,
    );

    // 6. Delete user from backend/server auth database
    BackendApiService().deleteServerUser(currentUserEmail);

    // 7. Clear active logged in user and persist all cleared state
    _currentUser = null;
    _persistState();
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
    _persistState();
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
    _persistState();
    notifyListeners();
  }

  /// Promotes user level and XP based on gifts / coins
  void promoteLevelFromCoins(int addedXp, int newLevel) {
    if (_currentUser == null) return;
    final current = _currentUser!;
    _currentUser = current.copyWith(
      xp: current.xp + addedXp,
      level: max(current.level, newLevel),
    );
    final idx = _registeredUsers.indexWhere((u) => u.id == _currentUser!.id);
    if (idx != -1) {
      _registeredUsers[idx] = _currentUser!;
    }
    _persistState();
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // REAL FRIENDS MANAGEMENT (Fresh & Real)
  // --------------------------------------------------------------------------

  List<FriendModel> get friends => _currentUser?.friends ?? _localFriends;
  final List<FriendModel> _localFriends = [];

  void addFriend({
    required String name,
    required String tag,
    Color? avatarColor,
    int? level,
  }) {
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Player';
    final cleanTag = tag.trim().startsWith('@')
        ? tag.trim().toLowerCase()
        : '@${tag.trim().toLowerCase()}';
    final initial = cleanName[0].toUpperCase();
    const colors = [
      AppColors.primaryPurple,
      AppColors.primaryBlueLight,
      AppColors.onlineGreen,
      AppColors.accentCyan,
      AppColors.coinAmber,
    ];
    final color = avatarColor ?? colors[Random().nextInt(colors.length)];

    // Check if already in friends list
    final existing = friends;
    if (existing.any((f) =>
        f.name.toLowerCase() == cleanName.toLowerCase() ||
        f.tag.toLowerCase() == cleanTag.toLowerCase())) {
      return;
    }

    final newFriend = FriendModel(
      id: 'f_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      tag: cleanTag,
      initial: initial,
      avatarColor: color,
      level: level ?? 1,
      isOnline: true,
      statusText: 'Following',
      favoriteGame: 'Party Voice & Games',
    );

    if (_currentUser != null) {
      final updated = List<FriendModel>.from(_currentUser!.friends)
        ..add(newFriend);
      _currentUser = _currentUser!.copyWith(friends: updated);
    } else {
      _localFriends.add(newFriend);
    }
    _persistState();
    notifyListeners();
  }

  void removeFriend(String nameOrId) {
    final target = nameOrId.toLowerCase().trim();
    if (_currentUser != null) {
      final updated = List<FriendModel>.from(_currentUser!.friends)
        ..removeWhere((f) =>
            f.id == nameOrId ||
            f.name.toLowerCase() == target ||
            f.tag.toLowerCase() == target ||
            f.tag.toLowerCase() == '@$target');
      _currentUser = _currentUser!.copyWith(friends: updated);
    } else {
      _localFriends.removeWhere((f) =>
          f.id == nameOrId ||
          f.name.toLowerCase() == target ||
          f.tag.toLowerCase() == target ||
          f.tag.toLowerCase() == '@$target');
    }
    _persistState();
    notifyListeners();
  }

  // --------------------------------------------------------------------------
  // REAL ROOMS MANAGEMENT (Fresh & Real)
  // --------------------------------------------------------------------------

  static const List<RoomModel> defaultPartyRooms = [];

  final List<RoomModel> _activeRooms = [];
  List<RoomModel> get activeRooms => List.unmodifiable(_activeRooms);

  /// Synchronizes rooms created across devices
  Future<void> fetchRooms() async {
    try {
      final remoteRooms = await BackendApiService().getRooms();
      _activeRooms.removeWhere((r) => BackendApiService.isDemoRoom(r));
      if (remoteRooms.isNotEmpty) {
        // Merge without losing freshly created local rooms
        for (final r in remoteRooms) {
          if (!BackendApiService.isDemoRoom(r) &&
              !_activeRooms.any((local) => local.id == r.id || local.roomCode == r.roomCode)) {
            _activeRooms.add(r);
          }
        }
        _persistState();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AuthService fetchRooms error: $e');
    }
  }

  void addRoom(RoomModel room) {
    _activeRooms.removeWhere((r) => r.id == room.id || r.roomCode == room.roomCode);
    _activeRooms.insert(0, room);
    _persistState();
    BackendApiService().createRoom(room);
    notifyListeners();
  }

  /// Deletes a room created by user, persists updated room list, and leaves if inside it
  bool deleteRoom(String roomId) {
    final initialCount = _activeRooms.length;
    _activeRooms.removeWhere((r) => r.id == roomId || r.roomCode == roomId);
    final removed = _activeRooms.length < initialCount;
    if (removed) {
      if (VoiceRoomManager().activeRoom?.id == roomId ||
          VoiceRoomManager().activeRoom?.roomCode == roomId) {
        VoiceRoomManager().leaveRoom();
      }
      _persistState();
      BackendApiService().deleteRoom(roomId);
      notifyListeners();
    }
    return removed;
  }

  void resetStatsForTesting() {
    LocalStorageService.resetInMemoryForTesting();
    BackendApiService().resetMockForTesting();
    const testAlex = UserModel(
      id: '010002',
      email: 'alex@playfriends.io',
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
      role: 'user',
      sessionToken: 'pf_session_alex_test',
      unlockedGameIds: ['tic_tac_toe'],
      friends: [],
    );
    _currentUser = testAlex;
    _registeredUsers = [adminUser, testAlex];
    _activeRooms.clear();
    _localFriends.clear();
    _persistState();
    notifyListeners();
  }
}
