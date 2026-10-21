import 'package:flutter/material.dart';

class FriendModel {
  final String id;
  final String name;
  final String tag;
  final String initial;
  final Color avatarColor;
  final int level;
  final bool isOnline;
  final String statusText;
  final String favoriteGame;

  const FriendModel({
    required this.id,
    required this.name,
    required this.tag,
    required this.initial,
    required this.avatarColor,
    required this.level,
    required this.isOnline,
    required this.statusText,
    required this.favoriteGame,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tag': tag,
      'initial': initial,
      'avatarColor': avatarColor.toARGB32(),
      'level': level,
      'isOnline': isOnline,
      'statusText': statusText,
      'favoriteGame': favoriteGame,
    };
  }

  factory FriendModel.fromMap(Map<String, dynamic> map) {
    return FriendModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      tag: map['tag']?.toString() ?? '',
      initial: map['initial']?.toString() ?? 'P',
      avatarColor: Color(map['avatarColor'] is int ? map['avatarColor'] as int : 0xFF7C3AED),
      level: map['level'] is int ? map['level'] as int : 1,
      isOnline: map['isOnline'] == true,
      statusText: map['statusText']?.toString() ?? '',
      favoriteGame: map['favoriteGame']?.toString() ?? '',
    );
  }
}
