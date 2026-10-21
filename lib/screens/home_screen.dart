import 'package:flutter/material.dart';
import '../data/sample_data.dart';
import '../models/game_model.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_card.dart';
import 'tic_tac_toe_screen.dart';
import 'ludo_game_screen.dart';
import 'carrom_game_screen.dart';
import 'space_dodge_screen.dart';
import 'neon_arena_brawl_screen.dart';
import 'word_rush_screen.dart';
import '../widgets/music_player_sheet.dart';

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

  void _launchGame(BuildContext context, GameModel game) {
    final auth = AuthService();
    final isUnlocked = auth.isGameUnlocked(game.id);

    if (isUnlocked) {
      Widget screen;
      switch (game.id) {
        case 'ludo':
          screen = const LudoGameScreen();
          break;
        case 'carrom':
          screen = const CarromGameScreen();
          break;
        case 'space_dodge':
          screen = const SpaceDodgeGameScreen();
          break;
        case 'arena_brawl':
          screen = const NeonArenaBrawlScreen();
          break;
        case 'word_rush':
          screen = const WordRushScreen();
          break;
        case 'tic_tac_toe':
        default:
          screen = const TicTacToeScreen();
          break;
      }
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    } else {
      final user = auth.currentUser;
      final wins = user?.totalWins ?? 0;
      final level = user?.level ?? 1;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, color: AppColors.coinAmber, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${game.title} Locked',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unlocks automatically when you reach Level ${game.requiredLevel} or win ${game.requiredWins} games!',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Win Progress', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text('$wins / ${game.requiredWins} Wins', style: const TextStyle(color: AppColors.coinAmber, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (wins / (game.requiredWins > 0 ? game.requiredWins : 1)).clamp(0.0, 1.0),
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.coinAmber),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 10),
                    Text('Player Level: $level (Required: Level ${game.requiredLevel})', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TicTacToeScreen()));
              },
              child: const Text('Play & Level Up', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _showAddFriendModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final tagCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryBlueLight),
            SizedBox(width: 10),
            Text('Add New Friend', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Friend Name',
                hintText: 'e.g. John Doe',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tagCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Gamer Tag',
                hintText: 'e.g. @john_duel',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                AuthService().addFriend(
                  name: nameCtrl.text.trim(),
                  tag: tagCtrl.text.trim().isNotEmpty ? tagCtrl.text.trim() : '@${nameCtrl.text.trim().toLowerCase()}',
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added ${nameCtrl.text.trim()} to your Squad!'),
                    backgroundColor: AppColors.onlineGreen,
                  ),
                );
              }
            },
            child: const Text('Add Friend', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final auth = AuthService();
        final user = auth.currentUser;
        final userName = user?.name.split(' ').first ?? 'Player';
        final userInitial = user?.avatarInitial ?? 'P';
        final userColor = user?.avatarColor ?? AppColors.primaryPurple;
        final userLevel = user?.level ?? 1;
        final userCoins = user?.coins ?? 500;
        final friends = auth.friends;
        final playableGame = SampleData.games.firstWhere((g) => g.id == 'tic_tac_toe');
        final otherFeatured = SampleData.games.where((g) => g.id != 'tic_tac_toe').take(2).toList();

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
                          onTap: () => onNavigateTab(3),
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
                                'Level $userLevel • ${user?.totalWins ?? 0} Wins',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Coins Balance
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
                        IconButton(
                          icon: const Icon(Icons.music_note_rounded),
                          color: AppColors.primaryBlueLight,
                          tooltip: 'In-App Music',
                          onPressed: () => MusicPlayerSheet.show(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          color: AppColors.primaryPurpleLight,
                          tooltip: 'Social Chat',
                          onPressed: onOpenChat,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Highlighted Quick Match Banner (Tic-Tac-Toe Duel)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF1E1B4B),
                            Color(0xFF0F172A),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.bolt_rounded, size: 14, color: AppColors.primaryBlueLight),
                                    SizedBox(width: 4),
                                    Text(
                                      'READY TO PLAY',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryBlueLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Wins: ${user?.totalWins ?? 0}/20 (Unlock Ludo)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.coinAmber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tic-Tac-Toe Duel',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
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
                            onPressed: () => _launchGame(context, playableGame),
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

                  // Friends Section
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
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Friend'),
                          onPressed: () => _showAddFriendModal(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (friends.isEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryPurple.withValues(alpha: 0.2),
                            ),
                            child: const Icon(Icons.person_add_rounded, color: AppColors.primaryPurpleLight),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Squad is empty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Add friends to challenge them to matches!', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _showAddFriendModal(context),
                            child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 98,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          return Container(
                            width: 78,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
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
                                const SizedBox(height: 6),
                                Text(
                                  friend.name,
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
                          onPressed: () => onNavigateTab(1),
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
                        GameCard(
                          game: playableGame,
                          onTap: () => _launchGame(context, playableGame),
                        ),
                        ...otherFeatured.map(
                          (g) => GameCard(
                            game: g,
                            onTap: () => _launchGame(context, g),
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
      },
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
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
