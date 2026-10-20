import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../theme/app_theme.dart';

class GameCard extends StatelessWidget {
  final GameModel game;
  final VoidCallback onTap;

  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: game.isPlayable
              ? AppColors.primaryBlue.withValues(alpha: 0.5)
              : AppColors.cardBorder,
          width: game.isPlayable ? 1.5 : 1,
        ),
        boxShadow: [
          if (game.isPlayable)
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Artwork / Icon container with gradient
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [game.primaryColor, game.secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: game.primaryColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    game.icon,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                // Game Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              game.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: game.isPlayable
                                  ? AppColors.primaryBlue.withValues(alpha: 0.2)
                                  : AppColors.primaryPurple.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: game.isPlayable
                                    ? AppColors.primaryBlue
                                    : AppColors.primaryPurple.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              game.statusBadge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: game.isPlayable
                                    ? AppColors.primaryBlueLight
                                    : AppColors.primaryPurpleLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        game.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.people_alt_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            game.playerCount,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: AppColors.trophyGold,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            game.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            game.isPlayable
                                ? Icons.play_circle_fill_rounded
                                : Icons.arrow_forward_ios_rounded,
                            size: game.isPlayable ? 26 : 14,
                            color: game.isPlayable
                                ? AppColors.primaryBlueLight
                                : AppColors.textMuted,
                          ),
                        ],
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
