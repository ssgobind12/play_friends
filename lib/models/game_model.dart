import 'package:flutter/material.dart';

enum GameCategory {
  board,
  action,
  casual,
}

class GameModel {
  final String id;
  final String title;
  final GameCategory category;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final String playerCount;
  final bool isPlayable;
  final String statusBadge;
  final double rating;
  final int requiredLevel;
  final int requiredWins;

  const GameModel({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.playerCount,
    required this.isPlayable,
    required this.statusBadge,
    required this.rating,
    this.requiredLevel = 1,
    this.requiredWins = 0,
  });
}
