import 'dart:math';
import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/room_card.dart';
import '../widgets/music_player_sheet.dart';
import 'carrom_game_screen.dart';
import 'ludo_game_screen.dart';
import 'space_dodge_screen.dart';
import 'tic_tac_toe_screen.dart';
import 'neon_arena_brawl_screen.dart';
import 'word_rush_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  late List<RoomModel> _rooms;

  @override
  void initState() {
    super.initState();
    _rooms = List.from(AuthService().activeRooms);
  }

  void _refreshRooms() {
    setState(() {
      _rooms = List.from(AuthService().activeRooms);
    });
  }

  void _handleCreateRoom() {
    final userLevel = AuthService().currentUser?.level ?? 1;
    // Room member formula: Level 20 -> 10 members. Level 1 -> 2 members.
    final maxAllowedMembers = (userLevel / 2).floor().clamp(2, 50);

    String selectedGame = 'Tic-Tac-Toe Duel';
    int maxPlayers = 2;
    bool isPrivate = false;

    // Available member options based on host level
    final availableCounts = <int>[];
    for (final c in [2, 4, 6, 8, 10, 16, 24, 32, 50]) {
      if (c <= maxAllowedMembers) {
        availableCounts.add(c);
      }
    }
    if (availableCounts.isEmpty) availableCounts.add(2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.add_box_rounded, color: AppColors.primaryBlueLight),
                      SizedBox(width: 10),
                      Text(
                        'Create Game Room',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.military_tech_rounded, color: AppColors.coinAmber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your Level: $userLevel • Room capacity: Max $maxAllowedMembers players\n(Win matches to level up & invite more members!)',
                            style: const TextStyle(fontSize: 11, color: Colors.white, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Select Game:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGame,
                    dropdownColor: AppColors.cardBg,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.cardBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Tic-Tac-Toe Duel',
                        child: Text('Tic-Tac-Toe Duel'),
                      ),
                      DropdownMenuItem(
                        value: 'Ludo Friends',
                        child: Text('Ludo Friends (Unlocked at Lvl 5 / 20 Wins)'),
                      ),
                      DropdownMenuItem(
                        value: 'Carrom Clash',
                        child: Text('Carrom Clash (Unlocked at Lvl 10 / 40 Wins)'),
                      ),
                      DropdownMenuItem(
                        value: 'Cyber Space Dodge',
                        child: Text('Cyber Space Dodge (Unlocked at Lvl 15 / 60 Wins)'),
                      ),
                      DropdownMenuItem(
                        value: 'Neon Arena Brawl',
                        child: Text('Neon Arena Brawl (Unlocked at Lvl 20 / 80 Wins)'),
                      ),
                      DropdownMenuItem(
                        value: 'Word Sprint Rush',
                        child: Text('Word Sprint Rush (Unlocked at Lvl 25 / 100 Wins)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedGame = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Max Players (Capacity limited by Level $userLevel):', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: availableCounts.map((count) {
                      final isSelected = maxPlayers == count;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text('$count Players'),
                        selectedColor: AppColors.primaryPurple,
                        backgroundColor: AppColors.cardBg,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => maxPlayers = count);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Private Room',
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Require 6-digit PIN to join',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isPrivate,
                        activeThumbColor: AppColors.primaryBlueLight,
                        onChanged: (val) {
                          setModalState(() => isPrivate = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        final randomCode = 'PF-${1000 + Random().nextInt(9000)}';
                        final newRoom = RoomModel(
                          id: 'r_${DateTime.now().millisecondsSinceEpoch}',
                          roomCode: randomCode,
                          gameTitle: selectedGame,
                          hostName: AuthService().currentUser?.name ?? 'Player 1',
                          currentPlayers: 1,
                          maxPlayers: maxPlayers,
                          isPrivate: isPrivate,
                          status: 'Waiting for players',
                        );
                        AuthService().addRoom(newRoom);
                        _refreshRooms();
                        _openRoomLobby(newRoom);
                      },
                      child: const Text('Create & Open Lobby'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleJoinWithCode() {
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.login_rounded, color: AppColors.primaryBlueLight),
            SizedBox(width: 10),
            Text('Join with Room Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the room PIN from your friend (e.g. PF-4912):',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'PF-XXXX',
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeCtrl.text.trim();
              Navigator.of(ctx).pop();
              if (code.isNotEmpty) {
                final match = _rooms.where((r) => r.roomCode.toLowerCase() == code.toLowerCase());
                if (match.isNotEmpty) {
                  _openRoomLobby(match.first);
                } else {
                  final newRoom = RoomModel(
                    id: 'r_${DateTime.now().millisecondsSinceEpoch}',
                    roomCode: code.toUpperCase(),
                    gameTitle: 'Tic-Tac-Toe Duel',
                    hostName: 'Game Friend',
                    currentPlayers: 1,
                    maxPlayers: 2,
                    isPrivate: false,
                    status: 'Joined lobby',
                  );
                  AuthService().addRoom(newRoom);
                  _refreshRooms();
                  _openRoomLobby(newRoom);
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _openRoomLobby(RoomModel room) {
    bool isReady = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLobbyState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          room.roomCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlueLight,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          room.gameTitle,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Players in Lobby:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  // Slot 1 (Host)
                  _buildLobbySlot(
                    name: room.hostName,
                    isHost: true,
                    isReady: true,
                    avatarColor: AppColors.primaryPurple,
                  ),
                  const SizedBox(height: 8),
                  // Slot 2
                  _buildLobbySlot(
                    name: AuthService().currentUser?.name ?? 'Player 2',
                    isHost: false,
                    isReady: isReady,
                    avatarColor: AppColors.primaryBlue,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isReady ? AppColors.onlineGreen : AppColors.cardBorder,
                            ),
                          ),
                          onPressed: () {
                            setLobbyState(() => isReady = !isReady);
                          },
                          child: Text(
                            isReady ? 'Ready ✓' : 'Set Ready',
                            style: TextStyle(
                              color: isReady ? AppColors.onlineGreen : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _startGameFromLobby(room);
                          },
                          child: const Text('Start Game'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _startGameFromLobby(RoomModel room) {
    String gameId = 'tic_tac_toe';
    if (room.gameTitle.contains('Ludo')) gameId = 'ludo';
    if (room.gameTitle.contains('Carrom')) gameId = 'carrom';
    if (room.gameTitle.contains('Space')) gameId = 'space_dodge';
    if (room.gameTitle.contains('Arena') || room.gameTitle.contains('Brawl')) gameId = 'arena_brawl';
    if (room.gameTitle.contains('Word') || room.gameTitle.contains('Sprint')) gameId = 'word_rush';

    if (!AuthService().isGameUnlocked(gameId)) {
      _showLockedGameDialog(context, room.gameTitle, gameId);
      return;
    }

    Widget screen;
    switch (gameId) {
      case 'ludo':
        screen = const LudoGameScreen();
        break;
      case 'carrom':
        screen = const CarromGameScreen();
        break;
      case 'space_dodge':
        screen = const SpaceDodgeScreen();
        break;
      case 'arena_brawl':
        screen = const NeonArenaBrawlScreen();
        break;
      case 'word_rush':
        screen = const WordRushScreen();
        break;
      default:
        screen = const TicTacToeScreen();
        break;
    }

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _showLockedGameDialog(BuildContext context, String gameTitle, String gameId) {
    final user = AuthService().currentUser;
    int reqLevel = 5;
    int reqWins = 20;
    if (gameId == 'carrom') {
      reqLevel = 10;
      reqWins = 40;
    } else if (gameId == 'space_dodge') {
      reqLevel = 15;
      reqWins = 60;
    } else if (gameId == 'arena_brawl') {
      reqLevel = 20;
      reqWins = 80;
    } else if (gameId == 'word_rush') {
      reqLevel = 25;
      reqWins = 100;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.coinAmber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$gameTitle Locked',
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock requirement: Level $reqLevel OR $reqWins Match Wins in Play Friends.\n\nCurrent Level: ${user?.level ?? 1} | Wins: ${user?.totalWins ?? 0}/$reqWins',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ((user?.totalWins ?? 0) / reqWins).clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceLight,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurpleLight),
                minHeight: 8,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TicTacToeScreen()),
              );
            },
            child: const Text('Play & Level Up'),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbySlot({
    required String name,
    required bool isHost,
    required bool isReady,
    required Color avatarColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: avatarColor,
            child: Text(
              name.isNotEmpty ? name[0] : 'P',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isHost) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.trophyGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'HOST',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.trophyGold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isReady
                  ? AppColors.onlineGreen.withValues(alpha: 0.2)
                  : AppColors.textMuted.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isReady ? 'READY' : 'WAITING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isReady ? AppColors.onlineGreen : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Rooms & Lobbies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.music_note_rounded, color: AppColors.accentCyan),
            tooltip: 'Music Store & Upload',
            onPressed: () => MusicPlayerSheet.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Create Room'),
                      onPressed: _handleCreateRoom,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Enter PIN'),
                      onPressed: _handleJoinWithCode,
                    ),
                  ),
                ],
              ),
            ),

            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Public Rooms (${_rooms.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Refresh Rooms',
                    onPressed: _refreshRooms,
                  ),
                ],
              ),
            ),

            // Rooms List or Empty State
            Expanded(
              child: _rooms.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.meeting_room_outlined,
                              size: 64,
                              color: AppColors.textMuted.withValues(alpha: 0.45),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Active Rooms Yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Create a custom game room or enter a PIN to invite your friends!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _handleCreateRoom,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Create First Room'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: _rooms.length,
                      itemBuilder: (context, index) {
                        final room = _rooms[index];
                        return RoomCard(
                          room: room,
                          onJoin: () => _openRoomLobby(room),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
