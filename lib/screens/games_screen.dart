import 'package:flutter/material.dart';
import '../data/sample_data.dart';
import '../models/game_model.dart';
import '../theme/app_theme.dart';
import '../widgets/demo_banner.dart';
import '../widgets/game_card.dart';
import 'tic_tac_toe_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final games = _filteredGames;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Arcade'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Game Engine Info',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('About Games'),
                  content: const Text(
                    'Play Friends includes a fully functional, playable local Tic-Tac-Toe engine (with AI & Pass-and-Play modes). Other titles (Ludo, Carrom, Action) are demo showcase previews for future multiplayer integrations.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const DemoBanner(
              message: 'Tic-Tac-Toe is playable right now! Other titles are shown as demo concept previews.',
            ),

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
                  hintText: 'Search games (e.g. Ludo, Tic-Tac-Toe)...',
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
                      selected: isSelected,
                      label: Text(cat),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                      backgroundColor: AppColors.cardBg,
                      selectedColor: AppColors.primaryPurple,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.primaryPurple : AppColors.cardBorder,
                        ),
                      ),
                      onSelected: (bool selected) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
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
                          onTap: () {
                            if (game.isPlayable) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TicTacToeScreen(),
                                ),
                              );
                            } else {
                              _showDemoDialog(context, game);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDemoDialog(BuildContext context, GameModel game) {
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                game.statusBadge,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPurpleLight,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(game.description),
            const SizedBox(height: 12),
            Text(
              'Supported: ${game.playerCount}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'This game requires online multiplayer servers which are not active in this demo version. You can play Tic-Tac-Toe locally right now!',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
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
            child: const Text('Launch Tic-Tac-Toe'),
          ),
        ],
      ),
    );
  }
}
