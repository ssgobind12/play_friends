import 'package:flutter/material.dart';
import '../data/sample_data.dart';
import '../models/game_model.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/demo_banner.dart';
import '../widgets/game_card.dart';
import 'tic_tac_toe_screen.dart';

class HomeScreen extends StatelessWidget {
  final Function(int) onNavigateTab;
  final VoidCallback onOpenRooms;
  final VoidCallback onOpenChat;

  const HomeScreen({
    super.key,
    required this.onNavigateTab,
    required this.onOpenRooms,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final playableGame = SampleData.games.firstWhere((g) => g.id == 'tic_tac_toe');
    final otherFeatured = SampleData.games.where((g) => g.id != 'tic_tac_toe').take(2).toList();
    final onlineFriends = SampleData.friends.where((f) => f.isOnline).toList();
    final user = AuthService().currentUser;
    final userName = user?.name.split(' ').first ?? 'Alex';
    final userInitial = user?.avatarInitial ?? 'A';
    final userColor = user?.avatarColor ?? AppColors.primaryPurple;
    final userLevel = user?.level ?? 14;
    final userCoins = user?.coins ?? 1450;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with User Info & Currency
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Avatar & Level
                    GestureDetector(
                      onTap: () => onNavigateTab(3), // Navigate to Profile tab
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: userColor,
                            child: Text(
                              userInitial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppColors.trophyGold,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                size: 10,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hey $userName!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Level $userLevel • ${user?.isGuest == true ? "Guest Gamer" : "Arena Player"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Demo Coins Balance
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.coinAmber.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monetization_on_rounded,
                            size: 16,
                            color: AppColors.coinAmber,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$userCoins',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.coinAmber,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chat shortcut
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      color: AppColors.primaryPurpleLight,
                      tooltip: 'Social Chat',
                      onPressed: onOpenChat,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              const DemoBanner(
                message: 'Play Friends Demo: All online connectivity is simulated. Local Tic-Tac-Toe is 100% playable.',
              ),

              const SizedBox(height: 16),

              // Highlighted Quick Match Banner (Playable Tic-Tac-Toe)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF281858), Color(0xFF10365C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primaryBlueLight.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlueLight.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 14,
                                  color: AppColors.primaryBlueLight,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'READY TO PLAY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryBlueLight,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Offline Match',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tic-Tac-Toe Duel',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Play locally with a friend via Pass & Play, or challenge our smart AI bot!',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                        label: const Text('Play Duel Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TicTacToeScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Quick Actions: Create & Join Rooms
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.add_circle_outline_rounded,
                        title: 'Create Room',
                        subtitle: 'Host custom match',
                        color: AppColors.primaryPurpleLight,
                        onTap: onOpenRooms,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.login_rounded,
                        title: 'Join Room',
                        subtitle: 'Enter 6-digit code',
                        color: AppColors.primaryBlueLight,
                        onTap: onOpenRooms,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Online Friends Reel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Online Friends',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => onNavigateTab(2), // Friends Tab
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 98,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: onlineFriends.length,
                  itemBuilder: (context, index) {
                    final friend = onlineFriends[index];
                    return GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Invited ${friend.name} to play! (Simulated)'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        width: 78,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: friend.avatarColor,
                                  child: Text(
                                    friend.initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
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
                                      color: AppColors.onlineGreen,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.background,
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              friend.name.split(' ').first,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'LVL ${friend.level}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.trophyGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Featured Games List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Featured Games',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => onNavigateTab(1), // Games Tab
                      child: const Text('All Games'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Playable Tic-Tac-Toe
                    GameCard(
                      game: playableGame,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TicTacToeScreen(),
                          ),
                        );
                      },
                    ),
                    // Other featured games
                    ...otherFeatured.map(
                      (g) => GameCard(
                        game: g,
                        onTap: () => _showGamePreviewModal(context, g),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
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
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGamePreviewModal(BuildContext context, GameModel game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(game.icon, color: game.primaryColor),
            const SizedBox(width: 10),
            Expanded(child: Text(game.title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'DEMO PREVIEW ONLY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPurpleLight,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(game.description),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.people_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('Players: ${game.playerCount}',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Online multiplayer server is not connected in this offline version. Try our fully playable Tic-Tac-Toe duel!',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TicTacToeScreen(),
                ),
              );
            },
            child: const Text('Play Tic-Tac-Toe Instead'),
          ),
        ],
      ),
    );
  }
}
