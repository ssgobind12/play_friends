import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';

/// LocalStorageService: Persists user profile, uploaded music tracks, and
/// user-created rooms to Android SharedPreferences and offline local disk.
/// Retains all state across app minimizations, swipe-aways, and complete restarts.
class LocalStorageService {
  static const MethodChannel _channel =
      MethodChannel('com.playfriends.game_sound');
  static final Map<String, String> _memoryFallback = {};

  static const String keyCurrentUser = 'pf_current_user_v1';
  static const String keyRegisteredUsers = 'pf_registered_users_v1';
  static const String keyUserCredentials = 'pf_user_credentials_v1';
  static const String keyActiveRooms = 'pf_active_rooms_v1';
  static const String prefixUserSongs = 'pf_user_songs_v1_';

  /// Save raw string value
  static Future<void> setString(String key, String value) async {
    _memoryFallback[key] = value;
    try {
      await _channel
          .invokeMethod('saveLocalData', {'key': key, 'value': value});
    } catch (_) {
      // In test or non-Android environment, use _memoryFallback
    }
  }

  /// Get raw string value
  static Future<String?> getString(String key) async {
    try {
      final res =
          await _channel.invokeMethod<String>('getLocalData', {'key': key});
      if (res != null && res.isNotEmpty) {
        _memoryFallback[key] = res;
        return res;
      }
    } catch (_) {}
    return _memoryFallback[key];
  }

  /// Get cached string synchronously from memory fallback
  static String? getStringSync(String key) => _memoryFallback[key];

  /// Remove key
  static Future<void> remove(String key) async {
    _memoryFallback.remove(key);
    try {
      await _channel.invokeMethod('removeLocalData', {'key': key});
    } catch (_) {}
  }

  // --------------------------------------------------------------------------
  // USER PROFILE & ACCOUNTS PERSISTENCE
  // --------------------------------------------------------------------------

  /// Persists current active logged-in user (including profilePhoto and stats)
  static Future<void> saveCurrentUser(UserModel? user) async {
    if (user == null) {
      await remove(keyCurrentUser);
      return;
    }
    final jsonStr = jsonEncode(user.toMap());
    await setString(keyCurrentUser, jsonStr);
  }

  /// Loads persisted active user, or null if no user logged in
  static Future<UserModel?> loadCurrentUser() async {
    final raw = await getString(keyCurrentUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return UserModel.fromMap(map);
      }
    } catch (_) {}
    return null;
  }

  /// Persists full list of registered accounts
  static Future<void> saveRegisteredUsers(List<UserModel> users) async {
    final list = users.map((u) => u.toMap()).toList();
    final jsonStr = jsonEncode(list);
    await setString(keyRegisteredUsers, jsonStr);
  }

  /// Loads full list of registered accounts
  static Future<List<UserModel>> loadRegisteredUsers() async {
    final raw = await getString(keyRegisteredUsers);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .map((item) => UserModel.fromMap(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Persists user credentials (email/identifier -> secure password hash)
  static Future<void> saveUserCredentials(
      Map<String, String> credentials) async {
    final jsonStr = jsonEncode(credentials);
    await setString(keyUserCredentials, jsonStr);
  }

  /// Loads persisted user credentials
  static Future<Map<String, String>> loadUserCredentials() async {
    final raw = await getString(keyUserCredentials);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw);
      if (map is Map) {
        return map.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  // --------------------------------------------------------------------------
  // USER CREATED ROOMS PERSISTENCE
  // --------------------------------------------------------------------------

  /// Persists user-created active rooms across app restarts
  static Future<void> saveActiveRooms(List<RoomModel> rooms) async {
    final list = rooms.map((r) => r.toMap()).toList();
    final jsonStr = jsonEncode(list);
    await setString(keyActiveRooms, jsonStr);
  }

  /// Loads user-created rooms persisted on local disk
  static Future<List<RoomModel>> loadActiveRooms() async {
    final raw = await getString(keyActiveRooms);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .map((item) => RoomModel.fromMap(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // --------------------------------------------------------------------------
  // USER UPLOADED SONGS PERSISTENCE
  // --------------------------------------------------------------------------

  /// Persists custom music tracks uploaded by a specific user
  static Future<void> saveUserSongs(
      String userId, List<Map<String, dynamic>> songs) async {
    final key = '$prefixUserSongs$userId';
    final jsonStr = jsonEncode(songs);
    await setString(key, jsonStr);
  }

  /// Loads custom music tracks uploaded by a specific user from local disk
  static Future<List<Map<String, dynamic>>> loadUserSongs(String userId) async {
    final key = '$prefixUserSongs$userId';
    final raw = await getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Clears testing data
  static void resetInMemoryForTesting() {
    _memoryFallback.clear();
  }
}
