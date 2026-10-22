import 'package:flutter/material.dart';
import 'friend_model.dart';

class UserModel {
  final String id;
  final String name;
  final String tag;
  final String email;
  final Color avatarColor;
  final String avatarInitial;
  final String? phoneNumber;
  final String countryCode;
  final String countryFlag;
  final int level;
  final int coins;
  final int trophies;
  final double winRate;
  final int totalMatches;
  final int totalWins;
  final int xp;
  final List<String> unlockedGameIds;
  final List<FriendModel> friends;
  final bool isGuest;
  final String role; // 'user' or 'admin' (strictly backend authorized)
  final String? sessionToken;
  final String? profilePhoto;
  final String? gender;
  final String? birthday;
  final List<String> interests;
  final String? education;
  final String? school;
  final String? occupation;
  final String? spokenLanguages;
  final String? aboutMe;
  final String? sportsAnswer;
  final String? musicAnswer;
  final String? foodAnswer;

  /// Returns true only if the user has verified administrator role with a valid session token
  bool get isAdmin =>
      role == 'admin' && (sessionToken != null && sessionToken!.isNotEmpty);

  /// Calculates profile completion percentage based on profile photo, personal info and Q&A answers
  int get profileCompletionPercentage {
    int filled = 0;
    const total = 12;
    if (profilePhoto != null && profilePhoto!.isNotEmpty) filled++;
    if (gender != null && gender!.isNotEmpty) filled++;
    if (name.isNotEmpty) filled++;
    if (birthday != null && birthday!.isNotEmpty) filled++;
    if (interests.isNotEmpty) filled++;
    if (education != null && education!.isNotEmpty) filled++;
    if (school != null && school!.isNotEmpty) filled++;
    if (occupation != null && occupation!.isNotEmpty) filled++;
    if (spokenLanguages != null && spokenLanguages!.isNotEmpty) filled++;
    if (aboutMe != null && aboutMe!.isNotEmpty) filled++;
    if (sportsAnswer != null && sportsAnswer!.isNotEmpty) filled++;
    if (musicAnswer != null && musicAnswer!.isNotEmpty) filled++;
    if (foodAnswer != null && foodAnswer!.isNotEmpty) filled++;
    final pct = ((filled / total) * 100).round();
    return pct.clamp(0, 100);
  }

  const UserModel({
    required this.id,
    required this.name,
    required this.tag,
    required this.email,
    required this.avatarColor,
    required this.avatarInitial,
    this.phoneNumber,
    this.countryCode = '+91',
    this.countryFlag = '🇮🇳',
    this.level = 1,
    this.coins = 500,
    this.trophies = 0,
    this.winRate = 0.0,
    this.totalMatches = 0,
    this.totalWins = 0,
    this.xp = 0,
    this.unlockedGameIds = const ['tic_tac_toe'],
    this.friends = const [],
    this.isGuest = false,
    this.role = 'user',
    this.sessionToken,
    this.profilePhoto,
    this.gender = 'Male',
    this.birthday = '1999-01-01',
    this.interests = const [],
    this.education,
    this.school,
    this.occupation,
    this.spokenLanguages,
    this.aboutMe,
    this.sportsAnswer,
    this.musicAnswer,
    this.foodAnswer,
  });

