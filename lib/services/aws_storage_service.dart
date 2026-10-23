import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/aws_config.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../utils/security_helper.dart';
import 'local_storage_service.dart';

class AwsCheckResult {
  final bool exists;
  final String? existingField; // 'email' or 'mobile'
  final String? message;
  final bool hasNetworkError;

  const AwsCheckResult({
    required this.exists,
    this.existingField,
    this.message,
    this.hasNetworkError = false,
  });
}

/// Service to interface with AWS Cloud Storage (Amazon DynamoDB & API Gateway)
/// for persisting user accounts and enforcing uniqueness on Email and Mobile Number.
class AwsStorageService {
  // In-memory cache of registered users (persists during app runtime)
  static final List<Map<String, dynamic>> _cloudUserCache = [];

  static List<Map<String, dynamic>> get cloudUserCache =>
      List.unmodifiable(_cloudUserCache);

  static final Map<String, Set<String>> _followersMap = {};
  static final Map<String, Set<String>> _followingMap = {};
  static final Map<String, List<Map<String, dynamic>>> _roomMembersMap = {};
  static final List<RoomModel> _cloudRooms = [];
  static final List<Map<String, dynamic>> _directMessages = [];
  static final Map<String, List<Map<String, dynamic>>> _mockSignalsMap = {};

  static void resetForTesting() {
    _cloudUserCache.clear();
    _followersMap.clear();
    _followingMap.clear();
    _roomMembersMap.clear();
    _cloudRooms.clear();
    _directMessages.clear();
    _mockSignalsMap.clear();
  }

  /// Flag for unit tests and offline testing mode
  static bool mockMode = false;

  /// HTTP client for network operations (can be overridden for testing)
  static http.Client httpClient = http.Client();

  /// Search users across AWS Cloud Storage (DynamoDB) and local cloud cache
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final cleanQ = query.trim().toLowerCase();
    if (cleanQ.isEmpty) return [];

    final results = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    // 1. Check local cloud user cache
    for (final u in _cloudUserCache) {
      final id = (u['id'] ?? u['userId'] ?? '').toString();
      final tag = (u['tag'] ?? u['gamerTag'] ?? '')
          .toString()
          .toLowerCase()
          .replaceAll('@', '');
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();

      final cleanRaw = cleanQ.replaceAll('@', '');
      if (id.toLowerCase().contains(cleanRaw) ||
          tag.contains(cleanRaw) ||
          name.contains(cleanRaw) ||
          email.contains(cleanRaw)) {
        if (!seenIds.contains(id)) {
          seenIds.add(id);
          results.add({
            'id': id,
            'securityId': id,
            'name': u['name'] ?? 'Player',
            'gamerTag': u['tag'] ?? u['gamerTag'] ?? '@gamer',
            'email': u['email'],
            'level': u['level'] ?? 1,
            'coins': u['coins'] ?? 500,
            'totalWins': u['trophies'] ?? 0,
            'profilePhoto': u['profilePhoto'],
            'followersCount': 0,
            'followingCount': 0,
            'visitorsCount': 0,
          });
        }
      }
    }

