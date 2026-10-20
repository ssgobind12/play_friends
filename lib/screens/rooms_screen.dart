import 'dart:math';
import 'package:flutter/material.dart';
import '../data/sample_data.dart';
import '../models/room_model.dart';
import '../theme/app_theme.dart';
import '../widgets/demo_banner.dart';
import '../widgets/room_card.dart';
import 'tic_tac_toe_screen.dart';

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
    _rooms = List.from(SampleData.rooms);
  }

  void _handleCreateRoom() {
    String selectedGame = 'Tic-Tac-Toe Duel';
    int maxPlayers = 2;
    bool isPrivate = false;

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
                  const SizedBox(height: 18),
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
                        child: Text('Tic-Tac-Toe Duel (Playable)'),
                      ),
                      DropdownMenuItem(
                        value: 'Ludo Friends',
                        child: Text('Ludo Friends (Demo Preview)'),
                      ),
                      DropdownMenuItem(
                        value: 'Carrom Clash',
                        child: Text('Carrom Clash (Demo Preview)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedGame = val;
                          if (val.contains('Tic-Tac-Toe') || val.contains('Carrom')) {
                            maxPlayers = 2;
                          } else {
                            maxPlayers = 4;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Max Players:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [2, 4, 6].map((count) {
                      final isSelected = maxPlayers == count;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ChoiceChip(
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
                        ),
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
                          hostName: SampleData.currentUserName,
                          currentPlayers: 1,
                          maxPlayers: maxPlayers,
                          isPrivate: isPrivate,
                          status: 'Waiting for players',
                        );
                        setState(() {
                          _rooms.insert(0, newRoom);
                        });
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
              'Enter the 6-character room PIN from your friend (e.g. PF-4912):',
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
                  final simulatedRoom = RoomModel(
                    id: 'r_sim',
                    roomCode: code.toUpperCase(),
                    gameTitle: 'Tic-Tac-Toe Duel',
                    hostName: 'Sarah Connor',
                    currentPlayers: 1,
                    maxPlayers: 2,
                    isPrivate: false,
                    status: 'Joined lobby',
                  );
                  _openRoomLobby(simulatedRoom);
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
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlueLight,
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
                  const SizedBox(height: 12),
                  const DemoBanner(
                    message: 'Simulated Lobby: Ready state and player slots reflect local preview.',
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
                  // Slot 2 (You or other)
                  _buildLobbySlot(
                    name: SampleData.currentUserName,
                    isHost: false,
                    isReady: isReady,
                    avatarColor: AppColors.primaryBlue,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setLobbyState(() => isReady = !isReady);
                          },
                          child: Text(isReady ? 'Unready' : 'I am Ready!'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            if (room.gameTitle.contains('Tic-Tac-Toe')) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TicTacToeScreen(),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${room.gameTitle} server is in preview mode. Launching Tic-Tac-Toe test duel instead.',
                                  ),
                                ),
                              );
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TicTacToeScreen(),
                                ),
                              );
                            }
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            const DemoBanner(
              message: 'Rooms & Lobbies are simulated local lobbies. You can create rooms, enter room PINs, and start matches.',
            ),

            // Top action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

            const SizedBox(height: 10),

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
                    onPressed: () {
                      setState(() {
                        _rooms = List.from(SampleData.rooms);
                      });
                    },
                  ),
                ],
              ),
            ),

            // Rooms List
            Expanded(
              child: ListView.builder(
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
