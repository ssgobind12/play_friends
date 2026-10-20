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
}
