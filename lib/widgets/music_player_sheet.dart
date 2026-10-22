import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/in_app_music_service.dart';
import '../services/phone_media_picker_service.dart';
import '../services/voice_room_manager.dart';
import '../theme/app_theme.dart';

class MusicPlayerSheet extends StatelessWidget {
  const MusicPlayerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const MusicPlayerSheet(),
    );
  }

  bool _checkPermission(BuildContext context) {
    if (!VoiceRoomManager().hasActiveRoom) return true;
    final currentUserName = AuthService().currentUser?.name;
    final canManage = VoiceRoomManager().canControlMusic(currentUserName);
    if (!canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '🔒 Only Room Host or assigned Admins can control room music.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  void _showUploadMusicDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final genreCtrl = TextEditingController(text: 'EDM / Gaming');
    final bpmCtrl = TextEditingController(text: '128 BPM');
    String selectedLocalFile = '🎵 My_Custom_Beat.mp3';

    final presetLocalFiles = [
      '🎵 My_Custom_Beat.mp3',
      '🎵 Lofi_Room_Chill.mp3',
      '🎵 Arcade_Electro_Drive.wav',
      '🎵 Bollywood_Gaming_Remix.mp3',
      '🎵 Victory_Celebration_Theme.mp3',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.cloud_upload_rounded,
                    color: AppColors.accentCyan, size: 26),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Upload Music from Phone',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primary Phone Storage Picker
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.folder_open_rounded, size: 20),
                      label: const Text(
                        'Browse Phone Audio Files (.mp3)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final picked = await PhoneMediaPickerService
                            .pickMusicFromPhoneStorage();
                        if (picked != null) {
                          final title = picked['title'] ?? 'Uploaded Song';
                          final path = picked['path'] ?? '';
                          final newTrack =
                              InAppMusicService().uploadCustomMusic(
                            title: title,
                            genre: 'Phone Audio',
                            bpm: '128 BPM',
                            audioPathOrUrl: path,
                          );
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Uploaded "${newTrack.title}" from Phone! Now playing in room.'),
                                backgroundColor: AppColors.onlineGreen,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      '— OR SELECT LOCAL PRESET FILE —',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // File selector dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedLocalFile,
                    dropdownColor: AppColors.cardBg,
                    decoration: InputDecoration(
                      labelText: 'Audio File from Storage',
                      prefixIcon: const Icon(Icons.audio_file_rounded,
                          color: AppColors.accentCyan),
                      filled: true,
                      fillColor: AppColors.cardBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    items: presetLocalFiles
                        .map((f) => DropdownMenuItem(
                            value: f,
                            child:
                                Text(f, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedLocalFile = val;
                          final clean = val
                              .replaceAll('🎵 ', '')
                              .replaceAll('.mp3', '')
                              .replaceAll('.wav', '')
                              .replaceAll('_', ' ');
                          if (titleCtrl.text.isEmpty) {
                            titleCtrl.text = clean;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Track Title',
                      hintText: 'e.g. Neon Horizon',
                      filled: true,
                      fillColor: AppColors.cardBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: genreCtrl,
                          decoration: InputDecoration(
                            labelText: 'Genre',
                            hintText: 'e.g. Lofi, Rock, EDM',
                            filled: true,
                            fillColor: AppColors.cardBg,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: bpmCtrl,
                          decoration: InputDecoration(
                            labelText: 'BPM / Tempo',
                            hintText: 'e.g. 120 BPM',
                            filled: true,
                            fillColor: AppColors.cardBg,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppColors.primaryPurple.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.onlineGreen, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Uploaded tracks will play live in room lobbies and multiplayer games!',
                            style:
                                TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Upload & Play in Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  final title = titleCtrl.text.trim().isNotEmpty
                      ? titleCtrl.text.trim()
                      : selectedLocalFile
                          .replaceAll('🎵 ', '')
                          .replaceAll('.mp3', '');
                  final genre = genreCtrl.text.trim().isNotEmpty
                      ? genreCtrl.text.trim()
                      : 'Custom Beat';
                  final bpm = bpmCtrl.text.trim().isNotEmpty
                      ? bpmCtrl.text.trim()
                      : '124 BPM';

                  final newTrack = InAppMusicService().uploadCustomMusic(
                    title: title,
                    genre: genre,
                    bpm: bpm,
                    audioPathOrUrl: selectedLocalFile,
                  );

                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.music_note_rounded,
                              color: AppColors.onlineGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                'Uploaded "${newTrack.title}" from Phone! Playing in room.'),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.surfaceLight,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
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
                        child: Icon(Icons.music_note_rounded,
                            color: current.accentColor),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Game & Room Music Store',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Upload and play music live in rooms',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      musicService.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: current.accentColor,
                      size: 38,
                    ),
                    onPressed: () {
                      if (!_checkPermission(context)) return;
                      musicService.toggleMusic();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Button 1: Direct Phone Audio / MP3 File Picker
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.audio_file_rounded,
                      size: 20, color: Colors.black),
                  label: const Text(
                    '📁 Upload Music from Phone Storage (.mp3)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                  ),
                  onPressed: () async {
                    if (!_checkPermission(context)) return;
                    final picked = await PhoneMediaPickerService
                        .pickMusicFromPhoneStorage();
                    if (picked != null) {
                      final title = picked['title'] ?? 'Uploaded Song';
                      final path = picked['path'] ?? '';
                      InAppMusicService().uploadCustomMusic(
                        title: title,
                        genre: 'Phone Audio',
                        bpm: '128 BPM',
                        audioPathOrUrl: path,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Uploaded "$title" from Phone! Now playing in room.'),
                            backgroundColor: AppColors.onlineGreen,
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        _showUploadMusicDialog(context);
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Button 2: Track details & Presets modal
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text(
                    'Custom Track Details / Local Presets',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    if (!_checkPermission(context)) return;
                    _showUploadMusicDialog(context);
                  },
                ),
              ),

              const SizedBox(height: 14),

              // Volume slider
              Row(
                children: [
                  const Icon(Icons.volume_down_rounded,
                      size: 20, color: AppColors.textSecondary),
                  Expanded(
                    child: Slider(
                      value: musicService.volume,
                      activeColor: current.accentColor,
                      onChanged: musicService.setVolume,
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded,
                      size: 20, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Background Track:',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    '${musicService.tracks.length} Tracks',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Track list
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.32,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: musicService.tracks.length,
                  itemBuilder: (context, i) {
                    final track = musicService.tracks[i];
                    final isSelected =
                        track.id == musicService.currentTrackIndex;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          if (!_checkPermission(context)) return;
                          musicService.selectTrack(track.id);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? track.accentColor.withValues(alpha: 0.18)
                                : AppColors.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? track.accentColor
                                  : AppColors.cardBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(track.icon,
                                  color: track.accentColor, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          track.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isSelected
                                                ? track.accentColor
                                                : Colors.white,
                                          ),
                                        ),
                                        if (track.isUserUploaded) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEC4899),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'UPLOADED',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '${track.genre} • ${track.bpm}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  musicService.isPlaying
                                      ? Icons.graphic_eq_rounded
                                      : Icons.check_circle_rounded,
                                  color: track.accentColor,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
