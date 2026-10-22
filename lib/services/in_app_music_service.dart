import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';
import 'aws_storage_service.dart';
import 'phone_media_picker_service.dart';

class MusicTrack {
  final int id;
  final String title;
  final String genre;
  final String bpm;
  final IconData icon;
  final Color accentColor;
  final bool isUserUploaded;
  final String? audioSource;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.genre,
    required this.bpm,
    required this.icon,
    required this.accentColor,
    this.isUserUploaded = false,
    this.audioSource,
  });
}

/// InAppMusicService: Manages local store background music in games & rooms.
/// Plays melodic synthesized audio loops across gameplay sessions and supports
/// user uploads of custom music tracks.
class InAppMusicService extends ChangeNotifier {
  static final InAppMusicService _instance = InAppMusicService._internal();
  factory InAppMusicService() => _instance;

  InAppMusicService._internal();

  static const MethodChannel _soundChannel =
      MethodChannel('com.playfriends.game_sound');

  bool _isPlaying = false;
  int _currentTrackIndex = 0;
  double _volume = 0.8;
  Timer? _loopTimer;

  static final List<MusicTrack> _initialTracks = [
    const MusicTrack(
      id: 0,
      title: 'Arcade Neon Pulse',
      genre: 'Synthwave / Retro',
      bpm: '128 BPM',
      icon: Icons.electric_bolt_rounded,
      accentColor: Color(0xFF06B6D4),
    ),
    const MusicTrack(
      id: 1,
      title: 'Lofi Chill Gaming',
      genre: 'Lofi / Ambient',
      bpm: '84 BPM',
      icon: Icons.headphones_rounded,
      accentColor: Color(0xFF8B5CF6),
    ),
    const MusicTrack(
      id: 2,
      title: 'Ludo Arena Fiesta',
      genre: 'Carnival / Beat',
      bpm: '116 BPM',
      icon: Icons.casino_rounded,
      accentColor: Color(0xFFF59E0B),
    ),
    const MusicTrack(
      id: 3,
      title: 'Champion Victory Beat',
      genre: 'Heroic Anthem',
      bpm: '135 BPM',
      icon: Icons.military_tech_rounded,
      accentColor: Color(0xFF10B981),
    ),
  ];

  late final List<MusicTrack> _tracks = List<MusicTrack>.from(_initialTracks);

  List<MusicTrack> get tracks => List.unmodifiable(_tracks);
  bool get isPlaying => _isPlaying;
  int get currentTrackIndex => _currentTrackIndex;
  double get volume => _volume;
  MusicTrack get currentTrack =>
      _tracks[_currentTrackIndex.clamp(0, _tracks.length - 1)];

  /// Load all songs uploaded by this user from the server / cloud storage
  Future<void> loadUserSongs(String userId) async {
    final serverSongs = await AwsStorageService.getUserSongsFromServer(userId);
    bool changed = false;

    for (final s in serverSongs) {
      final title = (s['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;

      final alreadyExists =
          _tracks.any((t) => t.isUserUploaded && t.title == title);
      if (!alreadyExists) {
        final newId = _tracks.length;
        _tracks.add(
          MusicTrack(
            id: newId,
            title: title,
            genre: (s['genre'] ?? 'Phone Audio').toString(),
            bpm: (s['bpm'] ?? '124 BPM').toString(),
            icon: Icons.library_music_rounded,
            accentColor: const Color(0xFFEC4899),
            isUserUploaded: true,
            audioSource: s['audioPathOrUrl']?.toString(),
          ),
        );
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  /// Removes all user-uploaded custom tracks from the active playlist
  void clearUserSongs(String userId) {
    _tracks.removeWhere((t) => t.isUserUploaded);
    if (_currentTrackIndex >= _tracks.length) {
      _currentTrackIndex = 0;
    }
    notifyListeners();
  }

  /// Upload and register custom music track in server and local storage store
  MusicTrack uploadCustomMusic({
    required String title,
    required String genre,
    String? audioPathOrUrl,
    String? bpm,
    String? fileName,
  }) {
    final newId = _tracks.length;
    final cleanTitle =
        title.trim().isNotEmpty ? title.trim() : 'Custom Track #$newId';
    final cleanGenre = genre.trim().isNotEmpty ? genre.trim() : 'Custom Audio';
    final cleanBpm =
        (bpm != null && bpm.trim().isNotEmpty) ? bpm.trim() : '124 BPM';

    final track = MusicTrack(
      id: newId,
      title: cleanTitle,
      genre: cleanGenre,
      bpm: cleanBpm,
      icon: Icons.library_music_rounded,
      accentColor: const Color(0xFFEC4899),
      isUserUploaded: true,
      audioSource: audioPathOrUrl,
    );
    _tracks.add(track);

    // Save to AWS server and persistent cache
    final currentUserId = AuthService().currentUser?.id ?? '01';
    AwsStorageService.uploadSongToServer(
      userId: currentUserId,
      songId: newId,
      title: cleanTitle,
      genre: cleanGenre,
      bpm: cleanBpm,
      audioPathOrUrl: audioPathOrUrl ?? '',
      fileName: fileName,
    );

    selectTrack(newId);
    playMusic();
    notifyListeners();
    return track;
  }

  void playMusic([int? trackIndex]) {
    if (trackIndex != null && trackIndex >= 0 && trackIndex < _tracks.length) {
      _currentTrackIndex = trackIndex;
    }
    _isPlaying = true;
    _loopTimer?.cancel();

    final track = currentTrack;
    if (track.audioSource != null &&
        (track.audioSource!.startsWith('/') ||
            track.audioSource!.contains('.'))) {
      PhoneMediaPickerService.playAudioFile(track.audioSource!,
          volume: _volume);
    } else {
      PhoneMediaPickerService.stopAudioFile();
      _startMelodyLoop();
    }
    notifyListeners();
  }

  void pauseMusic() {
    _isPlaying = false;
    _loopTimer?.cancel();
    PhoneMediaPickerService.pauseAudioFile();
    notifyListeners();
  }

  void toggleMusic() {
    if (_isPlaying) {
      pauseMusic();
    } else {
      playMusic();
    }
  }

  void selectTrack(int index) {
    _currentTrackIndex = index.clamp(0, _tracks.length - 1);
    if (_isPlaying) {
      playMusic(_currentTrackIndex);
    }
    notifyListeners();
  }

  void setVolume(double val) {
    _volume = val.clamp(0.0, 1.0);
    PhoneMediaPickerService.setMusicVolume(_volume);
    notifyListeners();
  }

  void _startMelodyLoop() {
    _loopTimer?.cancel();
    _playTrackPulse();

    // Loop interval based on track style
    final interval = _currentTrackIndex == 1
        ? const Duration(milliseconds: 3200)
        : const Duration(milliseconds: 2400);

    _loopTimer = Timer.periodic(interval, (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      _playTrackPulse();
    });
  }

  void _playTrackPulse() {
    if (!_isPlaying) return;
    try {
      final soundKey = _currentTrackIndex == 0
          ? 'cellTap'
          : (_currentTrackIndex == 1
              ? 'star'
              : (_currentTrackIndex == 2 ? 'tokenMove' : 'strike'));
      _soundChannel
          .invokeMethod('play', {'sound': soundKey}).catchError((_) => null);
    } catch (_) {
      // Ignored for non-native environments
    }
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    super.dispose();
  }
}