  UserModel copyWith({
    String? name,
    String? tag,
    String? email,
    Color? avatarColor,
    String? avatarInitial,
    String? phoneNumber,
    String? countryCode,
    String? countryFlag,
    int? level,
    int? coins,
    int? trophies,
    double? winRate,
    int? totalMatches,
    int? totalWins,
    int? xp,
    List<String>? unlockedGameIds,
    List<FriendModel>? friends,
    bool? isGuest,
    String? role,
    String? sessionToken,
    String? profilePhoto,
    bool clearProfilePhoto = false,
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
    return UserModel(
      id: id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      email: email ?? this.email,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarInitial: avatarInitial ?? this.avatarInitial,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryCode: countryCode ?? this.countryCode,
      countryFlag: countryFlag ?? this.countryFlag,
      level: level ?? this.level,
      coins: coins ?? this.coins,
      trophies: trophies ?? this.trophies,
      winRate: winRate ?? this.winRate,
      totalMatches: totalMatches ?? this.totalMatches,
      totalWins: totalWins ?? this.totalWins,
      xp: xp ?? this.xp,
      unlockedGameIds: unlockedGameIds ?? this.unlockedGameIds,
      friends: friends ?? this.friends,
      isGuest: isGuest ?? this.isGuest,
      role: role ?? this.role,
      sessionToken: sessionToken ?? this.sessionToken,
      profilePhoto:
          clearProfilePhoto ? null : (profilePhoto ?? this.profilePhoto),
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      interests: interests ?? this.interests,
      education: education ?? this.education,
      school: school ?? this.school,
      occupation: occupation ?? this.occupation,
      spokenLanguages: spokenLanguages ?? this.spokenLanguages,
      aboutMe: aboutMe ?? this.aboutMe,
      sportsAnswer: sportsAnswer ?? this.sportsAnswer,
      musicAnswer: musicAnswer ?? this.musicAnswer,
      foodAnswer: foodAnswer ?? this.foodAnswer,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tag': tag,
      'email': email,
      'avatarColor': avatarColor.toARGB32(),
      'avatarInitial': avatarInitial,
      'phoneNumber': phoneNumber,
      'countryCode': countryCode,
      'countryFlag': countryFlag,
      'level': level,
      'coins': coins,
      'trophies': trophies,
      'winRate': winRate,
      'totalMatches': totalMatches,
      'totalWins': totalWins,
      'xp': xp,
      'unlockedGameIds': unlockedGameIds,
      'friends': friends.map((f) => f.toMap()).toList(),
      'isGuest': isGuest,
      'role': role,
      'sessionToken': sessionToken,
      'profilePhoto': profilePhoto,
      'gender': gender,
      'birthday': birthday,
      'interests': interests,
      'education': education,
      'school': school,
      'occupation': occupation,
      'spokenLanguages': spokenLanguages,
      'aboutMe': aboutMe,
      'sportsAnswer': sportsAnswer,
      'musicAnswer': musicAnswer,
      'foodAnswer': foodAnswer,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawToken = map['sessionToken']?.toString();
    final rawRole =
        map['role']?.toString() ?? (map['isAdmin'] == true ? 'admin' : 'user');
    // Tamper protection: Never accept 'admin' role from local storage without a valid session token
    final validatedRole =
        (rawRole == 'admin' && rawToken != null && rawToken.isNotEmpty)
            ? 'admin'
            : 'user';

    return UserModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Player',
      tag: map['tag']?.toString() ?? '@player',
      email: map['email']?.toString() ?? '',
      avatarColor: Color(
          map['avatarColor'] is int ? map['avatarColor'] as int : 0xFF7C3AED),
      avatarInitial: map['avatarInitial']?.toString() ?? 'P',
      phoneNumber: map['phoneNumber']?.toString(),
      countryCode: map['countryCode']?.toString() ?? '+91',
      countryFlag: map['countryFlag']?.toString() ?? '🇮🇳',
      level: map['level'] is int ? map['level'] as int : 1,
      coins: map['coins'] is int ? map['coins'] as int : 500,
      trophies: map['trophies'] is int ? map['trophies'] as int : 0,
      winRate:
          (map['winRate'] is num) ? (map['winRate'] as num).toDouble() : 0.0,
      totalMatches: map['totalMatches'] is int ? map['totalMatches'] as int : 0,
      totalWins: map['totalWins'] is int ? map['totalWins'] as int : 0,
      xp: map['xp'] is int ? map['xp'] as int : 0,
      unlockedGameIds: (map['unlockedGameIds'] is List)
          ? (map['unlockedGameIds'] as List).cast<String>()
          : const ['tic_tac_toe'],
      friends: (map['friends'] is List)
          ? (map['friends'] as List)
              .map((item) =>
                  FriendModel.fromMap(Map<String, dynamic>.from(item as Map)))
              .toList()
          : const [],
      isGuest: map['isGuest'] == true,
      role: validatedRole,
      sessionToken: rawToken,
      profilePhoto: map['profilePhoto']?.toString(),
      gender: map['gender']?.toString() ?? 'Male',
      birthday: map['birthday']?.toString() ?? '1999-01-01',
      interests: (map['interests'] is List)
          ? (map['interests'] as List).cast<String>()
          : const [],
      education: map['education']?.toString(),
      school: map['school']?.toString(),
      occupation: map['occupation']?.toString(),
      spokenLanguages: map['spokenLanguages']?.toString(),
      aboutMe: map['aboutMe']?.toString(),
      sportsAnswer: map['sportsAnswer']?.toString(),
      musicAnswer: map['musicAnswer']?.toString(),
      foodAnswer: map['foodAnswer']?.toString(),
    );
  }
}