    // 2. Query AWS API Gateway if configured
    if (AwsConfig.isConfigured && !mockMode) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final response = await httpClient
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                if (AwsConfig.apiKey.isNotEmpty)
                  'x-api-key': AwsConfig.apiKey.trim(),
              },
              body: jsonEncode({
                'action': 'searchUsers',
                'query': query.trim(),
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List) {
            for (final item in data) {
              if (item is Map) {
                final id = (item['id'] ?? item['userId'] ?? '').toString();
                if (!seenIds.contains(id)) {
                  seenIds.add(id);
                  results.add({
                    'id': id,
                    'securityId': id,
                    'name': item['name'] ?? 'Player',
                    'gamerTag': item['tag'] ?? item['gamerTag'] ?? '@player',
                    'email': item['email'],
                    'level': item['level'] ?? 1,
                    'coins': item['coins'] ?? 500,
                    'totalWins': item['totalWins'] ?? item['trophies'] ?? 0,
                    'profilePhoto': item['profilePhoto'],
                    'followersCount': item['followersCount'] ?? 0,
                    'followingCount': item['followingCount'] ?? 0,
                    'visitorsCount': item['visitorsCount'] ?? 0,
                  });
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService searchUsers network error: $e');
      }
    }

    return results;
  }

  /// Check if an email or mobile number is already registered in AWS or local registry
  static Future<AwsCheckResult> checkUserExists({
    required String email,
    required String phoneNumber,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // 1. Check local cache first
    for (final u in _cloudUserCache) {
      final uEmail = (u['email'] ?? '').toString().trim().toLowerCase();
      final uPhone =
          (u['phoneNumber'] ?? '').toString().replaceAll(RegExp(r'\D'), '');

      if (cleanEmail.isNotEmpty && uEmail.isNotEmpty && uEmail == cleanEmail) {
        return const AwsCheckResult(
          exists: true,
          existingField: 'email',
          message:
              'This email is already used / registered. Please sign in or use another email.',
        );
      }

      if (cleanPhone.isNotEmpty && uPhone.isNotEmpty) {
        if (uPhone == cleanPhone ||
            (uPhone.length >= 7 && cleanPhone.length >= 7 &&
             (uPhone.endsWith(cleanPhone) || cleanPhone.endsWith(uPhone)))) {
          return const AwsCheckResult(
            exists: true,
            existingField: 'mobile',
            message:
                'This mobile number is already used / registered. Please sign in or use another mobile number.',
          );
        }
      }
    }

    // 2. If AWS API Gateway is configured, query the AWS cloud endpoint
    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await http
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'checkUser',
                'email': cleanEmail,
                'phoneNumber': cleanPhone,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 || response.statusCode == 409) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            final exists = data['exists'] == true;
            final field = data['field']?.toString();
            if (exists) {
              if (field == 'email') {
                return const AwsCheckResult(
                  exists: true,
                  existingField: 'email',
                  message:
                      'This email is already used / registered in AWS. Please sign in or use another email.',
                );
              } else if (field == 'mobile' || field == 'phone') {
                return const AwsCheckResult(
                  exists: true,
                  existingField: 'mobile',
                  message:
                      'This mobile number is already used / registered in AWS. Please sign in or use another mobile number.',
                );
              } else {
                return AwsCheckResult(
                  exists: true,
                  message: data['message']?.toString() ??
                      'This account is already registered in AWS.',
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('AWS checkUserExists network error: $e');
        // Do not silently treat network failure as proof that account identifier is available
        return const AwsCheckResult(
          exists: false,
          hasNetworkError: true,
          message:
              'Unable to verify email/phone uniqueness with the server. Please check your internet connection.',
        );
      }
    }

    return const AwsCheckResult(exists: false);
  }

  /// Store a registered user account in AWS DynamoDB & local cache
  static Future<bool> storeUser(UserModel user, {String? password}) async {
    final cleanEmail = user.email.trim().toLowerCase();
    final cleanPhone = (user.phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');

    // Cache locally
    _cloudUserCache.add({
      'id': user.id,
      'email': cleanEmail,
      'phoneNumber': cleanPhone,
      'name': user.name,
      'tag': user.tag,
      'countryCode': user.countryCode,
      'countryFlag': user.countryFlag,
      if (password != null && password.isNotEmpty) 'password': password,
      'registeredAt': DateTime.now().toIso8601String(),
    });

    if (mockMode) return true;

    // If AWS API Gateway is configured, upload to AWS DynamoDB
    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final payload = {
          'action': 'register',
          'userId': user.id,
          'id': user.id,
          'Id': user.id,
          'ID': user.id,
          'email': cleanEmail,
          'Email': cleanEmail,
          'phoneNumber': cleanPhone,
          'Phone': cleanPhone,
          'countryCode': user.countryCode,
          'countryFlag': user.countryFlag,
          'name': user.name,
          'tag': user.tag,
          if (password != null && password.isNotEmpty) ...{
            'password': password,
            'passwordHash': SecurityHelper.hashPassword(password),
          },
          'level': user.level,
          'coins': user.coins,
          'trophies': user.trophies,
          'tableName': AwsConfig.tableName,
          'registeredAt': DateTime.now().toIso8601String(),
        };

        final response = await httpClient
            .post(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 8));

        return response.statusCode == 200 || response.statusCode == 201;
      } catch (e) {
        debugPrint('AWS storeUser error: $e');
        return false;
      }
    }

    return true;
  }

  /// Login user via AWS Cloud Storage (DynamoDB & API Gateway)
  /// Authenticates using Email, Mobile Number, Gamer Tag (@tag), or Security ID (01xxxxxx)
  static Future<
      ({
        bool success,
        UserModel? user,
        String? sessionToken,
        String? error,
      })> loginUser({
    required String identifier,
    required String password,
  }) async {
    final cleanId = identifier.trim();
    if (cleanId.isEmpty || password.isEmpty) {
      return (
        success: false,
        user: null,
        sessionToken: null,
        error: 'Please enter your email, mobile number, or gamer tag.',
      );
    }

    // 1. Mock / offline cache fallback
    if (mockMode) {
      final cleanLower = cleanId.toLowerCase();
      final cleanDigits = cleanId.replaceAll(RegExp(r'\D'), '');
      final cleanTag = cleanLower.replaceAll('@', '');

      for (final u in _cloudUserCache) {
        final uEmail = (u['email'] ?? '').toString().toLowerCase();
        final uPhone =
            (u['phoneNumber'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final uTag = (u['tag'] ?? u['gamerTag'] ?? '')
            .toString()
            .toLowerCase()
            .replaceAll('@', '');
        final uId = (u['id'] ?? u['userId'] ?? '').toString().toLowerCase();

        if (uEmail == cleanLower ||
            (cleanDigits.isNotEmpty && uPhone == cleanDigits) ||
            uTag == cleanTag ||
            uId == cleanLower) {
          final storedPass = u['password']?.toString() ?? '';
          if (storedPass.isNotEmpty &&
              !SecurityHelper.verifyPassword(password, storedPass)) {
            return (
              success: false,
              user: null,
              sessionToken: null,
              error: 'Incorrect password. Please try again.',
            );
          }
          final name = (u['name'] ?? 'Player').toString();
          final user = UserModel(
            id: (u['id'] ?? u['userId'] ?? '01000000').toString(),
            name: name,
            tag: u['tag'] ?? u['gamerTag'] ?? '@gamer',
            email: u['email'] ?? '',
            avatarColor: const Color(0xFF7C3AED),
            avatarInitial: name.isNotEmpty ? name[0].toUpperCase() : 'P',
            phoneNumber: u['phoneNumber'],
            countryCode: u['countryCode'] ?? '+91',
            countryFlag: u['countryFlag'] ?? '🇮🇳',
            level: u['level'] ?? 1,
            coins: u['coins'] ?? 500,
            trophies: u['trophies'] ?? 0,
            profilePhoto: u['profilePhoto'],
          );
          return (
            success: true,
            user: user,
            sessionToken: 'mock_sess_${user.id}',
            error: null,
          );
        }
      }
      return (
        success: false,
        user: null,
        sessionToken: null,
        error: 'Account not found. Please check your credentials or register.',
      );
    }

    // 2. Query AWS API Gateway
    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'login',
                'identifier': cleanId,
                'password': password,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 8));

        final data = jsonDecode(response.body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (data is Map && data['success'] == true && data['user'] is Map) {
            final userMap = Map<String, dynamic>.from(data['user'] as Map);
            final sessionToken = data['sessionToken']?.toString() ??
                'pf_sess_${userMap['id'] ?? userMap['userId']}';
            final user = UserModel.fromMap(userMap);
            return (
              success: true,
              user: user,
              sessionToken: sessionToken,
              error: null,
            );
          }
        }

        final errorMsg = (data is Map ? data['error']?.toString() : null) ??
            (response.statusCode == 401
                ? 'Incorrect password. Please try again.'
                : 'Account not found. Please check your credentials or register.');

        return (
          success: false,
          user: null,
          sessionToken: null,
          error: errorMsg,
        );
      } catch (e) {
        debugPrint('AWS login network error: $e');
        return (
          success: false,
          user: null,
          sessionToken: null,
          error:
              'Unable to reach server. Please check your internet connection.',
        );
      }
    }

    return (
      success: false,
      user: null,
      sessionToken: null,
      error: 'AWS server is not configured.',
    );
  }

  /// Reset user password in AWS Cloud Storage (DynamoDB & API Gateway)
  static Future<({bool success, String? error})> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || newPassword.isEmpty) {
      return (success: false, error: 'Email and new password are required.');
    }

    // Update in local cloud user cache
    for (final u in _cloudUserCache) {
      if ((u['email'] ?? '').toString().toLowerCase() == cleanEmail) {
        u['password'] = newPassword;
        break;
      }
    }

    if (mockMode) return (success: true, error: null);

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'resetPassword',
                'email': cleanEmail,
                'newPassword': newPassword,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 8));

        final data = jsonDecode(response.body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return (success: true, error: null);
        } else {
          return (
            success: false,
            error: (data is Map ? data['error']?.toString() : null) ??
                'Password reset failed on server.',
          );
        }
      } catch (e) {
        debugPrint('AWS resetPassword network error: $e');
        return (
          success: false,
          error: 'Unable to reach AWS server. Please try again.',
        );
      }
    }

    return (success: true, error: null);
  }

  // Persistent in-memory map of uploaded songs per userId (persists across sessions)
  static final Map<String, List<Map<String, dynamic>>> _userUploadedSongsCache =
      {};

  /// Update user profile photo on AWS server and local cloud registry
  static Future<bool> updateUserProfilePhoto({
    required String userId,
    required String email,
    required String? profilePhoto,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Update in local cloud user cache
    for (final u in _cloudUserCache) {
      if (u['id'] == userId ||
          (u['email'] ?? '').toString().toLowerCase() == cleanEmail) {
        u['profilePhoto'] = profilePhoto;
        break;
      }
    }

    if (mockMode) return true;

    // 2. Sync to AWS DynamoDB / API Gateway if configured
    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final payload = {
          'action': profilePhoto == null || profilePhoto.isEmpty
              ? 'deleteProfilePhoto'
              : 'updateProfilePhoto',
          'userId': userId,
          'email': cleanEmail,
          'profilePhoto': profilePhoto,
          'tableName': AwsConfig.tableName,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        final response = await httpClient
            .post(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 5));

        return response.statusCode == 200 || response.statusCode == 201;
      } catch (e) {
        debugPrint(
            'AWS updateUserProfilePhoto network error (saved to local cache): $e');
        return false;
      }
    }

    return true;
  }

  /// Delete user profile photo from AWS server and local cache
  static Future<bool> deleteUserProfilePhoto({
    required String userId,
    required String email,
  }) async {
    return updateUserProfilePhoto(
        userId: userId, email: email, profilePhoto: null);
  }

  /// Save an uploaded song to AWS server and persistent user song registry
  static Future<bool> uploadSongToServer({
    required String userId,
    required int songId,
    required String title,
    required String genre,
    required String bpm,
    required String audioPathOrUrl,
    String? fileName,
  }) async {
    final songData = {
      'id': songId,
      'userId': userId,
      'title': title,
      'genre': genre,
      'bpm': bpm,
      'audioPathOrUrl': audioPathOrUrl,
      'fileName': fileName ?? title,
      'isUserUploaded': true,
      'uploadedAt': DateTime.now().toIso8601String(),
    };

    _userUploadedSongsCache.putIfAbsent(userId, () => []);
    _userUploadedSongsCache[userId]!.removeWhere((s) => s['title'] == title);
    _userUploadedSongsCache[userId]!.add(songData);

    // Persist to local disk so songs survive app restarts
    LocalStorageService.saveUserSongs(userId, _userUploadedSongsCache[userId]!);

    if (mockMode) return true;

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final payload = {
          'action': 'uploadSong',
          'userId': userId,
          'song': songData,
          'tableName': AwsConfig.tableName,
        };

        final response = await httpClient
            .post(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 5));
        return response.statusCode == 200 || response.statusCode == 201;
      } catch (e) {
        debugPrint('AWS uploadSongToServer error: $e');
        return false;
      }
    }

    return true;
  }

  /// Delete an uploaded song from AWS server and local storage
  static Future<bool> deleteSongFromServer({
    required String userId,
    required int songId,
  }) async {
    if (_userUploadedSongsCache.containsKey(userId)) {
      _userUploadedSongsCache[userId]!.removeWhere((s) => s['id'] == songId);
      LocalStorageService.saveUserSongs(
          userId, _userUploadedSongsCache[userId]!);
    }

    if (mockMode) return true;

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final payload = {
          'action': 'deleteSong',
          'userId': userId,
          'songId': songId,
          'tableName': AwsConfig.tableName,
        };

        final response = await httpClient
            .post(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 5));
        return response.statusCode == 200 || response.statusCode == 204;
      } catch (e) {
        debugPrint('AWS deleteSongFromServer error: $e');
        return false;
      }
    }

    return true;
  }

  /// Fetch all songs uploaded by this user from AWS server or cache
  static Future<List<Map<String, dynamic>>> getUserSongsFromServer(
      String userId) async {
    var localSongs = _userUploadedSongsCache[userId] ?? [];
    if (localSongs.isEmpty) {
      final diskSongs = await LocalStorageService.loadUserSongs(userId);
      if (diskSongs.isNotEmpty) {
        _userUploadedSongsCache[userId] = diskSongs;
        localSongs = diskSongs;
      }
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await http
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'getUserSongs',
                'userId': userId,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['songs'] is List) {
            final cloudSongs =
                (data['songs'] as List).cast<Map<String, dynamic>>();
            _userUploadedSongsCache[userId] = cloudSongs;
            return cloudSongs;
          }
        }
      } catch (e) {
        debugPrint('AWS getUserSongsFromServer error: $e');
      }
    }

    return List<Map<String, dynamic>>.from(localSongs);
  }

  /// Follow or unfollow a user on AWS server and local graph
  static Future<Map<String, dynamic>> followUser({
    required String followerId,
    required String followerName,
    required String targetIdOrTag,
    bool follow = true,
  }) async {
    final cleanFollower = followerId.trim().toLowerCase();
    final cleanTarget = targetIdOrTag.trim().toLowerCase().replaceAll('@', '');

    if (mockMode) {
      final fSet = _followersMap.putIfAbsent(cleanTarget, () => {});
      final gSet = _followingMap.putIfAbsent(cleanFollower, () => {});
      if (follow) {
        fSet.add(cleanFollower);
        gSet.add(cleanTarget);
      } else {
        fSet.remove(cleanFollower);
        gSet.remove(cleanTarget);
      }
      return {
        'success': true,
        'isFollowing': follow,
        'targetName': targetIdOrTag,
        'followersCount': fSet.length,
        'followingCount': gSet.length,
      };
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'followUser',
                'followerId': cleanFollower,
                'followerName': followerName,
                'targetId': cleanTarget,
                'targetGamerTagOrId': cleanTarget,
                'follow': follow,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            return Map<String, dynamic>.from(data);
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService followUser error: $e');
      }
    }

    // Local fallback update
    final fSet = _followersMap.putIfAbsent(cleanTarget, () => {});
    final gSet = _followingMap.putIfAbsent(cleanFollower, () => {});
    if (follow) {
      fSet.add(cleanFollower);
      gSet.add(cleanTarget);
    } else {
      fSet.remove(cleanFollower);
      gSet.remove(cleanTarget);
    }
    return {
      'success': true,
      'isFollowing': follow,
      'targetName': targetIdOrTag,
      'followersCount': fSet.length,
      'followingCount': gSet.length,
    };
  }

  /// Get followers list for a user
  static Future<List<Map<String, dynamic>>> getFollowers(String userIdOrEmail) async {
    final cleanId = userIdOrEmail.trim().toLowerCase().replaceAll('@', '');

    if (mockMode) {
      final keys = _followersMap[cleanId] ?? {};
      final list = <Map<String, dynamic>>[];
      for (final k in keys) {
        final u = _cloudUserCache.firstWhere(
          (user) =>
              (user['id'] ?? user['userId'] ?? '').toString().toLowerCase() == k ||
              (user['email'] ?? '').toString().toLowerCase() == k ||
              (user['tag'] ?? user['gamerTag'] ?? '').toString().toLowerCase().replaceAll('@', '') == k,
          orElse: () => {
            'id': k,
            'name': 'Player',
            'tag': '@player',
          },
        );
        list.add({
          'id': u['id'] ?? u['userId'] ?? k,
          'name': u['name'] ?? 'Player',
          'tag': u['tag'] ?? u['gamerTag'] ?? '@player',
          'profilePhoto': u['profilePhoto'],
          'level': u['level'] ?? 1,
        });
      }
      return list;
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'getFollowers',
                'userId': cleanId,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['list'] is List) {
            return (data['list'] as List).cast<Map<String, dynamic>>();
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService getFollowers error: $e');
      }
    }

    return [];
  }

  /// Get following list for a user
  static Future<List<Map<String, dynamic>>> getFollowing(String userIdOrEmail) async {
    final cleanId = userIdOrEmail.trim().toLowerCase().replaceAll('@', '');

    if (mockMode) {
      final keys = _followingMap[cleanId] ?? {};
      final list = <Map<String, dynamic>>[];
      for (final k in keys) {
        final u = _cloudUserCache.firstWhere(
          (user) =>
              (user['id'] ?? user['userId'] ?? '').toString().toLowerCase() == k ||
              (user['email'] ?? '').toString().toLowerCase() == k ||
              (user['tag'] ?? user['gamerTag'] ?? '').toString().toLowerCase().replaceAll('@', '') == k,
          orElse: () => {
            'id': k,
            'name': 'Player',
            'tag': '@player',
          },
        );
        list.add({
          'id': u['id'] ?? u['userId'] ?? k,
          'name': u['name'] ?? 'Player',
          'tag': u['tag'] ?? u['gamerTag'] ?? '@player',
          'profilePhoto': u['profilePhoto'],
          'level': u['level'] ?? 1,
        });
      }
      return list;
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'getFollowing',
                'userId': cleanId,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['list'] is List) {
            return (data['list'] as List).cast<Map<String, dynamic>>();
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService getFollowing error: $e');
      }
    }

    return [];
  }

  /// Get follow and mutual relationship status between two users
  static Future<Map<String, dynamic>> getFollowStatus({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final cId = currentUserId.trim().toLowerCase();
    final tId = targetUserId.trim().toLowerCase().replaceAll('@', '');

    if (mockMode) {
      final isFollowing = _followingMap[cId]?.contains(tId) == true;
      final isFollowedBy = _followersMap[cId]?.contains(tId) == true;
      return {
        'success': true,
        'isFollowing': isFollowing,
        'isFollowedBy': isFollowedBy,
        'isMutual': isFollowing && isFollowedBy,
      };
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'getFollowStatus',
                'currentUserId': cId,
                'targetUserId': tId,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            return Map<String, dynamic>.from(data);
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService getFollowStatus error: $e');
      }
    }

    final isFollowing = _followingMap[cId]?.contains(tId) == true;
    final isFollowedBy = _followersMap[cId]?.contains(tId) == true;
    return {
      'success': true,
      'isFollowing': isFollowing,
      'isFollowedBy': isFollowedBy,
      'isMutual': isFollowing && isFollowedBy,
    };
  }

  /// Fetch active live rooms from AWS server
  static Future<List<RoomModel>> getRooms() async {
    if (mockMode) {
      return _cloudRooms.where((r) => !RoomModel.isDemoRoom(r)).toList();
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'getRooms',
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List) {
            final rooms = <RoomModel>[];
            for (final item in data) {
              if (item is Map) {
                final r = RoomModel.fromMap(Map<String, dynamic>.from(item));
                if (!RoomModel.isDemoRoom(r)) {
                  rooms.add(r);
                }
              }
            }
            return rooms;
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService getRooms error: $e');
      }
    }

    final local = await LocalStorageService.loadActiveRooms();
    return local.where((r) => !RoomModel.isDemoRoom(r)).toList();
  }

  /// Create and persist a room on AWS server
  static Future<bool> createRoom(RoomModel room) async {
    if (RoomModel.isDemoRoom(room)) return false;

    _cloudRooms.removeWhere((r) => r.id == room.id || r.roomCode == room.roomCode);
    _cloudRooms.insert(0, room);
    _roomMembersMap[room.id] = [
      {
        'userId': room.id,
        'name': room.hostName,
        'role': 'host',
        'joinedAt': DateTime.now().toIso8601String(),
      }
    ];

    if (mockMode) return true;

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'createRoom',
                'room': room.toMap(),
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        return response.statusCode == 200 || response.statusCode == 201;
      } catch (e) {
        debugPrint('AwsStorageService createRoom error: $e');
        return false;
      }
    }

    return true;
  }

  /// Delete a room from AWS server
  static Future<bool> deleteRoom(String roomId) async {
    _cloudRooms.removeWhere((r) => r.id == roomId || r.roomCode == roomId);
    _roomMembersMap.remove(roomId);

    if (mockMode) return true;

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'deleteRoom',
                'roomId': roomId,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        return response.statusCode == 200 || response.statusCode == 204;
      } catch (e) {
        debugPrint('AwsStorageService deleteRoom error: $e');
        return false;
      }
    }

    return true;
  }

  /// Get comprehensive room state (members, seats, music, deletion status, chat messages, kicked users)
  static Future<({
    bool success,
    bool roomDeleted,
    RoomModel? room,
    List<Map<String, dynamic>> members,
    List<dynamic> seats,
    Map<String, dynamic>? currentSong,
    int currentPlayers,
    List<Map<String, dynamic>> chatMessages,
    List<String> kickedUsers,
  })> getRoomState(String roomIdOrCode) async {
    if (mockMode) {
      final r = _cloudRooms.firstWhere(
        (room) => room.id == roomIdOrCode || room.roomCode.toLowerCase() == roomIdOrCode.toLowerCase(),
        orElse: () => RoomModel(
          id: roomIdOrCode,
          roomCode: roomIdOrCode,
          gameTitle: 'Voice Party Room',
          hostName: 'Host',
          currentPlayers: 1,
          maxPlayers: 100,
          isPrivate: false,
          status: 'Active',
        ),
      );
      final m = _roomMembersMap[r.id] ?? [];
      return (
        success: true,
        roomDeleted: false,
        room: r,
        members: List<Map<String, dynamic>>.from(m),
        seats: [],
        currentSong: null,
        currentPlayers: m.length,
        chatMessages: <Map<String, dynamic>>[],
        kickedUsers: <String>[],
      );
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'getRoomState',
                'roomId': roomIdOrCode,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            RoomModel? parsedRoom;
            if (data['room'] is Map) {
              parsedRoom = RoomModel.fromMap(Map<String, dynamic>.from(data['room']));
            }
            final membersList = data['members'] is List
                ? (data['members'] as List).cast<Map<String, dynamic>>()
                : <Map<String, dynamic>>[];
            final seatsList = data['seats'] is List ? (data['seats'] as List) : <dynamic>[];
            final currentSong = data['currentSong'] is Map
                ? Map<String, dynamic>.from(data['currentSong'])
                : null;
            final count = data['currentPlayers'] is int ? data['currentPlayers'] as int : membersList.length;
            final chatList = data['chatMessages'] is List
                ? (data['chatMessages'] as List).cast<Map<String, dynamic>>()
                : <Map<String, dynamic>>[];
            final kickedList = data['kickedUsers'] is List
                ? (data['kickedUsers'] as List).map((x) => x.toString()).toList()
                : <String>[];

            return (
              success: true,
              roomDeleted: false,
              room: parsedRoom,
              members: membersList,
              seats: seatsList,
              currentSong: currentSong,
              currentPlayers: count,
              chatMessages: chatList,
              kickedUsers: kickedList,
            );
          }
        } else if (response.statusCode == 404) {
          final data = jsonDecode(response.body);
          final isDel = data is Map && data['roomDeleted'] == true;
          return (
            success: false,
            roomDeleted: isDel,
            room: null,
            members: <Map<String, dynamic>>[],
            seats: [],
            currentSong: null,
            currentPlayers: 0,
            chatMessages: <Map<String, dynamic>>[],
            kickedUsers: <String>[],
          );
        }
      } catch (e) {
        debugPrint('AwsStorageService getRoomState error: $e');
      }
    }

    return (
      success: false,
      roomDeleted: false,
      room: null,
      members: <Map<String, dynamic>>[],
      seats: [],
      currentSong: null,
      currentPlayers: 0,
      chatMessages: <Map<String, dynamic>>[],
      kickedUsers: <String>[],
    );
  }

  /// Take a mic seat in a room on AWS server
  static Future<List<dynamic>> takeSeat({
    required String roomId,
    required int seatIndex,
    required UserModel user,
  }) async {
    if (mockMode) return [];

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'takeSeat',
                'roomId': roomId,
                'seatIndex': seatIndex,
                'user': {
                  'id': user.id,
                  'name': user.name,
                  'tag': user.tag,
                  'profilePhoto': user.profilePhoto,
                  'avatarColor': user.avatarColor.toARGB32(),
                  'level': user.level,
                },
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['seats'] is List) {
            return (data['seats'] as List);
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService takeSeat error: $e');
      }
    }
    return [];
  }

  /// Leave a mic seat in a room on AWS server
  static Future<List<dynamic>> leaveSeat({
    required String roomId,
    required int seatIndex,
    required String userId,
  }) async {
    if (mockMode) return [];

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'leaveSeat',
                'roomId': roomId,
                'seatIndex': seatIndex,
                'userId': userId,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['seats'] is List) {
            return (data['seats'] as List);
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService leaveSeat error: $e');
      }
    }
    return [];
  }

  /// Sync room music playback state to all players in the room
  static Future<Map<String, dynamic>?> syncRoomMusic({
    required String roomId,
    required Map<String, dynamic> song,
  }) async {
    if (mockMode) return song;

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'syncRoomMusic',
                'roomId': roomId,
                'song': song,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['currentSong'] is Map) {
            return Map<String, dynamic>.from(data['currentSong']);
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService syncRoomMusic error: $e');
      }
    }
    return null;
  }

  /// Join a room and register membership on AWS server
  static Future<({
    bool success,
    RoomModel? room,
    List<Map<String, dynamic>> members,
    int currentPlayers,
    List<dynamic> seats,
    Map<String, dynamic>? currentSong,
  })> joinRoom({
    required String roomId,
    required UserModel user,
  }) async {
    final memberObj = {
      'userId': user.id,
      'name': user.name,
      'gamerTag': user.tag,
      'profilePhoto': user.profilePhoto,
      'role': 'listener',
      'joinedAt': DateTime.now().toIso8601String(),
    };

    final localList = _roomMembersMap.putIfAbsent(roomId, () => []);
    localList.removeWhere((m) => m['userId'] == user.id);
    localList.add(memberObj);

    if (mockMode) {
      return (
        success: true,
        room: null,
        members: localList,
        currentPlayers: localList.length,
        seats: [],
        currentSong: null,
      );
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'joinRoom',
                'roomId': roomId,
                'user': {
                  'id': user.id,
                  'name': user.name,
                  'tag': user.tag,
                  'profilePhoto': user.profilePhoto,
                },
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            RoomModel? parsedRoom;
            if (data['room'] is Map) {
              parsedRoom = RoomModel.fromMap(Map<String, dynamic>.from(data['room']));
            }
            final mList = data['members'] is List
                ? (data['members'] as List).cast<Map<String, dynamic>>()
                : localList;
            final seatsList = data['seats'] is List ? (data['seats'] as List) : <dynamic>[];
            final currentSong = data['currentSong'] is Map
                ? Map<String, dynamic>.from(data['currentSong'])
                : null;
            _roomMembersMap[roomId] = mList;
            final count = data['currentPlayers'] is int ? data['currentPlayers'] as int : mList.length;
            return (
              success: true,
              room: parsedRoom,
              members: mList,
              currentPlayers: count,
              seats: seatsList,
              currentSong: currentSong,
            );
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService joinRoom error: $e');
      }
    }

    return (
      success: true,
      room: null,
      members: localList,
      currentPlayers: localList.length,
      seats: [],
      currentSong: null,
    );
  }

  /// Leave a room and unregister membership on AWS server
  static Future<({bool success, List<Map<String, dynamic>> members, int currentPlayers})> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    if (_roomMembersMap.containsKey(roomId)) {
      _roomMembersMap[roomId]!.removeWhere((m) => m['userId'] == userId);
    }
    final remaining = _roomMembersMap[roomId] ?? [];

    if (mockMode) {
      return (success: true, members: remaining, currentPlayers: remaining.length);
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'leaveRoom',
                'roomId': roomId,
                'userId': userId,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['members'] is List) {
            final mList = (data['members'] as List).cast<Map<String, dynamic>>();
            _roomMembersMap[roomId] = mList;
            final count = data['currentPlayers'] is int ? data['currentPlayers'] as int : mList.length;
            return (success: true, members: mList, currentPlayers: count);
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService leaveRoom error: $e');
      }
    }

    return (success: true, members: remaining, currentPlayers: remaining.length);
  }

  /// Get active members of a room
  static Future<List<Map<String, dynamic>>> getRoomMembers(String roomId) async {
    if (mockMode) {
      return List<Map<String, dynamic>>.from(_roomMembersMap[roomId] ?? []);
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'getRoomMembers',
                'roomId': roomId,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['members'] is List) {
            final mList = (data['members'] as List).cast<Map<String, dynamic>>();
            _roomMembersMap[roomId] = mList;
            return mList;
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService getRoomMembers error: $e');
      }
    }

    return List<Map<String, dynamic>>.from(_roomMembersMap[roomId] ?? []);
  }

  /// Kick / remove a user from room (authorized for host)
  static Future<bool> kickUser({
    required String roomId,
    required String targetUserId,
    required String hostId,
  }) async {
    if (mockMode) return true;

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'kickUser',
                'roomId': roomId,
                'targetUserId': targetUserId,
                'hostId': hostId,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        return response.statusCode == 200;
      } catch (e) {
        debugPrint('AwsStorageService kickUser error: $e');
      }
    }
    return false;
  }

  /// Send a persistent message to the voice room chat
  static Future<bool> sendRoomMessage({
    required String roomId,
    required Map<String, dynamic> message,
  }) async {
    if (mockMode) return true;

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'sendRoomMessage',
                'roomId': roomId,
                'message': message,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        return response.statusCode == 200;
      } catch (e) {
        debugPrint('AwsStorageService sendRoomMessage error: $e');
      }
    }
    return false;
  }

  /// Clear all persistent room messages (authorized for host)
  static Future<bool> clearRoomChat({
    required String roomId,
    required String hostId,
  }) async {
    if (mockMode) return true;

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'clearRoomChat',
                'roomId': roomId,
                'hostId': hostId,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        return response.statusCode == 200;
      } catch (e) {
        debugPrint('AwsStorageService clearRoomChat error: $e');
      }
    }
    return false;
  }

  /// Send a WebRTC voice signaling message (offer, answer, candidate) to a room peer
  static Future<bool> sendVoiceSignal({
    required String roomId,
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
    required String signalType,
    required Map<String, dynamic> signalData,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final sig = {
      'id': 'sig_${now}_${fromUserId.hashCode}',
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'signalType': signalType,
      'signalData': signalData,
      'timestamp': now,
    };

    if (mockMode) {
      _mockSignalsMap.putIfAbsent(roomId, () => []).add(sig);
      return true;
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'sendVoiceSignal',
                'roomId': roomId,
                'fromUserId': fromUserId,
                'fromUserName': fromUserName,
                'toUserId': toUserId,
                'signalType': signalType,
                'signalData': signalData,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        return response.statusCode == 200;
      } catch (e) {
        debugPrint('AwsStorageService sendVoiceSignal error: $e');
      }
    }

    _mockSignalsMap.putIfAbsent(roomId, () => []).add(sig);
    return true;
  }

  /// Retrieve pending WebRTC voice signaling messages for current user in a room
  static Future<List<Map<String, dynamic>>> getVoiceSignals({
    required String roomId,
    required String userId,
    int lastTimestamp = 0,
  }) async {
    if (mockMode) {
      final list = _mockSignalsMap[roomId] ?? [];
      final uIdLower = userId.toLowerCase();
      return list.where((s) {
        final from = (s['fromUserId'] ?? '').toString().toLowerCase();
        if (from == uIdLower) return false;
        final to = (s['toUserId'] ?? '*').toString().toLowerCase();
        final isForMe = to == '*' || to == uIdLower;
        final isNew = ((s['timestamp'] as num?)?.toInt() ?? 0) > lastTimestamp;
        return isForMe && isNew;
      }).toList();
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'getVoiceSignals',
                'roomId': roomId,
                'userId': userId,
                'lastTimestamp': lastTimestamp,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['signals'] is List) {
            return (data['signals'] as List).cast<Map<String, dynamic>>();
          }
        }
      } catch (e) {
        // Suppress timeout in rapid polling
      }
    }

    final list = _mockSignalsMap[roomId] ?? [];
    final uIdLower = userId.toLowerCase();
    return list.where((s) {
      final from = (s['fromUserId'] ?? '').toString().toLowerCase();
      if (from == uIdLower) return false;
      final to = (s['toUserId'] ?? '*').toString().toLowerCase();
      final isForMe = to == '*' || to == uIdLower;
      final isNew = ((s['timestamp'] as num?)?.toInt() ?? 0) > lastTimestamp;
      return isForMe && isNew;
    }).toList();
  }

  /// Send gift to recipient: deducts sender coins and increments recipient coins on server
  static Future<Map<String, dynamic>> sendGift({
    required String senderId,
    required String senderName,
    required String recipientId,
    required int coins,
    required String giftName,
    required String giftIcon,
  }) async {
    if (mockMode) {
      return {'success': true, 'coinsAwarded': coins};
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'sendGift',
                'senderId': senderId,
                'senderName': senderName,
                'recipientId': recipientId,
                'coins': coins,
                'giftName': giftName,
                'giftIcon': giftIcon,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            return Map<String, dynamic>.from(data);
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService sendGift error: $e');
      }
    }

    return {'success': false};
  }

  /// Get real-time notifications for a user (follower alerts, gifts received)
  static Future<List<Map<String, dynamic>>> getNotifications(String userIdOrEmail) async {
    if (mockMode) return [];

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'getNotifications',
                'userId': userIdOrEmail,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['notifications'] is List) {
            return (data['notifications'] as List).cast<Map<String, dynamic>>();
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService getNotifications error: $e');
      }
    }
    return [];
  }

  /// Clear or mark read all notifications for a user
  static Future<bool> markNotificationsRead(String userIdOrEmail) async {
    if (mockMode) return true;

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'markNotificationsRead',
                'userId': userIdOrEmail,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        return response.statusCode == 200;
      } catch (e) {
        debugPrint('AwsStorageService markNotificationsRead error: $e');
      }
    }
    return false;
  }

  /// Send a 1-on-1 direct message between mutual friends
  static Future<bool> sendDirectMessage({
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    final msg = {
      'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
    };
    _directMessages.add(msg);

    if (mockMode) return true;

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'sendDirectMessage',
                'senderId': senderId,
                'receiverId': receiverId,
                'text': text,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        return response.statusCode == 200 || response.statusCode == 201;
      } catch (e) {
        debugPrint('AwsStorageService sendDirectMessage error: $e');
        return false;
      }
    }

    return true;
  }

  /// Get direct messages between two users
  static Future<List<Map<String, dynamic>>> getDirectMessages({
    required String userA,
    required String userB,
  }) async {
    if (mockMode) {
      return _directMessages
          .where((m) =>
              (m['senderId'] == userA && m['receiverId'] == userB) ||
              (m['senderId'] == userB && m['receiverId'] == userA))
          .toList();
    }

    if (AwsConfig.isConfigured) {
      try {
        final uri = Uri.parse(AwsConfig.apiEndpoint);
        final headers = {
          'Content-Type': 'application/json',
          if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
        };

        final response = await httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'action': 'getDirectMessages',
                'userA': userA,
                'userB': userB,
                'tableName': AwsConfig.tableName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map && data['messages'] is List) {
            return (data['messages'] as List).cast<Map<String, dynamic>>();
          }
        }
      } catch (e) {
        debugPrint('AwsStorageService getDirectMessages error: $e');
      }
    }

    return _directMessages
        .where((m) =>
            (m['senderId'] == userA && m['receiverId'] == userB) ||
            (m['senderId'] == userB && m['receiverId'] == userA))
        .toList();
  }

  /// Test connection to AWS endpoint
  static Future<({bool success, String message})> testConnection() async {
    if (!AwsConfig.isConfigured) {
      return (
        success: false,
        message:
            'AWS API Gateway endpoint is not set. Please enter your AWS Lambda / API Gateway URL below.',
      );
    }

    try {
      final uri = Uri.parse(AwsConfig.apiEndpoint);
      final headers = {
        'Content-Type': 'application/json',
        if (AwsConfig.apiKey.isNotEmpty) 'x-api-key': AwsConfig.apiKey.trim(),
      };

      final stopwatch = Stopwatch()..start();
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'action': 'ping',
              'tableName': AwsConfig.tableName,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 6));
      stopwatch.stop();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (
          success: true,
          message:
              'Connected to AWS API Gateway (${stopwatch.elapsedMilliseconds}ms)! DynamoDB table "${AwsConfig.tableName}" ready.',
        );
      } else {
        return (
          success: false,
          message:
              'AWS responded with HTTP ${response.statusCode}: ${response.body.isNotEmpty ? response.body : "Check your API Gateway permissions or Lambda handler."}',
        );
      }
    } catch (e) {
      return (
        success: false,
        message:
            'Connection failed: $e. Verify the URL and ensure your phone has internet access.',
      );
    }
  }

  /// Get the recommended AWS Lambda handler code for DynamoDB integration
  static String getRecommendedLambdaCode() {
    return '''
// AWS Lambda (Node.js 20.x) for Play Friends User Storage, Auth, and Directory
// Table: PlayFriends_Users (Primary Key: email [String], GSI: phoneNumber [String])

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, ScanCommand, GetCommand, DeleteCommand } = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const TABLE_NAME = process.env.TABLE_NAME || "PlayFriends_Users";

exports.handler = async (event) => {
    let body = {};
    if (event.body) {
        body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    }
    
    const action = body.action || "ping";
    
    try {
        if (action === "ping") {
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ status: "ok", message: "Play Friends AWS backend online" })
            };
        }
        
        // -------------------------------------------------------------
        // LOGIN: Supports Email, Mobile Number, Gamer Tag, or Security ID
        // -------------------------------------------------------------
        if (action === "login") {
            const rawId = (body.identifier || body.email || body.phoneNumber || body.tag || "").trim();
            const password = (body.password || "").trim();
            
            if (!rawId || !password) {
                return {
                    statusCode: 400,
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ success: false, error: "Please enter your credentials." })
                };
            }
            
            const cleanEmail = rawId.toLowerCase();
            const cleanDigits = rawId.replace(/\\D/g, "");
            const cleanTag = rawId.toLowerCase().replace(/^@/, "");
            
            let userItem = null;
            if (rawId.includes("@") && rawId.includes(".")) {
                const getResult = await docClient.send(new GetCommand({
                    TableName: TABLE_NAME,
                    Key: { email: cleanEmail }
                }));
                if (getResult.Item) {
                    userItem = getResult.Item;
                }
            }
            
            if (!userItem) {
                const scanResult = await docClient.send(new ScanCommand({
                    TableName: TABLE_NAME,
                    Limit: 200
                }));
                
                for (const item of (scanResult.Items || [])) {
                    const itemEmail = (item.email || "").toLowerCase();
                    const itemPhone = (item.phoneNumber || "").replace(/\\D/g, "");
                    const itemTag = (item.tag || item.gamerTag || "").toLowerCase().replace(/^@/, "");
                    const itemId = (item.userId || item.id || "").toLowerCase();
                    
                    if (
                        (cleanEmail && itemEmail === cleanEmail) ||
                        (cleanDigits && cleanDigits.length >= 7 && (itemPhone === cleanDigits || itemPhone.endsWith(cleanDigits) || cleanDigits.endsWith(itemPhone))) ||
                        (cleanTag && itemTag === cleanTag) ||
                        (itemId && itemId === rawId.toLowerCase())
                    ) {
                        userItem = item;
                        break;
                    }
                }
            }
            
            if (!userItem) {
                return {
                    statusCode: 404,
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        success: false,
                        error: "Account not found. Please check your credentials or register."
                    })
                };
            }
            
            // Password verification
            const storedPass = userItem.password || userItem.passwordHash;
            if (storedPass) {
                const isMatch = (storedPass === password) || (userItem.passwordHash && userItem.passwordHash === password);
                if (!isMatch) {
                    return {
                        statusCode: 401,
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify({
                            success: false,
                            error: "Incorrect password. Please try again."
                        })
                    };
                }
            } else {
                // If legacy record without password, update their password so subsequent logins work
                userItem.password = password;
                userItem.updatedAt = new Date().toISOString();
                await docClient.send(new PutCommand({
                    TableName: TABLE_NAME,
                    Item: userItem
                }));
            }
            
            const clientUser = {
                id: userItem.userId || userItem.id || "01000000",
                userId: userItem.userId || userItem.id || "01000000",
                name: userItem.name || "Player",
                tag: userItem.tag || userItem.gamerTag || ("@" + (userItem.name || "player").toLowerCase().replace(/\\s+/g, "_")),
                gamerTag: userItem.tag || userItem.gamerTag || ("@" + (userItem.name || "player").toLowerCase().replace(/\\s+/g, "_")),
                email: userItem.email,
                phoneNumber: userItem.phoneNumber,
                countryCode: userItem.countryCode || "+91",
                countryFlag: userItem.countryFlag || "🇮🇳",
                level: userItem.level || 1,
                coins: userItem.coins || 500,
                trophies: userItem.trophies || 0,
                profilePhoto: userItem.profilePhoto || null,
                role: userItem.role || "user"
            };
            
            const sessionToken = "pf_sess_" + Math.random().toString(36).substring(2) + Date.now().toString(36);
            
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    success: true,
                    user: clientUser,
                    sessionToken: sessionToken
                })
            };
        }
        
        // -------------------------------------------------------------
        // CHECK USER: Checks if email or mobile exists
        // -------------------------------------------------------------
        if (action === "checkUser") {
            const email = (body.email || "").toLowerCase().trim();
            const phone = (body.phoneNumber || "").replace(/\\D/g, "");
            
            // Check by Email
            if (email) {
                const emailResult = await docClient.send(new GetCommand({
                    TableName: TABLE_NAME,
                    Key: { email }
                }));
                
                if (emailResult.Item) {
                    return {
                        statusCode: 200,
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify({
                            exists: true,
                            field: "email",
                            message: "This email is already registered. Please sign in or use another email."
                        })
                    };
                }
            }
            
            // Check by Phone Number
            if (phone && phone.length >= 7) {
                const scanResult = await docClient.send(new ScanCommand({
                    TableName: TABLE_NAME,
                    Limit: 200
                }));
                
                const matched = (scanResult.Items || []).find(item => {
                    const itemPhone = (item.phoneNumber || "").replace(/\\D/g, "");
                    return itemPhone && (itemPhone === phone || itemPhone.endsWith(phone) || phone.endsWith(itemPhone));
                });
                
                if (matched) {
                    // If an uncompleted legacy test record has no password, allow registration to adopt it
                    const hasPassword = !!(matched.password || matched.passwordHash);
                    if (hasPassword) {
                        return {
                            statusCode: 200,
                            headers: { "Content-Type": "application/json" },
                            body: JSON.stringify({
                                exists: true,
                                field: "mobile",
                                message: "This mobile number is already registered in AWS. Please sign in with your mobile number or use another number."
                            })
                        };
                    }
                }
            }
            
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ exists: false })
            };
        }
        
        // -------------------------------------------------------------
        // REGISTER: Stores user and password in AWS DynamoDB
        // -------------------------------------------------------------
        if (action === "register") {
            const email = (body.email || "").toLowerCase().trim();
            const phone = (body.phoneNumber || "").trim();
            const password = (body.password || "").trim();
            const passwordHash = (body.passwordHash || "").trim();
            
            const item = {
                email: email,
                phoneNumber: phone,
                userId: body.userId || ("01" + Math.floor(100000 + Math.random() * 900000)),
                name: body.name || "Player",
                tag: body.tag || ("@" + (body.name || "player").toLowerCase().replace(/\\s+/g, "_")),
                countryCode: body.countryCode || "+91",
                countryFlag: body.countryFlag || "🇮🇳",
                password: password || passwordHash,
                passwordHash: passwordHash || password,
                level: body.level || 1,
                coins: body.coins || 500,
                trophies: body.trophies || 0,
                createdAt: body.registeredAt || new Date().toISOString(),
                updatedAt: new Date().toISOString()
            };
            
            await docClient.send(new PutCommand({
                TableName: TABLE_NAME,
                Item: item
            }));
            
            return {
                statusCode: 201,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    success: true,
                    message: "User and credentials stored in AWS DynamoDB successfully",
                    user: item
                })
            };
        }
        
        // -------------------------------------------------------------
        // LIST USERS: Directory of all registered users
        // -------------------------------------------------------------
        if (action === "listUsers" || action === "getAllUsers") {
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_NAME,
                Limit: 200
            }));
            const users = (scanResult.Items || []).map(u => ({
                id: u.userId || u.id || "01000000",
                userId: u.userId || u.id || "01000000",
                securityId: u.userId || u.id || "01000000",
                name: u.name || "Player",
                gamerTag: u.tag || u.gamerTag || ("@" + (u.name || "player").toLowerCase().replace(/\\s+/g, "_")),
                email: u.email,
                phoneNumber: u.phoneNumber,
                level: u.level || 1,
                coins: u.coins || 500,
                trophies: u.trophies || 0,
                profilePhoto: u.profilePhoto || null,
                createdAt: u.createdAt
            }));
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(users)
            };
        }
        
        // -------------------------------------------------------------
        // SEARCH USERS
        // -------------------------------------------------------------
        if (action === "searchUsers") {
            const raw = (body.query || body.q || "").toLowerCase().trim();
            const cleanQ = raw.replace(/^@/, "");
            if (!cleanQ) {
                return {
                    statusCode: 200,
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify([])
                };
            }
            
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_NAME,
                Limit: 100
            }));
            
            const matched = [];
            for (const u of (scanResult.Items || [])) {
                const uId = (u.userId || u.id || "").toLowerCase();
                const uTag = (u.tag || u.gamerTag || "").toLowerCase().replace(/^@/, "");
                const uName = (u.name || "").toLowerCase();
                const uEmail = (u.email || "").toLowerCase();
                
                if (uId.includes(cleanQ) || uTag.includes(cleanQ) || uName.includes(cleanQ) || uEmail.includes(cleanQ)) {
                    matched.push({
                        id: u.userId || u.id || "01000000",
                        userId: u.userId || u.id || "01000000",
                        securityId: u.userId || u.id || "01000000",
                        name: u.name || "Player",
                        tag: u.tag || ("@" + (u.name || "player").toLowerCase().replace(/\\s+/g, "_")),
                        gamerTag: u.tag || ("@" + (u.name || "player").toLowerCase().replace(/\\s+/g, "_")),
                        email: u.email,
                        level: u.level || 1,
                        coins: u.coins || 500,
                        trophies: u.trophies || 0,
                        profilePhoto: u.profilePhoto || null
                    });
                }
            }
            
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(matched)
            };
        }
        
        // -------------------------------------------------------------
        // RESET PASSWORD
        // -------------------------------------------------------------
        if (action === "resetPassword") {
            const email = (body.email || "").toLowerCase().trim();
            const phone = (body.phoneNumber || "").replace(/\\D/g, "");
            const newPassword = (body.newPassword || "").trim();
            
            if (!newPassword) {
                return {
                    statusCode: 400,
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ success: false, error: "New password is required." })
                };
            }
            
            let userItem = null;
            if (email) {
                const res = await docClient.send(new GetCommand({
                    TableName: TABLE_NAME,
                    Key: { email }
                }));
                userItem = res.Item;
            }
            
            if (!userItem && phone) {
                const scanRes = await docClient.send(new ScanCommand({
                    TableName: TABLE_NAME,
                    Limit: 200
                }));
                userItem = (scanRes.Items || []).find(u => {
                    const p = (u.phoneNumber || "").replace(/\\D/g, "");
                    return p === phone;
                });
            }
            
            if (!userItem) {
                return {
                    statusCode: 404,
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ success: false, error: "Account not found." })
                };
            }
            
            userItem.password = newPassword;
            userItem.passwordHash = newPassword;
            userItem.updatedAt = new Date().toISOString();
            await docClient.send(new PutCommand({
                TableName: TABLE_NAME,
                Item: userItem
            }));
            
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ success: true, message: "Password updated successfully." })
            };
        }
        
        // -------------------------------------------------------------
        // DELETE USER
        // -------------------------------------------------------------
        if (action === "deleteUser") {
            const email = (body.email || "").toLowerCase().trim();
            if (email) {
                await docClient.send(new DeleteCommand({
                    TableName: TABLE_NAME,
                    Key: { email }
                }));
            }
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ success: true, message: "User deleted from server." })
            };
        }
        
        // -------------------------------------------------------------
        // PROFILE PHOTO
        // -------------------------------------------------------------
        if (action === "updateProfilePhoto" || action === "deleteProfilePhoto") {
            const email = (body.email || "").toLowerCase().trim();
            const photo = action === "deleteProfilePhoto" ? null : body.profilePhoto;
            
            await docClient.send(new PutCommand({
                TableName: TABLE_NAME,
                Item: { email, profilePhoto: photo, updatedAt: new Date().toISOString() }
            }));
            
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ success: true, message: "Profile photo updated on server" })
            };
        }
        
        // -------------------------------------------------------------
        // SONGS
        // -------------------------------------------------------------
        if (action === "uploadSong") {
            const song = body.song || {};
            await docClient.send(new PutCommand({
                TableName: TABLE_NAME + "_Songs",
                Item: { ...song, updatedAt: new Date().toISOString() }
            }));
            
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ success: true, message: "Song saved to server" })
            };
        }
        
        if (action === "getUserSongs") {
            const userId = body.userId;
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_NAME + "_Songs",
                FilterExpression: "userId = :uid",
                ExpressionAttributeValues: { ":uid": userId }
            }));
            
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ success: true, songs: scanResult.Items || [] })
            };
        }
        
        // -------------------------------------------------------------
        // ROOMS
        // -------------------------------------------------------------
        if (action === "getRooms") {
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_NAME + "_Rooms",
                Limit: 50
            }));
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(scanResult.Items || [])
            };
        }
        
        if (action === "createRoom") {
            const room = body.room || body;
            await docClient.send(new PutCommand({
                TableName: TABLE_NAME + "_Rooms",
                Item: { ...room, updatedAt: new Date().toISOString() }
            }));
            return {
                statusCode: 201,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ success: true, room })
            };
        }
        
        if (action === "deleteRoom") {
            const roomId = body.roomId || body.id;
            await docClient.send(new DeleteCommand({
                TableName: TABLE_NAME + "_Rooms",
                Key: { id: roomId }
            }));
            return {
                statusCode: 200,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ success: true })
            };
        }
        
        return { statusCode: 400, body: JSON.stringify({ error: "Unknown action" }) };
    } catch (err) {
        return {
            statusCode: 500,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ error: err.message })
        };
    }
};
''';
  }
}
