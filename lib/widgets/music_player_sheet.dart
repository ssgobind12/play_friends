import 'package:flutter/material.dart';
import '../services/in_app_music_service.dart';
import '../theme/app_theme.dart';

class MusicPlayerSheet extends StatelessWidget {
  const MusicPlayerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const MusicPlayerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final musicService = InAppMusicService();

    return ListenableBuilder(
      listenable: musicService,
      builder: (context, _) {
        final current = musicService.currentTrack;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: current.accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.music_note_rounded, color: current.accentColor),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Game & Room Music Store', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Local ambient tracks for play sessions', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      musicService.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      color: current.accentColor,
                      size: 38,
                    ),
                    onPressed: musicService.toggleMusic,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Volume slider
              Row(
                children: [
                  const Icon(Icons.volume_down_rounded, size: 20, color: AppColors.textSecondary),
                  Expanded(
                    child: Slider(
                      value: musicService.volume,
                      activeColor: current.accentColor,
                      onChanged: musicService.setVolume,
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, size: 20, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 10),

              const Text('Select Background Track:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),

              // Track list
              ...InAppMusicService.tracks.map((track) {
                final isSelected = track.id == musicService.currentTrackIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => musicService.selectTrack(track.id),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? track.accentColor.withValues(alpha: 0.18) : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? track.accentColor : AppColors.cardBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(track.icon, color: track.accentColor, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isSelected ? track.accentColor : Colors.white,
                                  ),
                                ),
                                Text('${track.genre} • ${track.bpm}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              musicService.isPlaying ? Icons.graphic_eq_rounded : Icons.check_circle_rounded,
                              color: track.accentColor,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
