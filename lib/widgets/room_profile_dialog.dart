import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/room_model.dart';
import '../services/voice_room_manager.dart';
import '../theme/app_theme.dart';
import 'user_profile_dialog.dart';

class RoomProfileDialog extends StatelessWidget {
  final RoomModel room;

  const RoomProfileDialog({
    super.key,
    required this.room,
  });

  static Future<void> show(
    BuildContext context, {
    required RoomModel room,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => RoomProfileDialog(room: room),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VoiceRoomManager(),
      builder: (context, _) {
        final vm = VoiceRoomManager();
        final isFollowed = vm.isFollowingRoom(room.roomCode);
        final followersCount = vm.getRoomFollowers(room.roomCode);
        final roomLevel =
            LevelProgressionService.calculateLevel(room.giftPoints);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 390),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isFollowed
                    ? AppColors.trophyGold.withValues(alpha: 0.6)
                    : AppColors.primaryPurple.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isFollowed
                          ? AppColors.trophyGold
                          : AppColors.primaryPurple)
                      .withValues(alpha: 0.25),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Level Pill & Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.accentCyan.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded,
                              size: 14, color: AppColors.accentCyan),
                          const SizedBox(width: 4),
                          Text(
                            'Room Lv.$roomLevel',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white60, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Room Icon Header
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryPurple, AppColors.accentCyan],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withValues(alpha: 0.5),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.radio_rounded,
                    size: 38,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 14),

                // Room Title
                Text(
                  room.gameTitle,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Room ID with Tap-to-Copy Pill
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: room.roomCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Room ID copied: ${room.roomCode}! 📋'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primaryBlueLight
                              .withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Room ID: ${room.roomCode}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlueLight,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy_rounded,
                            size: 13, color: AppColors.primaryBlueLight),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Stats Grid: Followers, Level, Charm
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetric(
                        'Followers',
                        '$followersCount ⭐',
                        AppColors.trophyGold,
                      ),
                      Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.15)),
                      _buildMetric(
                        'Room Level',
                        'Lv.$roomLevel',
                        AppColors.accentCyan,
                      ),
                      Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.15)),
                      _buildMetric(
                        'Charm',
                        '${room.giftPoints}',
                        AppColors.coinAmber,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Host Info Card (Tap to view host user profile)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.of(context).pop();
                    UserProfileDialog.show(
                      context,
                      name: room.hostName,
                      profilePhoto: room.hostPhoto,
                      level: 25,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryPurple,
                          backgroundImage: room.hostPhoto != null
                              ? NetworkImage(room.hostPhoto!)
                              : null,
                          child: room.hostPhoto == null
                              ? Text(
                                  room.hostName.isNotEmpty
                                      ? room.hostName[0]
                                      : 'H',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 13),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Host: ${room.hostName}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Tap to inspect host profile',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.white54, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Action Buttons: Follow Room & Close
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowed
                              ? AppColors.surfaceLight
                              : AppColors.trophyGold,
                          foregroundColor:
                              isFollowed ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: isFollowed
                                ? const BorderSide(
                                    color: AppColors.trophyGold, width: 1)
                                : BorderSide.none,
                          ),
                        ),
                        onPressed: () {
                          vm.toggleFollowRoom(room.roomCode);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isFollowed
                                  ? 'Unfollowed ${room.roomCode}'
                                  : 'Following room ${room.roomCode}! Added to Favorites ⭐'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: Icon(
                          isFollowed
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 18,
                        ),
                        label: Text(
                          isFollowed ? 'Following Room ⭐' : 'Follow Room',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
