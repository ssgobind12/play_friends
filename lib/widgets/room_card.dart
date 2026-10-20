import 'package:flutter/material.dart';
import '../models/room_model.dart';
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1),
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
              if (room.isPrivate)
                const Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: AppColors.coinAmber,
                ),
              const Spacer(),
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
          Text(
            'Host: ${room.hostName}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
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
                '${room.currentPlayers}/${room.maxPlayers} Players',
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
                child: const Text('Join', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
