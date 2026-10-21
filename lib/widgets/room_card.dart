import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../services/voice_room_manager.dart';
import '../theme/app_theme.dart';

class RoomCard extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onJoin;

  const RoomCard({
    super.key,
    required this.room,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final double fillPercentage = room.currentPlayers / room.maxPlayers;
    final bool isFull = room.currentPlayers >= room.maxPlayers;
    final roomLevel = LevelProgressionService.calculateLevel(room.giftPoints);

    return ListenableBuilder(
      listenable: VoiceRoomManager(),
      builder: (context, _) {
        final isFollowed = VoiceRoomManager().isFollowingRoom(room.roomCode);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isFollowed ? AppColors.accentCyan.withValues(alpha: 0.6) : AppColors.cardBorder,
              width: isFollowed ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryPurple.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      room.roomCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.primaryBlueLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Room Level Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Lv.$roomLevel',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accentCyan),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (room.isPrivate)
                    const Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: AppColors.coinAmber,
                    ),
                  const Spacer(),
                  // Follow Room Star Icon Button
                  GestureDetector(
                    onTap: () {
                      VoiceRoomManager().toggleFollowRoom(room.roomCode);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isFollowed ? 'Unfollowed ${room.roomCode}' : 'Following ${room.roomCode}! ⭐'),
                          duration: const Duration(milliseconds: 900),
                        ),
                      );
                    },
                    child: Icon(
                      isFollowed ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isFollowed ? AppColors.trophyGold : Colors.white54,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isFull
                          ? AppColors.dangerRose.withValues(alpha: 0.15)
                          : AppColors.onlineGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      room.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isFull ? AppColors.dangerRose : AppColors.onlineGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                room.gameTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Host: ${room.hostName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.emoji_events_rounded, size: 12, color: AppColors.coinAmber),
                  const SizedBox(width: 3),
                  Text(
                    '${room.giftPoints} Charm',
                    style: const TextStyle(fontSize: 11, color: AppColors.coinAmber, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Player count progress bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fillPercentage,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFull ? AppColors.dangerRose : AppColors.primaryPurple,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${room.currentPlayers}/${room.maxPlayers} Members',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton(
                    onPressed: isFull ? null : onJoin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: const Size(60, 34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Enter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
