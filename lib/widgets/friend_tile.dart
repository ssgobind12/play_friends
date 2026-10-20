import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../theme/app_theme.dart';

class FriendTile extends StatelessWidget {
  final FriendModel friend;
  final VoidCallback onInvite;
  final VoidCallback onChat;
  final VoidCallback onTap;

  const FriendTile({
    super.key,
    required this.friend,
    required this.onInvite,
    required this.onChat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar with online status badge
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: friend.avatarColor,
                      child: Text(
                        friend.initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: friend.isOnline
                              ? AppColors.onlineGreen
                              : AppColors.textMuted,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.cardBg,
                            width: 2.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // Friend Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              friend.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LVL ${friend.level}',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.trophyGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        friend.statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: friend.isOnline
                              ? AppColors.primaryBlueLight
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                      color: AppColors.primaryPurpleLight,
                      tooltip: 'Chat',
                      onPressed: onChat,
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, size: 20),
                      color: friend.isOnline
                          ? AppColors.primaryBlueLight
                          : AppColors.textMuted,
                      tooltip: 'Invite',
                      onPressed: onInvite,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
