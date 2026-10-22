import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/room_model.dart';
import '../services/auth_service.dart';
import '../services/backend_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/room_card.dart';
import '../widgets/music_player_sheet.dart';
import 'voice_party_room_screen.dart';

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
    AuthService().fetchRooms().then((_) {
      if (mounted) {
        setState(() {
          _rooms = List.from(AuthService().activeRooms);
        });
      }
    });
  }

  Future<void> _refreshRooms() async {
    await AuthService().fetchRooms();
    if (mounted) {
      setState(() {
        _rooms = List.from(AuthService().activeRooms);
      });
    }
  }

  void _handleCreateRoom() {
    final currentUserName = AuthService().currentUser?.name ?? 'Player';
    final userLevel = AuthService().currentUser?.level ?? 1;
    // Room capacity scales by player level (> 100 persons):
    // Level 1: up to 100 persons
    // Level 5: up to 150 persons
    // Level 10: up to 250 persons
    // Level 20: up to 500 persons
    // Level 50+: up to 1,000 persons!
    int maxAllowedMembers = 100;
    if (userLevel >= 50) {
      maxAllowedMembers = 1000;
    } else if (userLevel >= 20) {
      maxAllowedMembers = 500;
    } else if (userLevel >= 10) {
      maxAllowedMembers = 250;
    } else if (userLevel >= 5) {
      maxAllowedMembers = 150;
    } else {
      maxAllowedMembers = 100;
    }

    final defaultBase = currentUserName.length > 9
        ? currentUserName.substring(0, 9)
        : currentUserName;
    final initialRoomName = "$defaultBase's Room";
    final roomNameCtrl = TextEditingController(text: initialRoomName);
    String selectedGame = 'All-in-One Multi-Game Party';
    int maxPlayers = min(100, maxAllowedMembers);
    bool isPrivate = false;

    // Available member options based on host level
    final availableCounts = <int>[];
    for (final c in [10, 25, 50, 100, 150, 250, 500, 1000]) {
      if (c <= maxAllowedMembers) {
        availableCounts.add(c);
      }
    }
    if (availableCounts.isEmpty) availableCounts.add(100);

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
                      Icon(Icons.add_box_rounded,
                          color: AppColors.primaryBlueLight),
                      SizedBox(width: 10),
                      Text(
                        'Create Custom Voice Room',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppColors.primaryPurple.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.military_tech_rounded,
                            color: AppColors.coinAmber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your Level: $userLevel • Room capacity: Max $maxAllowedMembers persons\n(Level 1 = 100, Lvl 5 = 150, Lvl 10 = 250, Lvl 20 = 500, Lvl 50 = 1,000+!)',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Custom Room Name:',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: roomNameCtrl,
                    maxLength: 16,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(16),
                    ],
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter room name (max 16 chars)',
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.cardBg,
                      prefixIcon: const Icon(Icons.meeting_room_rounded,
                          color: AppColors.accentCyan),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Featured Game (You can play ANY game inside!):',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGame,
                    dropdownColor: AppColors.cardBg,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.cardBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'All-in-One Multi-Game Party',
                        child: Text('All-in-One Multi-Game Party 🎮'),
                      ),
                      DropdownMenuItem(
                        value: 'Tic-Tac-Toe Duel',
                        child: Text('Tic-Tac-Toe Duel'),
                      ),
                      DropdownMenuItem(
                        value: 'Ludo Friends',
                        child:
                            Text('Ludo Friends (Unlocked at Lvl 5 / 20 Wins)'),
                      ),
                      DropdownMenuItem(
                        value: 'Carrom Clash',
                        child:
                            Text('Carrom Clash (Unlocked at Lvl 10 / 40 Wins)'),
                      ),
                      DropdownMenuItem(
                        value: 'Cyber Space Dodge',
                        child: Text(
                            'Cyber Space Dodge (Unlocked at Lvl 15 / 60 Wins)'),
                      ),
                      DropdownMenuItem(
                        value: 'Neon Arena Brawl',
                        child: Text(
                            'Neon Arena Brawl (Unlocked at Lvl 20 / 80 Wins)'),
                      ),
                      DropdownMenuItem(
                        value: 'Word Sprint Rush',
                        child: Text(
                            'Word Sprint Rush (Unlocked at Lvl 25 / 100 Wins)'),
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
                  Text('Max Players (Capacity limited by Level $userLevel):',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
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
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
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
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Require 6-digit PIN to join',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
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
                        final randomCode =
                            'PF-${1000 + Random().nextInt(9000)}';
                        final rawTitle = roomNameCtrl.text.trim().isNotEmpty
                            ? roomNameCtrl.text.trim()
                            : initialRoomName;
                        final roomTitle = rawTitle.length > 16
                            ? rawTitle.substring(0, 16)
                            : rawTitle;

                        final newRoom = RoomModel(
                          id: 'r_${DateTime.now().millisecondsSinceEpoch}',
                          roomCode: randomCode,
                          gameTitle: roomTitle,
                          hostName:
                              AuthService().currentUser?.name ?? 'Player 1',
                          hostPhoto: AuthService().currentUser?.profilePhoto,
                          currentPlayers: 1,
                          maxPlayers: maxPlayers,
                          isPrivate: isPrivate,
                          status: 'Live Voice Party',
                        );
                        AuthService().addRoom(newRoom);
                        _refreshRooms();
                        _openRoomLobby(newRoom);
                      },
                      child: const Text('Create & Enter Voice Party Room'),
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                final match = _rooms.where(
                    (r) => r.roomCode.toLowerCase() == code.toLowerCase());
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VoicePartyRoomScreen(room: room),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final displayRooms = AuthService()
            .activeRooms
            .where((r) => !BackendApiService.isDemoRoom(r))
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Game Rooms & Lobbies'),
            actions: [
              IconButton(
                icon: const Icon(Icons.music_note_rounded,
                    color: AppColors.accentCyan),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Public Rooms (${displayRooms.length})',
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
                  child: displayRooms.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.meeting_room_outlined,
                                  size: 64,
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.45),
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
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          itemCount: displayRooms.length,
                          itemBuilder: (context, index) {
                            final room = displayRooms[index];
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
      },
    );
  }
}
