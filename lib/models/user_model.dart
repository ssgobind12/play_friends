import 'package:flutter/material.dart';
import 'friend_model.dart';

class UserModel {
  final String id;
  final String name;
  final String tag;
  final String email;
  final String password;
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
  final bool isAdmin;
  final String? profilePhoto;

  const UserModel({
    required this.id,
    required this.name,
    required this.tag,
    required this.email,
    required this.password,
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
    this.isAdmin = false,
    this.profilePhoto,
  });

  UserModel copyWith({
    String? name,
    String? tag,
    String? email,
    String? password,
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
    bool? isAdmin,
    String? profilePhoto,
    bool clearProfilePhoto = false,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      email: email ?? this.email,
      password: password ?? this.password,
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
      isAdmin: isAdmin ?? this.isAdmin,
      profilePhoto: clearProfilePhoto ? null : (profilePhoto ?? this.profilePhoto),
    );
  }
}
