import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../screens/chat_screen.dart';
import '../services/auth_service.dart';
import '../services/voice_room_manager.dart';
import '../theme/app_theme.dart';

class UserProfileDialog extends StatelessWidget {
  final String name;
  final String tag;
  final String? profilePhoto;
  final String? securityId;
  final Color avatarColor;
  final int level;
  final int xp;
  final bool isOnline;

  const UserProfileDialog({
    super.key,
    required this.name,
    required this.tag,
    this.profilePhoto,
    this.securityId,
    required this.avatarColor,
    this.level = 1,
    this.xp = 0,
    this.isOnline = true,
  });

  static Future<void> show(
    BuildContext context, {
    required String name,
    String? tag,
    String? profilePhoto,
    String? securityId,
    Color? avatarColor,
    int? level,
    int? xp,
    bool? isOnline,
  }) async {
    final cleanTag = (tag != null && tag.isNotEmpty)
        ? (tag.startsWith('@') ? tag : '@$tag')
        : AuthService().generateUniqueTagFromEmail('$name@playfriends.io');

    await showDialog(
      context: context,
      builder: (_) => UserProfileDialog(
        name: name,
        tag: cleanTag,
        profilePhoto: profilePhoto,
        securityId: securityId,
        avatarColor: avatarColor ?? AppColors.primaryPurple,
        level: level ?? 1,
        xp: xp ?? 0,
        isOnline: isOnline ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VoiceRoomManager(),
      builder: (context, _) {
        final vm = VoiceRoomManager();
        final isFollowing = vm.isFollowingUser(name);
        final isFollower = vm.isFollowedByUser(name);
        final isMutual = vm.isMutualFollow(name);

        final followersCount = vm.getUserFollowers(name);
        final followingCount = vm.getUserFollowing(name);
        final visitorsCount = vm.getUserVisitors(name);

        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
        final hasPhoto = profilePhoto != null && profilePhoto!.isNotEmpty;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isMutual
                    ? AppColors.onlineGreen.withValues(alpha: 0.6)
                    : AppColors.primaryPurple.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isMutual
                          ? AppColors.onlineGreen
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
                // Top Row: Status Tag & Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMutual
                            ? AppColors.onlineGreen.withValues(alpha: 0.2)
                            : isFollower
                                ? AppColors.accentCyan.withValues(alpha: 0.2)
                                : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isMutual
                              ? AppColors.onlineGreen
                              : isFollower
                                  ? AppColors.accentCyan
                                  : Colors.white24,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isMutual
                                ? Icons.verified_rounded
                                : Icons.people_alt_rounded,
                            size: 13,
                            color: isMutual
                                ? AppColors.onlineGreen
                                : isFollower
                                    ? AppColors.accentCyan
                                    : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isMutual
                                ? 'Mutual Followers ⭐'
                                : isFollower
                                    ? 'Follows You'
                                    : 'Player Profile',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isMutual
                                  ? AppColors.onlineGreen
                                  : isFollower
                                      ? AppColors.accentCyan
                                      : Colors.white70,
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

                const SizedBox(height: 14),

                // Avatar Photo or Colored Circle
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isMutual
                              ? AppColors.onlineGreen
                              : AppColors.primaryPurpleLight,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: avatarColor.withValues(alpha: 0.5),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: hasPhoto
                            ? Image.network(
                                profilePhoto!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildFallback(initial, avatarColor, 34),
                              )
                            : _buildFallback(initial, avatarColor, 34),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.trophyGold,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF0F172A), width: 1.5),
                        ),
                        child: Text(
                          'Lv.$level',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Display Name
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Gamer Tag
                Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlueLight,
                  ),
                ),

                const SizedBox(height: 6),

