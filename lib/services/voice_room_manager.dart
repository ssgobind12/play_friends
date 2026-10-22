import 'dart:math';
import 'package:flutter/material.dart';
import '../models/room_model.dart';
import 'auth_service.dart';
import 'in_app_music_service.dart';

/// Level Progression Calculation according to user request:
/// 1000 coins -> Level 2 (1st Level Up)
/// 3000 coins -> Level 3 (2nd Level Up)
/// 5000 coins -> Level 4 (3rd Level Up)
/// 8000 coins -> Level 5
/// 12000 coins -> Level 6
class LevelProgressionService {
  static int calculateLevel(int coins) {
    if (coins >= 12000) return 6;
    if (coins >= 8000) return 5;
    if (coins >= 5000) return 4;
    if (coins >= 3000) return 3;
    if (coins >= 1000) return 2;
    return 1;
  }

  static int coinsForNextLevel(int currentCoins) {
    if (currentCoins < 1000) return 1000;
    if (currentCoins < 3000) return 3000;
    if (currentCoins < 5000) return 5000;
    if (currentCoins < 8000) return 8000;
    if (currentCoins < 12000) return 12000;
    return currentCoins + 5000;
  }
}

/// Global Voice Room Manager:
/// Controls active joined room, background mini-player, room admin permissions,
/// follow system, and gift-driven level increments.
class VoiceRoomManager extends ChangeNotifier {
  static final VoiceRoomManager _instance = VoiceRoomManager._internal();
  factory VoiceRoomManager() => _instance;

  VoiceRoomManager._internal();

  RoomModel? _activeRoom;
  RoomModel? get activeRoom => _activeRoom;
  bool get hasActiveRoom => _activeRoom != null;

  // Set of assigned room admins (by host)
  final Set<String> _roomAdmins = {};
  Set<String> get roomAdmins => Set.unmodifiable(_roomAdmins);

  // Followed rooms and follower counts
  final Set<String> _followedRoomCodes = {};
  final Map<String, int> _roomFollowerCounts = {};

  // Followed users (who current user is following)
  final Set<String> _followedUsers = {};

  // Followers of the current user (who follow current user)
  final Set<String> _userFollowers = {};

  // User stats (followers, following, visitors)
  final Map<String, int> _userFollowerCounts = {};
  final Map<String, int> _userFollowingCounts = {};
  final Map<String, int> _userVisitorCounts = {};

  Set<String> get followedRoomCodes => Set.unmodifiable(_followedRoomCodes);
  Set<String> get followedUsers => Set.unmodifiable(_followedUsers);
  Set<String> get userFollowers => Set.unmodifiable(_userFollowers);

  bool isFollowingRoom(String roomCode) =>
      _followedRoomCodes.contains(roomCode);
  bool isFollowingUser(String userName) => _followedUsers.contains(userName);
  bool isFollowedByUser(String userName) => _userFollowers.contains(userName);

  /// Direct chat is unlocked only when both users follow each other!
  bool isMutualFollow(String userName) =>
      isFollowingUser(userName) && isFollowedByUser(userName);

  int getRoomFollowers(String roomCode) {
    return _roomFollowerCounts[roomCode] ?? 120;
  }

  int getUserFollowers(String userName) {
    return _userFollowerCounts[userName] ?? 100;
  }

  int getUserFollowing(String userName) {
    return _userFollowingCounts[userName] ?? 25;
  }

  int getUserVisitors(String userName) {
    return _userVisitorCounts[userName] ?? 350;
  }

  void toggleFollowRoom(String roomCode) {
    final current = _roomFollowerCounts[roomCode] ?? 120;
    if (_followedRoomCodes.contains(roomCode)) {
      _followedRoomCodes.remove(roomCode);
      _roomFollowerCounts[roomCode] = max(0, current - 1);
    } else {
      _followedRoomCodes.add(roomCode);
      _roomFollowerCounts[roomCode] = current + 1;
    }
    notifyListeners();
  }

  void toggleFollowUser(String userName) {
    final current = _userFollowerCounts[userName] ?? 100;
    if (_followedUsers.contains(userName)) {
      _followedUsers.remove(userName);
      _userFollowerCounts[userName] = max(0, current - 1);
    } else {
      _followedUsers.add(userName);
      _userFollowerCounts[userName] = current + 1;
    }
    notifyListeners();
  }

  void setUserFollowsMe(String userName, bool follows) {
    if (follows) {
      _userFollowers.add(userName);
    } else {
      _userFollowers.remove(userName);
    }
    notifyListeners();
  }

  /// Sets the currently active room and starts room music
  void joinRoom(RoomModel room) {
    _activeRoom = room;
    _roomAdmins.clear();
    // Default: Host is always admin
    _roomAdmins.add(room.hostName);

    // Silent by default when creating or joining a room; starts only when player presses play!
    InAppMusicService().pauseMusic();
    notifyListeners();
  }

  /// Leaves the current room and stops room music
  void leaveRoom() {
    _activeRoom = null;
    _roomAdmins.clear();
    InAppMusicService().pauseMusic();
    notifyListeners();
  }

  /// Assign or remove Admin permission (Only host can do this)
  bool toggleAdminPermission(String userName) {
    if (_activeRoom == null) return false;
    if (userName == _activeRoom!.hostName) {
      // Host is always admin
      return true;
    }

    if (_roomAdmins.contains(userName)) {
      _roomAdmins.remove(userName);
    } else {
      _roomAdmins.add(userName);
    }
    notifyListeners();
    return _roomAdmins.contains(userName);
  }

  /// Checks if a user is Host or assigned Admin (Only they can control music)
  bool canControlMusic(String? userName) {
    if (userName == null || _activeRoom == null) return false;
    return userName == _activeRoom!.hostName || _roomAdmins.contains(userName);
  }

  /// Records a gift sent in the room:
  /// Increases Room Charm / Points, Room Level, and Sender User ID Level!
  void recordGiftSent({
    required int coins,
    required String senderName,
  }) {
    if (_activeRoom == null) return;

    // 1. Update Room gift points & level
    final currentPoints = _activeRoom!.giftPoints + coins;

    _activeRoom = _activeRoom!.copyWith(
      giftPoints: currentPoints,
      currentPlayers: max(_activeRoom!.currentPlayers, 1),
    );

    // 2. Update User level in AuthService if sender is current user
    final auth = AuthService();
    final user = auth.currentUser;
    if (user != null && user.name == senderName) {
      final updatedXp = user.xp + coins;
      final calculatedUserLevel =
          LevelProgressionService.calculateLevel(updatedXp);
      final newLevel = max(user.level, calculatedUserLevel);

      auth.promoteLevelFromCoins(coins, newLevel);
    }

    notifyListeners();
  }
}
