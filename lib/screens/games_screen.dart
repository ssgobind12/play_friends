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

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Board Games',
    'Action Games',
    'Casual',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GameModel> get _filteredGames {
    return SampleData.games.where((game) {
      final matchesSearch = game.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          game.description.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_selectedCategory == 'Board Games') {
        return game.category == GameCategory.board;
      } else if (_selectedCategory == 'Action Games') {
        return game.category == GameCategory.action;
      } else if (_selectedCategory == 'Casual') {
        return game.category == GameCategory.casual;
      }
      return true;
    }).toList();
  }

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final games = _filteredGames;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Game Arcade'),
            actions: [
              IconButton(
                icon: const Icon(Icons.music_note_rounded, color: AppColors.accentCyan),
                tooltip: 'Game Music Store',
                onPressed: () => MusicPlayerSheet.show(context),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search games (e.g. Ludo, Carrom, Space)...',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.cardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
                      ),
                    ),
                  ),
                ),

                // Category Filter Chips
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          },
                          backgroundColor: AppColors.cardBg,
                          selectedColor: AppColors.primaryPurple,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isSelected ? AppColors.primaryPurple : AppColors.cardBorder,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Games List
                Expanded(
                  child: games.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.sports_esports_outlined,
                                size: 48,
                                color: AppColors.textMuted.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No games found matching your search',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: games.length,
                          itemBuilder: (context, index) {
                            final game = games[index];
                            return GameCard(
                              game: game,
                              onTap: () => _launchGame(context, game),
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
