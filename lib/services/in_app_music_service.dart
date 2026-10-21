import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MusicTrack {
  final int id;
  final String title;
  final String genre;
  final String bpm;
  final IconData icon;
  final Color accentColor;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.genre,
    required this.bpm,
    required this.icon,
    required this.accentColor,
  });
}

/// InAppMusicService: Manages local store background music in games & rooms.
/// Plays melodic synthesized audio loops across gameplay sessions.
class InAppMusicService extends ChangeNotifier {
  static final InAppMusicService _instance = InAppMusicService._internal();
  factory InAppMusicService() => _instance;

  InAppMusicService._internal();

  static const MethodChannel _soundChannel = MethodChannel('com.playfriends.game_sound');

  bool _isPlaying = false;
  int _currentTrackIndex = 0;
  double _volume = 0.8;
  Timer? _loopTimer;

  bool get isPlaying => _isPlaying;
  int get currentTrackIndex => _currentTrackIndex;
  double get volume => _volume;
  MusicTrack get currentTrack => tracks[_currentTrackIndex];

  static const List<MusicTrack> tracks = [
    MusicTrack(
      id: 0,
      title: 'Arcade Neon Pulse',
      genre: 'Synthwave / Retro',
      bpm: '128 BPM',
      icon: Icons.electric_bolt_rounded,
      accentColor: Color(0xFF06B6D4),
    ),
    MusicTrack(
      id: 1,
      title: 'Lofi Chill Gaming',
      genre: 'Lofi / Ambient',
      bpm: '84 BPM',
      icon: Icons.headphones_rounded,
      accentColor: Color(0xFF8B5CF6),
    ),
    MusicTrack(
      id: 2,
      title: 'Ludo Arena Fiesta',
      genre: 'Carnival / Beat',
      bpm: '116 BPM',
      icon: Icons.casino_rounded,
      accentColor: Color(0xFFF59E0B),
    ),
    MusicTrack(
      id: 3,
      title: 'Champion Victory Beat',
      genre: 'Heroic Anthem',
      bpm: '135 BPM',
      icon: Icons.military_tech_rounded,
      accentColor: Color(0xFF10B981),
    ),
  ];

  void playMusic([int? trackIndex]) {
    if (trackIndex != null && trackIndex >= 0 && trackIndex < tracks.length) {
      _currentTrackIndex = trackIndex;
    }
    _isPlaying = true;
    _startMelodyLoop();
    notifyListeners();
  }

  void pauseMusic() {
    _isPlaying = false;
    _loopTimer?.cancel();
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
    _currentTrackIndex = index.clamp(0, tracks.length - 1);
    if (_isPlaying) {
      _loopTimer?.cancel();
      _startMelodyLoop();
    }
    notifyListeners();
  }

  void setVolume(double val) {
    _volume = val.clamp(0.0, 1.0);
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
          : (_currentTrackIndex == 1 ? 'star' : (_currentTrackIndex == 2 ? 'tokenMove' : 'strike'));
      _soundChannel.invokeMethod('play', {'sound': soundKey});
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
