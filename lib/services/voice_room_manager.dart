import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'aws_storage_service.dart';
import 'in_app_music_service.dart';
import 'local_storage_service.dart';

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

  /// Loads persisted followed users from local disk
  Future<void> init() async {
    try {
      final savedFollowed = await LocalStorageService.loadFollowedUsers();
      if (savedFollowed.isNotEmpty) {
        _followedUsers.clear();
        _followedUsers.addAll(savedFollowed);
      }
      final savedFollowers = await LocalStorageService.loadUserFollowers();
      if (savedFollowers.isNotEmpty) {
        _userFollowers.clear();
        _userFollowers.addAll(savedFollowers);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('VoiceRoomManager init error: $e');
    }
  }

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

  // Active room member list synced across devices
  Timer? _roomSyncTimer;
  List<Map<String, dynamic>> _activeRoomMembers = [];
  List<Map<String, dynamic>> get activeRoomMembers => List.unmodifiable(_activeRoomMembers);

  // Synchronized Mic Seats across all players in room
  List<dynamic> _micSeats = [];
  List<dynamic> get micSeats => List.unmodifiable(_micSeats);

  // Synchronized Room Music Track & Play State
  Map<String, dynamic>? _syncedRoomSong;
  Map<String, dynamic>? get syncedRoomSong => _syncedRoomSong;

  // Flag set when room is closed/deleted by host
  bool _activeRoomWasDeleted = false;
  bool get activeRoomWasDeleted => _activeRoomWasDeleted;
  void clearRoomDeletedFlag() => _activeRoomWasDeleted = false;

  // Flag set when user is kicked/removed by host
  bool _kickedFromRoom = false;
  bool get kickedFromRoom => _kickedFromRoom;
  void clearKickedFlag() => _kickedFromRoom = false;

  List<Map<String, dynamic>> _activeRoomMessages = [];
  List<Map<String, dynamic>> get activeRoomMessages =>
      List.unmodifiable(_activeRoomMessages);

  Set<String> get followedRoomCodes => Set.unmodifiable(_followedRoomCodes);
  Set<String> get followedUsers => Set.unmodifiable(_followedUsers);
  Set<String> get userFollowers => Set.unmodifiable(_userFollowers);

  bool isFollowingRoom(String roomCode) =>
      _followedRoomCodes.contains(roomCode);

  bool isFollowingUser(String query) {
    final clean = query.trim().toLowerCase().replaceAll('@', '');
    if (clean.isEmpty) return false;
    for (final u in _followedUsers) {
      if (u.trim().toLowerCase().replaceAll('@', '') == clean) return true;
    }
    final friends = AuthService().friends;
    for (final f in friends) {
      if (f.name.trim().toLowerCase() == clean ||
          f.tag.trim().toLowerCase().replaceAll('@', '') == clean) {
        return true;
      }
    }
    return false;
  }

  bool isFollowedByUser(String query) {
    final clean = query.trim().toLowerCase().replaceAll('@', '');
    if (clean.isEmpty) return false;
    for (final u in _userFollowers) {
      if (u.trim().toLowerCase().replaceAll('@', '') == clean) return true;
    }
    final friends = AuthService().friends;
    for (final f in friends) {
      if ((f.name.trim().toLowerCase() == clean ||
              f.tag.trim().toLowerCase().replaceAll('@', '') == clean) &&
          f.statusText.contains('Mutual')) {
        return true;
      }
    }
    return false;
  }

  /// Direct chat is unlocked when both users follow each other or have mutual badge!
  bool isMutualFollow(String userName) {
    final clean = userName.trim().toLowerCase().replaceAll('@', '');
    if (clean.isEmpty) return false;

    final friends = AuthService().friends;
    for (final f in friends) {
      if ((f.name.trim().toLowerCase() == clean ||
              f.tag.trim().toLowerCase().replaceAll('@', '') == clean) &&
          f.statusText.contains('Mutual')) {
        return true;
      }
    }

    return isFollowingUser(userName) && isFollowedByUser(userName);
  }

  int getRoomFollowers(String roomCode) {
    return _roomFollowerCounts[roomCode] ?? 0;
  }

  int getUserFollowers(String userName) {
    return _userFollowerCounts[userName] ?? 0;
  }

  int getUserFollowing(String userName) {
    return _userFollowingCounts[userName] ?? 0;
  }

  int getUserVisitors(String userName) {
    return _userVisitorCounts[userName] ?? 0;
  }

  void toggleFollowRoom(String roomCode) {
    final current = _roomFollowerCounts[roomCode] ?? 0;
    if (_followedRoomCodes.contains(roomCode)) {
      _followedRoomCodes.remove(roomCode);
      _roomFollowerCounts[roomCode] = max(0, current - 1);
    } else {
      _followedRoomCodes.add(roomCode);
      _roomFollowerCounts[roomCode] = current + 1;
    }
    notifyListeners();
  }

  Future<void> toggleFollowUser(
    String userName, {
    String? tag,
    String? profilePhoto,
    Color? avatarColor,
    int? level,
  }) async {
    final current = _userFollowerCounts[userName] ?? 0;
    final isNowFollowing = !_followedUsers.contains(userName);

    if (!isNowFollowing) {
      _followedUsers.remove(userName);
      _userFollowerCounts[userName] = max(0, current - 1);
      AuthService().removeFriend(userName);

      final currentUser = AuthService().currentUser;
      if (currentUser != null) {
        final res = await AwsStorageService.followUser(
          followerId: currentUser.email,
          followerName: currentUser.name,
          targetIdOrTag: tag ?? userName,
          follow: false,
        );
        if (res['followersCount'] is int) {
          _userFollowerCounts[userName] = res['followersCount'] as int;
        }
        if (res['followingCount'] is int) {
          _userFollowingCounts[currentUser.name] = res['followingCount'] as int;
        }
      }
    } else {
      _followedUsers.add(userName);
      _userFollowerCounts[userName] = current + 1;

      final cleanTag = (tag != null && tag.isNotEmpty)
          ? (tag.startsWith('@') ? tag : '@$tag')
          : '@${userName.toLowerCase().replaceAll(' ', '_')}';

      AuthService().addFriend(
        name: userName,
        tag: cleanTag,
        avatarColor: avatarColor,
        level: level ?? 1,
      );

      final currentUser = AuthService().currentUser;
      if (currentUser != null) {
        final res = await AwsStorageService.followUser(
          followerId: currentUser.email,
          followerName: currentUser.name,
          targetIdOrTag: cleanTag,
          follow: true,
        );
        if (res['followersCount'] is int) {
          _userFollowerCounts[userName] = res['followersCount'] as int;
        }
        if (res['followingCount'] is int) {
          _userFollowingCounts[currentUser.name] = res['followingCount'] as int;
        }
      }
    }

    LocalStorageService.saveFollowedUsers(_followedUsers);
    notifyListeners();
  }

  /// Syncs followers and following lists directly from AWS DynamoDB and updates AuthService friends
  Future<void> syncFollowsFromServer() async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return;

    try {
      final followers = await AwsStorageService.getFollowers(currentUser.id);
      _userFollowers.clear();
      for (final f in followers) {
        final fName = f['name']?.toString() ?? '';
        final fId = f['id']?.toString() ?? '';
        final fTag = f['tag']?.toString() ?? '';
        if (fName.isNotEmpty) {
          _userFollowers.add(fName);
          _userFollowers.add(fName.toLowerCase());
        }
        if (fId.isNotEmpty) {
          _userFollowers.add(fId);
          _userFollowers.add(fId.toLowerCase());
        }
        if (fTag.isNotEmpty) {
          _userFollowers.add(fTag);
          _userFollowers.add(fTag.toLowerCase().replaceAll('@', ''));
        }
      }
      _userFollowerCounts[currentUser.name] = followers.length;

      final following = await AwsStorageService.getFollowing(currentUser.id);
      _followedUsers.clear();
      for (final g in following) {
        final gName = g['name']?.toString() ?? '';
        final gId = g['id']?.toString() ?? '';
        final gTag = g['tag']?.toString() ?? '';
        if (gName.isNotEmpty) {
          _followedUsers.add(gName);
          _followedUsers.add(gName.toLowerCase());
        }
        if (gId.isNotEmpty) {
          _followedUsers.add(gId);
          _followedUsers.add(gId.toLowerCase());
        }
        if (gTag.isNotEmpty) {
          _followedUsers.add(gTag);
          _followedUsers.add(gTag.toLowerCase().replaceAll('@', ''));
        }
      }
      _userFollowingCounts[currentUser.name] = following.length;

      // Populate AuthService().friends with real relationships & mutual badges
      final auth = AuthService();
      for (final g in following) {
        final gName = g['name']?.toString() ?? '';
        final gId = g['id']?.toString() ?? '';
        final gTag = g['tag']?.toString() ?? '@gamer';
        if (gName.isEmpty) continue;

        final isMutual = followers.any((f) {
          final fName = (f['name'] ?? '').toString().toLowerCase();
          final fId = (f['id'] ?? '').toString().toLowerCase();
          return fName == gName.toLowerCase() || (gId.isNotEmpty && fId == gId.toLowerCase());
        });

        auth.addFriend(
          name: gName,
          tag: gTag,
          level: g['level'] is int ? g['level'] as int : 1,
          statusText: isMutual ? 'Mutual Friends 👥' : 'Following',
        );
      }

      for (final f in followers) {
        final fName = f['name']?.toString() ?? '';
        final fId = f['id']?.toString() ?? '';
        final fTag = f['tag']?.toString() ?? '@gamer';
        if (fName.isEmpty) continue;

        final isMutual = following.any((g) {
          final gName = (g['name'] ?? '').toString().toLowerCase();
          final gId = (g['id'] ?? '').toString().toLowerCase();
          return gName == fName.toLowerCase() || (fId.isNotEmpty && gId == fId.toLowerCase());
        });

        auth.addFriend(
          name: fName,
          tag: fTag,
          level: f['level'] is int ? f['level'] as int : 1,
          statusText: isMutual ? 'Mutual Friends 👥' : 'Follows You',
        );
      }

      LocalStorageService.saveFollowedUsers(_followedUsers);
      LocalStorageService.saveUserFollowers(_userFollowers);
      notifyListeners();
    } catch (e) {
      debugPrint('VoiceRoomManager syncFollowsFromServer error: $e');
    }
  }

  void setUserFollowsMe(String userName, bool follows) {
    if (follows) {
      _userFollowers.add(userName);
    } else {
      _userFollowers.remove(userName);
    }
    LocalStorageService.saveUserFollowers(_userFollowers);
    notifyListeners();
  }

  /// Take a mic seat in the active room (Seat 0 to 7)
  Future<void> takeSeat(int seatIndex, UserModel user) async {
    if (_activeRoom == null) return;
    try {
      final updatedSeats = await AwsStorageService.takeSeat(
        roomId: _activeRoom!.id,
        seatIndex: seatIndex,
        user: user,
      );
      if (updatedSeats.isNotEmpty) {
        _micSeats = updatedSeats;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('VoiceRoomManager takeSeat error: $e');
    }
  }

  /// Leave a mic seat in the active room
  Future<void> leaveSeat(int seatIndex, String userId) async {
    if (_activeRoom == null) return;
    try {
      final updatedSeats = await AwsStorageService.leaveSeat(
        roomId: _activeRoom!.id,
        seatIndex: seatIndex,
        userId: userId,
      );
      if (updatedSeats.isNotEmpty) {
        _micSeats = updatedSeats;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('VoiceRoomManager leaveSeat error: $e');
    }
  }

  /// Broadcast room music state to all room occupants
  Future<void> broadcastRoomMusic(Map<String, dynamic> song) async {
    if (_activeRoom == null) return;
    _syncedRoomSong = song;
    notifyListeners();
    try {
      await AwsStorageService.syncRoomMusic(
        roomId: _activeRoom!.id,
        song: song,
      );
    } catch (e) {
      debugPrint('VoiceRoomManager broadcastRoomMusic error: $e');
    }
  }

  /// Sets the currently active room, registers with server, and begins live member & seat sync
  void joinRoom(RoomModel room) {
    _activeRoom = room;
    _activeRoomWasDeleted = false;
    _roomAdmins.clear();
    // Default: Host is always admin
    _roomAdmins.add(room.hostName);

    // Initial member list with host
    _activeRoomMembers = [
      {
        'userId': room.id,
        'name': room.hostName,
        'role': 'host',
        'joinedAt': DateTime.now().toIso8601String(),
      }
    ];

    // Silent by default when creating or joining a room; starts only when player presses play!
    InAppMusicService().pauseMusic();
    notifyListeners();

    final currentUser = AuthService().currentUser;
    if (currentUser != null) {
      AwsStorageService.joinRoom(roomId: room.id, user: currentUser).then((res) {
        if (res.room != null) {
          _activeRoom = res.room!;
        }
        if (res.members.isNotEmpty) {
          _activeRoomMembers = res.members;
          if (_activeRoom != null) {
            _activeRoom = _activeRoom!.copyWith(currentPlayers: res.currentPlayers);
          }
        }
        if (res.seats.isNotEmpty) {
          _micSeats = res.seats;
        }
        if (res.currentSong != null) {
          _syncedRoomSong = res.currentSong;
        }
        notifyListeners();
      });
    }

    if (!AwsStorageService.mockMode) {
      _roomSyncTimer?.cancel();
      _roomSyncTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) async {
        if (_activeRoom == null) {
          _roomSyncTimer?.cancel();
          return;
        }
        try {
          final state = await AwsStorageService.getRoomState(_activeRoom!.id);
          if (state.roomDeleted) {
            _activeRoomWasDeleted = true;
            _roomSyncTimer?.cancel();
            _roomSyncTimer = null;
            _activeRoom = null;
            _activeRoomMembers.clear();
            _micSeats.clear();
            _syncedRoomSong = null;
            InAppMusicService().pauseMusic();
            notifyListeners();
            return;
          }

          // Check if current user was kicked/removed from room by host
          final currentUser = AuthService().currentUser;
          final myId = (currentUser?.id ?? '').toLowerCase();
          final myName = (currentUser?.name ?? '').toLowerCase();
          final isKicked = state.kickedUsers.any((k) {
            final kLower = k.toLowerCase().trim();
            return kLower == myId || kLower == myName;
          });

          if (isKicked) {
            _kickedFromRoom = true;
            _roomSyncTimer?.cancel();
            _roomSyncTimer = null;
            _activeRoom = null;
            _activeRoomMembers.clear();
            _micSeats.clear();
            _syncedRoomSong = null;
            InAppMusicService().pauseMusic();
            notifyListeners();
            return;
          }

          if (state.success) {
            bool changed = false;
            if (state.room != null && (state.room!.gameTitle != _activeRoom!.gameTitle || state.room!.hostName != _activeRoom!.hostName)) {
              _activeRoom = state.room!;
              changed = true;
            }
            if (state.members.isNotEmpty) {
              _activeRoomMembers = state.members;
              _activeRoom = _activeRoom?.copyWith(currentPlayers: state.currentPlayers);
              changed = true;
            }
            if (state.seats.isNotEmpty) {
              _micSeats = state.seats;
              changed = true;
            }
            if (state.chatMessages.isNotEmpty) {
              _activeRoomMessages = state.chatMessages;
              changed = true;
            }
            if (state.currentSong != null) {
              _syncedRoomSong = state.currentSong;
              // Sync audio for listeners
              final user = AuthService().currentUser;
              final isHost = _activeRoom != null && _activeRoom!.hostName == user?.name;
              if (!isHost) {
                final isPlaying = _syncedRoomSong!['isPlaying'] == true;
                final trackIdx = _syncedRoomSong!['trackIndex'] is int ? _syncedRoomSong!['trackIndex'] as int : 0;
                final music = InAppMusicService();
                if (isPlaying && (!music.isPlaying || music.currentTrackIndex != trackIdx)) {
                  music.playMusic(trackIdx);
                } else if (!isPlaying && music.isPlaying) {
                  music.pauseMusic();
                }
              }
              changed = true;
            }
            if (changed) notifyListeners();
          }
        } catch (_) {}
      });
    }
  }

  /// Leaves the current room, unregisters from server, and cancels live member sync
  void leaveRoom() {
    _roomSyncTimer?.cancel();
    _roomSyncTimer = null;

    final leavingRoom = _activeRoom;
    final currentUser = AuthService().currentUser;
    if (leavingRoom != null && currentUser != null) {
      AwsStorageService.leaveRoom(roomId: leavingRoom.id, userId: currentUser.id);
    }

    _activeRoom = null;
    _activeRoomMembers.clear();
    _micSeats.clear();
    _syncedRoomSong = null;
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
