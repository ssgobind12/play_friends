import 'dart:convert';
import 'package:flutter/material.dart';
import '../screens/voice_party_room_screen.dart';
import '../services/voice_room_manager.dart';
import '../theme/app_theme.dart';

/// Floating Mini Room Player: Appears at the bottom-left of all screens
/// when a user is in an active voice room.
class FloatingMiniRoomPlayer extends StatefulWidget {
  const FloatingMiniRoomPlayer({super.key});

  @override
  State<FloatingMiniRoomPlayer> createState() => _FloatingMiniRoomPlayerState();
}

class _FloatingMiniRoomPlayerState extends State<FloatingMiniRoomPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (VoiceRoomManager().hasActiveRoom) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  ImageProvider? _resolveImage(String? photo) {
    if (photo == null || photo.isEmpty) return null;
    if (photo.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(photo.split(',')[1]));
      } catch (_) {
        return null;
      }
    }
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return NetworkImage(photo);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VoiceRoomManager(),
      builder: (context, _) {
        final roomManager = VoiceRoomManager();
        if (!roomManager.hasActiveRoom) {
          if (_pulseCtrl.isAnimating) {
            _pulseCtrl.stop();
          }
          return const SizedBox.shrink();
        }

        if (!_pulseCtrl.isAnimating) {
          _pulseCtrl.repeat(reverse: true);
        }

        final room = roomManager.activeRoom!;
        final hostImage = _resolveImage(room.hostPhoto);

        return Positioned(
          left: 14,
          bottom: 12,
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VoicePartyRoomScreen(room: room),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2D184E), Color(0xFF131738)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.8),
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Host Avatar or Music Icon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: hostImage != null
                          ? Image(
                              image: hostImage,
                              width: 62,
                              height: 62,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: AppColors.primaryPurple,
                              child: Center(
                                child: Text(
                                  room.hostName.isNotEmpty ? room.hostName[0] : '🎵',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                    ),

                    // Animated Equalizer Wave Overlay (Ahchat style)
                    Positioned(
                      bottom: 4,
                      left: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (context, _) {
                            final val = _pulseCtrl.value;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Container(
                                  width: 2.5,
                                  height: 6 + val * 8,
                                  color: AppColors.accentCyan,
                                ),
                                Container(
                                  width: 2.5,
                                  height: 12 - val * 7,
                                  color: AppColors.coinAmber,
                                ),
                                Container(
                                  width: 2.5,
                                  height: 5 + val * 10,
                                  color: AppColors.primaryPurpleLight,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    // Close / Exit Room Button
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () {
                          roomManager.leaveRoom();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Left voice room'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