                // Security ID Chip
                Builder(builder: (_) {
                  final displayId = (securityId != null && securityId!.isNotEmpty)
                      ? securityId!
                      : (AuthService()
                              .registeredUsers
                              .where((u) => u.name == name || u.tag == tag)
                              .map((u) => u.id)
                              .firstOrNull ??
                          '01----');

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.security_rounded,
                            size: 11, color: AppColors.accentCyan),
                        const SizedBox(width: 5),
                        Text(
                          'Security ID: $displayId',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentCyan,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 18),

                // Stats Row: Followers, Following, Visitors
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
                      _buildStatColumn(
                          'Followers', '$followersCount', AppColors.accentCyan),
                      Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.15)),
                      _buildStatColumn('Following', '$followingCount',
                          AppColors.primaryPurpleLight),
                      Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.15)),
                      _buildStatColumn(
                          'Visitors', '$visitorsCount', AppColors.coinAmber),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Action Buttons Row: Follow, Direct Chat, Gift
                Row(
                  children: [
                    // 1. Follow / Following Button
                    Expanded(
                      flex: 5,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? AppColors.surfaceLight
                              : AppColors.primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: isFollowing
                                ? const BorderSide(
                                    color: AppColors.cardBorder, width: 1)
                                : BorderSide.none,
                          ),
                          elevation: isFollowing ? 0 : 4,
                        ),
                        onPressed: () {
                          vm.toggleFollowUser(
                            name,
                            tag: tag,
                            profilePhoto: profilePhoto,
                            avatarColor: avatarColor,
                            level: level,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isFollowing
                                  ? 'Unfollowed $name'
                                  : 'Following $name! ⭐ Added to your Online Friends!'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: Icon(
                          isFollowing
                              ? Icons.check_rounded
                              : Icons.person_add_rounded,
                          size: 18,
                          color: isFollowing
                              ? AppColors.onlineGreen
                              : Colors.white,
                        ),
                        label: Text(
                          isFollowing ? 'Following' : '+ Follow',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // 2. Direct Chat Button (Unlocked when Mutual Follow!)
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMutual
                              ? AppColors.primaryBlue
                              : AppColors.surfaceLight,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isMutual
                                  ? AppColors.primaryBlueLight
                                  : AppColors.cardBorder,
                              width: 1,
                            ),
                          ),
                          elevation: isMutual ? 4 : 0,
                        ),
                        onPressed: () {
                          if (!isMutual) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isFollowing
                                      ? '🔒 Direct chat is waiting for $name to follow back!'
                                      : '🔒 Direct chat requires mutual following! Tap "+ Follow" first.',
                                ),
                                backgroundColor: AppColors.surfaceLight,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          // Mutual follow: Open direct chat screen!
                          Navigator.of(context).pop();
                          final thread = ChatThread(
                            id: 'dm_$name',
                            title: name,
                            subtitle: 'Say hello to $name!',
                            time: 'Online',
                            unreadCount: 0,
                            isGroup: false,
                            iconColor: avatarColor,
                            messages: [
                              ChatMessage(
                                id: 'm1',
                                senderName: name,
                                senderInitial: initial,
                                senderColor: avatarColor,
                                message:
                                    'Hey! We are now mutual friends on Play Friends! 🎮',
                                time: 'Just now',
                                isMe: false,
                              ),
                            ],
                          );
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChatConversationScreen(thread: thread),
                            ),
                          );
                        },
                        icon: Icon(
                          isMutual
                              ? Icons.chat_rounded
                              : Icons.lock_outline_rounded,
                          size: 16,
                          color: isMutual ? Colors.white : AppColors.coinAmber,
                        ),
                        label: Text(
                          isMutual ? 'Chat' : 'Chat 🔒',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // 3. Send Gift Button
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppColors.coinAmber.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(
                              color: AppColors.coinAmber, width: 1),
                        ),
                      ),
                      icon: const Icon(Icons.card_giftcard_rounded,
                          color: AppColors.coinAmber, size: 20),
                      tooltip: 'Send Charm Gift',
                      onPressed: () => _showGiftPicker(context),
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

  Widget _buildFallback(String initial, Color color, double fontSize) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
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

  void _showGiftPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B4B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.volunteer_activism_rounded,
                    color: AppColors.coinAmber, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Send Gift to $name',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Gifts increase player charm & upgrade level progression!',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildGiftItem(ctx, context, '🌹', 'Lucky Rose', 50),
                _buildGiftItem(ctx, context, '👑', 'Crown', 200),
                _buildGiftItem(ctx, context, '🚀', 'Rocket', 500),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftItem(BuildContext sheetCtx, BuildContext parentCtx,
      String emoji, String title, int cost) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(sheetCtx).pop();
        final success = AuthService().spendCoins(cost);
        if (success) {
          AuthService().promoteLevelFromCoins(cost ~/ 2, 2);
          ScaffoldMessenger.of(parentCtx).showSnackBar(
            SnackBar(
              content: Text('Sent $emoji $title to $name! (Spent $cost Coins)'),
              backgroundColor: AppColors.surfaceLight,
            ),
          );
        } else {
          ScaffoldMessenger.of(parentCtx).showSnackBar(
            const SnackBar(
              content: Text('Not enough coins! Play games to win more coins.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text('$cost 🪙',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.coinAmber,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
