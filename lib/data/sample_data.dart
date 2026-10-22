import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../models/friend_model.dart';
import '../models/room_model.dart';
import '../models/chat_model.dart';

class SampleData {
  // Current user info
  static const String currentUserName = "Alex Vance";
  static const String currentUserTag = "@alex_play";
  static const int currentUserLevel = 1;
  static const int currentUserCoins = 500;
  static const int currentUserTrophies = 0;
  static const double currentUserWinRate = 0.0;
  static const int currentUserTotalMatches = 0;

  // Games Catalog (Real Playable Games with Progression Unlocks)
  static const List<GameModel> games = [
    GameModel(
      id: 'tic_tac_toe',
      title: 'Tic-Tac-Toe Duel',
      category: GameCategory.board,
      description:
          'Classic quick duel! Local 2-player Pass & Play or challenge the AI bot.',
      icon: Icons.grid_3x3_rounded,
      primaryColor: Color(0xFF06B6D4),
      secondaryColor: Color(0xFF8B5CF6),
      playerCount: '1-2 Players',
      isPlayable: true,
      statusBadge: 'PLAYABLE NOW',
      rating: 4.9,
      requiredLevel: 1,
      requiredWins: 0,
    ),
    GameModel(
      id: 'ludo',
      title: 'Ludo Friends',
      category: GameCategory.board,
      description:
          'Roll the dice and race your tokens home in this classic social board duel.',
      icon: Icons.casino_rounded,
      primaryColor: Color(0xFFF59E0B),
      secondaryColor: Color(0xFFEF4444),
      playerCount: '2 Players',
      isPlayable: true,
      statusBadge: 'UNLOCKS AT LEVEL 5 OR 20 WINS',
      rating: 4.8,
      requiredLevel: 5,
      requiredWins: 20,
    ),
    GameModel(
      id: 'carrom',
      title: 'Carrom Clash',
      category: GameCategory.board,
      description:
          'Strike coins into pockets with physics-based carrom board mechanics.',
      icon: Icons.disc_full_rounded,
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF059669),
      playerCount: '2 Players',
      isPlayable: true,
      statusBadge: 'UNLOCKS AT LEVEL 10 OR 40 WINS',
      rating: 4.7,
      requiredLevel: 10,
      requiredWins: 40,
    ),
    GameModel(
      id: 'space_dodge',
      title: 'Cyber Space Dodge',
      category: GameCategory.action,
      description:
          'Dodge incoming laser asteroids and compete for the top high score.',
      icon: Icons.rocket_launch_rounded,
      primaryColor: Color(0xFFEC4899),
      secondaryColor: Color(0xFF8B5CF6),
      playerCount: 'Solo Arcade',
      isPlayable: true,
      statusBadge: 'UNLOCKS AT LEVEL 15 OR 60 WINS',
      rating: 4.6,
      requiredLevel: 15,
      requiredWins: 60,
    ),
    GameModel(
      id: 'arena_brawl',
      title: 'Neon Arena Brawl',
      category: GameCategory.action,
      description:
          'Fast-paced multiplayer party combat with colorful neon arenas.',
      icon: Icons.sports_kabaddi_rounded,
      primaryColor: Color(0xFF6366F1),
      secondaryColor: Color(0xFF3B82F6),
      playerCount: '2-4 Players',
      isPlayable: true,
      statusBadge: 'UNLOCKS AT LEVEL 20 OR 80 WINS',
      rating: 4.5,
      requiredLevel: 20,
      requiredWins: 80,
    ),
    GameModel(
      id: 'word_rush',
      title: 'Word Sprint',
      category: GameCategory.casual,
      description:
          'Race against friends to find words under rapid countdown pressure.',
      icon: Icons.text_fields_rounded,
      primaryColor: Color(0xFF38BDF8),
      secondaryColor: Color(0xFF0284C7),
      playerCount: '2-6 Players',
      isPlayable: true,
      statusBadge: 'UNLOCKS AT LEVEL 25 OR 100 WINS',
      rating: 4.4,
      requiredLevel: 25,
      requiredWins: 100,
    ),
  ];

  // Fresh Real Friends (Empty by default)
  static const List<FriendModel> friends = [];

  // Fresh Real Rooms (Empty by default)
  static const List<RoomModel> rooms = [];

  // Fresh Real Chat Threads (Empty by default)
  static final List<ChatThread> chatThreads = [];
}
