import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../models/room_theme_model.dart';
import '../services/auth_service.dart';
import '../services/game_sound_service.dart';
import '../services/in_app_music_service.dart';
import '../services/privacy_filter_service.dart';
import '../services/voice_room_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/music_player_sheet.dart';
import '../widgets/room_profile_dialog.dart';
import '../widgets/user_profile_dialog.dart';
import 'carrom_game_screen.dart';
import 'ludo_game_screen.dart';
import 'tic_tac_toe_screen.dart';
import 'space_dodge_screen.dart';
import 'neon_arena_brawl_screen.dart';
import 'word_rush_screen.dart';

// Available animated gifts for voice rooms
class GiftItem {
  final String id;
  final String name;
  final String icon;
  final int cost;
  final Color glowColor;
  final String description;

  const GiftItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.cost,
    required this.glowColor,
    required this.description,
  });
}

const List<GiftItem> kRoomGifts = [
  GiftItem(
    id: 'rose',
    name: 'Romantic Rose',
    icon: '🌹',
    cost: 10,
    glowColor: Color(0xFFF43F5E),
    description: 'Shower with fresh roses',
  ),
  GiftItem(
    id: 'heart',
    name: 'Love Heart',
    icon: '💖',
    cost: 50,
    glowColor: Color(0xFFEC4899),
    description: 'Send endless sparkling love',
  ),
  GiftItem(
    id: 'dice',
    name: 'Lucky Dice',
    icon: '🎲',
    cost: 100,
    glowColor: Color(0xFF8B5CF6),
    description: 'Brings high rolls & luck',
  ),
  GiftItem(
    id: 'ring',
    name: 'Diamond Ring',
    icon: '💍',
    cost: 500,
    glowColor: Color(0xFF06B6D4),
    description: 'Sparkling royal diamond',
  ),
  GiftItem(
    id: 'car',
    name: 'Super Sports Car',
    icon: '🏎️',
    cost: 1000,
    glowColor: Color(0xFFEF4444),
    description: 'Vroooom across the room!',
  ),
  GiftItem(
    id: 'castle',
    name: 'Magic Castle',
    icon: '🏰',
    cost: 2500,
    glowColor: Color(0xFFF59E0B),
    description: 'Royal kingdom palace',
  ),
  GiftItem(
    id: 'dragon',
    name: 'Golden Dragon',
    icon: '🐉',
    cost: 5000,
    glowColor: Color(0xFFEAB308),
    description: 'Fierce mythical dragon banner',
  ),
  GiftItem(
    id: 'rocket',
    name: 'Galaxy Rocket',
    icon: '🚀',
    cost: 10000,
    glowColor: Color(0xFF3B82F6),
    description: 'Blast off to the stars!',
  ),
];

class RoomChatMessage {
  final String id;
  final String senderName;
  final String? senderPhoto;
  final Color senderColor;
  final int level;
  final String message;
  final bool isJoinAnnouncement;
  final bool isGiftAnnouncement;
  final GiftItem? gift;
  final String? recipientName;

  const RoomChatMessage({
    required this.id,
    required this.senderName,
    this.senderPhoto,
    required this.senderColor,
    this.level = 1,
    required this.message,
    this.isJoinAnnouncement = false,
    this.isGiftAnnouncement = false,
    this.gift,
    this.recipientName,
  });
}

class MicSeatData {
  final int seatIndex;
  final String? userName;
  final String? userPhoto;
  final Color? userColor;
  final int level;
  final bool isMuted;
  final bool isSpeaking;
  final bool isHost;

  const MicSeatData({
    required this.seatIndex,
    this.userName,
    this.userPhoto,
    this.userColor,
    this.level = 1,
    this.isMuted = false,
    this.isSpeaking = false,
    this.isHost = false,
  });

  MicSeatData copyWith({
    String? userName,
    String? userPhoto,
    Color? userColor,
    int? level,
    bool? isMuted,
    bool? isSpeaking,
    bool? isHost,
    bool clearUser = false,
  }) {
    return MicSeatData(
      seatIndex: seatIndex,
      userName: clearUser ? null : (userName ?? this.userName),
      userPhoto: clearUser ? null : (userPhoto ?? this.userPhoto),
      userColor: clearUser ? null : (userColor ?? this.userColor),
      level: clearUser ? 1 : (level ?? this.level),
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isHost: isHost ?? this.isHost,
    );
  }
}

/// Floating animated reaction item
class FloatingReaction {
  final String emoji;
  final double startX;
  final Key key;

  FloatingReaction(
      {required this.emoji, required this.startX, required this.key});
}

/// Full screen Voice & Party Room Screen
class VoicePartyRoomScreen extends StatefulWidget {
  final RoomModel room;

  const VoicePartyRoomScreen({super.key, required this.room});

  @override
  State<VoicePartyRoomScreen> createState() => _VoicePartyRoomScreenState();
}

class _VoicePartyRoomScreenState extends State<VoicePartyRoomScreen>
    with TickerProviderStateMixin {
  late AnimationController _vinylAnimCtrl;
  late AnimationController _giftAnimCtrl;
  late ScrollController _chatScrollCtrl;
  final TextEditingController _chatInputCtrl = TextEditingController();

  late List<MicSeatData> _seats;
  late List<RoomChatMessage> _messages;
  final List<FloatingReaction> _reactions = [];

  bool _isMicMuted = false;
  bool _isRoomAudioMuted = false;
  bool _isVinylPlayerVisible = true;
  int _charmPoints = 0;
  int _activeSpectators = 120;
  GiftItem? _activeGiftOverlay;
  String? _activeGiftSender;
  RoomThemeData _currentTheme = RoomThemeData.presetThemes[0];

  Timer? _simulatedTrafficTimer;

  @override
  void initState() {
    super.initState();
    _charmPoints = widget.room.giftPoints;

    // Register active room in VoiceRoomManager for background & floating mini-player
    VoiceRoomManager().joinRoom(widget.room);

    // Silent by default when entering or creating room; only plays when player presses play!
    InAppMusicService().pauseMusic();

    // Continuous Vinyl record rotation animation
    _vinylAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Gift Celebration Banner Animation
    _giftAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _chatScrollCtrl = ScrollController();

    final user = AuthService().currentUser;
    final isHostMe = widget.room.hostName == (user?.name ?? '');

    // Initialize 8 Mic Seats (Seat 1 = Host)
    _seats = List.generate(8, (i) {
      if (i == 0) {
        return MicSeatData(
          seatIndex: 1,
          userName: widget.room.hostName,
          userPhoto: isHostMe ? user?.profilePhoto : widget.room.hostPhoto,
          userColor: isHostMe
              ? (user?.avatarColor ?? AppColors.primaryPurple)
              : AppColors.primaryPurple,
          level: isHostMe ? (user?.level ?? 1) : 25,
          isMuted: false,
          isSpeaking: true,
          isHost: true,
        );
      }
      return MicSeatData(seatIndex: i + 1);
    });

    // Initial Room Welcome Notice
    _messages = [
      RoomChatMessage(
        id: 'msg_welcome',
        senderName: 'System Notice',
        senderColor: AppColors.accentCyan,
        message:
            'Welcome to ${widget.room.gameTitle}! Enjoy voice chat, music, and social games with friends.',
      ),
    ];

    _activeSpectators = max(1, widget.room.currentPlayers);
  }

  @override
  void dispose() {
    _simulatedTrafficTimer?.cancel();
    _vinylAnimCtrl.dispose();
    _giftAnimCtrl.dispose();
    _chatScrollCtrl.dispose();
    _chatInputCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleMicSeat(int seatIndex) {
    final user = AuthService().currentUser;
    if (user == null) return;

    final mySeatIndex = _seats.indexWhere((s) => s.userName == user.name);

    setState(() {
      if (mySeatIndex == seatIndex) {
        // Leave seat
        _seats[seatIndex] = MicSeatData(seatIndex: seatIndex + 1);
        GameSoundService.buttonTap();
      } else if (_seats[seatIndex].userName == null) {
        // If already on another seat, vacate it first
        if (mySeatIndex != -1) {
          _seats[mySeatIndex] = MicSeatData(seatIndex: mySeatIndex + 1);
        }
        // Take seat
        _seats[seatIndex] = MicSeatData(
          seatIndex: seatIndex + 1,
          userName: user.name,
          userPhoto: user.profilePhoto,
          userColor: user.avatarColor,
          level: user.level,
          isMuted: _isMicMuted,
          isSpeaking: !_isMicMuted,
          isHost: seatIndex == 0,
        );
        GameSoundService.buttonTap();
      } else {
        // Seat taken by another user
        final seat = _seats[seatIndex];
        final occupant = seat.userName!;
        final isHostMe = widget.room.hostName == user.name;
        if (isHostMe) {
          _showHostUserManageSheet(occupant, seatIndex);
        } else {
          UserProfileDialog.show(
            context,
            name: occupant,
            profilePhoto: seat.userPhoto,
            avatarColor: seat.userColor,
            level: seat.level,
          );
        }
      }
    });
  }

  void _showHostUserManageSheet(String targetUser, int seatIndex) {
    final roomManager = VoiceRoomManager();
    final isAdmin = roomManager.roomAdmins.contains(targetUser);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B4B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Manage $targetUser',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person_pin_rounded,
                  color: AppColors.accentCyan),
              title: const Text('View User Profile'),
              subtitle: const Text(
                  'Inspect followers, following, level & gifts',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              onTap: () {
                Navigator.of(ctx).pop();
                final seat = _seats[seatIndex];
                UserProfileDialog.show(
                  context,
                  name: targetUser,
                  profilePhoto: seat.userPhoto,
                  avatarColor: seat.userColor,
                  level: seat.level,
                );
              },
            ),
            ListTile(
              leading: Icon(
                isAdmin
                    ? Icons.remove_moderator_rounded
                    : Icons.admin_panel_settings_rounded,
                color: AppColors.coinAmber,
              ),
              title: Text(isAdmin
                  ? 'Remove Admin Permissions'
                  : '👑 Assign as Room Admin'),
              subtitle: Text(
                isAdmin
                    ? 'User will no longer be able to control or change room music'
                    : 'Allow user to control room music & upload tracks',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                final nowAdmin = roomManager.toggleAdminPermission(targetUser);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(nowAdmin
                        ? '👑 $targetUser is now a Room Admin! Can control music.'
                        : 'Removed admin rights from $targetUser'),
                    backgroundColor: AppColors.onlineGreen,
                  ),
                );
                setState(() {});
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.mic_off_rounded, color: Colors.redAccent),
              title: const Text('Mute Participant Mic'),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _seats[seatIndex] = _seats[seatIndex]
                      .copyWith(isMuted: true, isSpeaking: false);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.card_giftcard_rounded,
                  color: AppColors.accentCyan),
              title: const Text('Send Gift to Participant'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showGiftDrawer();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    // Strict Privacy & Anti-Scam Filter
    final check = PrivacyFilterService.checkMessage(clean);
    if (!check.isAllowed) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B4B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.shield_rounded, color: Colors.amber, size: 26),
              SizedBox(width: 8),
              Text('Security Protection',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            check.reason ??
                'Sharing personal contact details (phone numbers, WhatsApp, Instagram, Facebook, or external IDs) is not permitted.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    final user = AuthService().currentUser;
    final senderName = user?.name ?? 'Player';

    setState(() {
      _messages.add(
        RoomChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
          senderName: senderName,
          senderPhoto: user?.profilePhoto,
          senderColor: user?.avatarColor ?? AppColors.primaryPurple,
          level: user?.level ?? 1,
          message: clean,
        ),
      );
    });
    _chatInputCtrl.clear();
    _scrollToBottom();
    GameSoundService.buttonTap();
  }

  void _sendGift(GiftItem gift) {
    final auth = AuthService();
    final user = auth.currentUser;
    if (user == null) return;

    final hasDeducted = auth.spendCoins(gift.cost);
    if (!hasDeducted) {
      // Insufficient coins dialog with recharge bonus prompt
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.monetization_on_rounded,
                  color: AppColors.coinAmber, size: 26),
              SizedBox(width: 8),
              Text('Need More Coins!'),
            ],
          ),
          content: Text(
            'Sending ${gift.icon} ${gift.name} costs ${gift.cost} coins. Your balance is ${user.coins} coins.\n\nClaim your +1,000 Free Daily Recharge Bonus now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.card_giftcard_rounded, size: 18),
              label: const Text('Claim +1,000 Coins Bonus'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coinAmber,
                  foregroundColor: Colors.black),
              onPressed: () {
                auth.addCoins(1000);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Claimed +1,000 Recharge Bonus Coins!'),
                    backgroundColor: AppColors.onlineGreen,
                  ),
                );
              },
            ),
          ],
        ),
      );
      return;
    }

    // Trigger celebration sound & haptics
    GameSoundService.giftSent();

    final prevLevel = user.level;
    // Record gift in VoiceRoomManager: increases room level, room charm, and user ID level
    VoiceRoomManager().recordGiftSent(coins: gift.cost, senderName: user.name);
    final newLevel = auth.currentUser?.level ?? prevLevel;

    setState(() {
      _charmPoints += gift.cost;
      _activeGiftOverlay = gift;
      _activeGiftSender = user.name;
      _messages.add(
        RoomChatMessage(
          id: 'gift_${DateTime.now().millisecondsSinceEpoch}',
          senderName: user.name,
          senderPhoto: user.profilePhoto,
          senderColor: user.avatarColor,
          level: newLevel,
          message:
              'showered ${widget.room.hostName} with ${gift.icon} ${gift.name}!',
          isGiftAnnouncement: true,
          gift: gift,
          recipientName: widget.room.hostName,
        ),
      );
    });

    if (newLevel > prevLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🎉 LEVEL UP! You reached Level $newLevel! Larger room capacity unlocked!'),
          backgroundColor: AppColors.trophyGold,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    _giftAnimCtrl.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _activeGiftOverlay = null;
        });
      }
    });

    _scrollToBottom();
  }

  void _addFloatingReaction(String emoji) {
    final startX = 0.6 + Random().nextDouble() * 0.35;
    final reaction =
        FloatingReaction(emoji: emoji, startX: startX, key: UniqueKey());
    setState(() {
      _reactions.add(reaction);
    });
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _reactions.remove(reaction);
        });
      }
    });
  }

  void _showGiftDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16192E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: AuthService(),
          builder: (context, _) {
            final coins = AuthService().currentUser?.coins ?? 0;

            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.card_giftcard_rounded,
                              color: AppColors.trophyGold, size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            'Send Room Gift',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEC4899)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFEC4899)),
                            ),
                            child: const Text(
                              'Send Charm ✨',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFEC4899),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.monetization_on_rounded,
                                color: AppColors.coinAmber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$coins',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.coinAmber),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                AuthService().addCoins(500);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Claimed +500 Coins Recharge Bonus!'),
                                    backgroundColor: AppColors.onlineGreen,
                                  ),
                                );
                              },
                              child: const Text(
                                '+Recharge',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.accentCyan,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Gifts Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: kRoomGifts.length,
                    itemBuilder: (context, i) {
                      final gift = kRoomGifts[i];
                      final canAfford = coins >= gift.cost;

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _sendGift(gift);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2342),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: gift.glowColor
                                  .withValues(alpha: canAfford ? 0.6 : 0.2),
                              width: canAfford ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(gift.icon,
                                  style: const TextStyle(fontSize: 32)),
                              const SizedBox(height: 6),
                              Text(
                                gift.name,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.monetization_on_rounded,
                                      color: AppColors.coinAmber, size: 12),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${gift.cost}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: canAfford
                                          ? AppColors.coinAmber
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showThemeSelectorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.palette_rounded,
                      color: AppColors.accentCyan, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '10 Room Atmosphere Themes',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Text(
                'Customize the background lighting and atmosphere of this room:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: RoomThemeData.presetThemes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.6,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, i) {
                    final theme = RoomThemeData.presetThemes[i];
                    final isSelected = theme.id == _currentTheme.id;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _currentTheme = theme;
                        });
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(theme.icon,
                                    color: theme.accentColor, size: 20),
                                const SizedBox(width: 8),
                                Text('Switched room theme to "${theme.name}"!'),
                              ],
                            ),
                            backgroundColor: AppColors.surfaceDark,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: theme.gradientColors.take(2).toList(),
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isSelected ? theme.accentColor : Colors.white24,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(theme.icon,
                                color: theme.accentColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                theme.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  color: theme.accentColor, size: 18),
                          ],
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

  void _launchRoomGame() {
    final games = [
      (
        id: 'tic_tac_toe',
        title: 'Tic-Tac-Toe Duel',
        desc: 'Fast 1v1 grid battle',
        icon: Icons.grid_3x3_rounded,
        color: AppColors.primaryPurple,
        screen: const TicTacToeScreen(),
      ),
      (
        id: 'ludo',
        title: 'Ludo Friends',
        desc: '4-Player classic board race (Ludo King style)',
        icon: Icons.casino_rounded,
        color: const Color(0xFFF59E0B),
        screen: const LudoGameScreen(),
      ),
      (
        id: 'carrom',
        title: 'Carrom Clash',
        desc: 'Striker disc physics battle',
        icon: Icons.circle_outlined,
        color: const Color(0xFFEC4899),
        screen: const CarromGameScreen(),
      ),
      (
        id: 'space_dodge',
        title: 'Cyber Space Dodge',
        desc: 'Retro arcade dodge battle',
        icon: Icons.rocket_launch_rounded,
        color: AppColors.accentCyan,
        screen: const SpaceDodgeGameScreen(),
      ),
      (
        id: 'arena_brawl',
        title: 'Neon Arena Brawl',
        desc: 'Neon gladiator combat',
        icon: Icons.sports_kabaddi_rounded,
        color: const Color(0xFFEF4444),
        screen: const NeonArenaBrawlScreen(),
      ),
      (
        id: 'word_rush',
        title: 'Word Sprint Rush',
        desc: 'Vocabulary speed challenge',
        icon: Icons.spellcheck_rounded,
        color: const Color(0xFF10B981),
        screen: const WordRushScreen(),
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131127),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final auth = AuthService();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sports_esports_rounded,
                      color: AppColors.coinAmber, size: 26),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Play Game in this Room',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          'Pick any game to launch and play with room members',
                          style: TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...games.map((g) {
                final isUnlocked = auth.isGameUnlocked(g.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUnlocked
                          ? g.color.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: g.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(g.icon,
                          color: isUnlocked ? g.color : Colors.white38,
                          size: 24),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            g.title,
                            style: TextStyle(
                              color: isUnlocked ? Colors.white : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (widget.room.gameTitle
                            .toLowerCase()
                            .contains(g.id.replaceAll('_', ' '))) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.onlineGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('ROOM GAME',
                                style: TextStyle(
                                    color: AppColors.onlineGreen,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      isUnlocked
                          ? g.desc
                          : '🔒 Unlocks with higher level & wins',
                      style: TextStyle(
                        color: isUnlocked ? Colors.white70 : Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    trailing: isUnlocked
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: g.color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Play ▶',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11)),
                          )
                        : const Icon(Icons.lock_rounded,
                            color: Colors.white38, size: 18),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      if (isUnlocked) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => g.screen),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '🔒 ${g.title} is locked. Reach higher level or wins to unlock!'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  ImageProvider? _resolveAvatarImage(String? photo) {
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
    final music = InAppMusicService();
    final currentTrack = music.currentTrack;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Room stays active in VoiceRoomManager and continues playing in background floating mini-player!
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 1. Dynamic Room Theme Gradient Background (10 Custom Themes)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _currentTheme.gradientColors,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Ambient Stars / City Glow Details
            Positioned(
              top: 60,
              left: 20,
              child: Icon(Icons.star_rounded,
                  size: 8, color: Colors.white.withValues(alpha: 0.3)),
            ),
            Positioned(
              top: 120,
              right: 40,
              child: Icon(Icons.star_rounded,
                  size: 10, color: Colors.white.withValues(alpha: 0.4)),
            ),
            Positioned(
              top: 220,
              left: 50,
              child: Icon(Icons.star_rounded,
                  size: 6, color: Colors.white.withValues(alpha: 0.2)),
            ),

            // Main Room Content
            SafeArea(
              child: Column(
                children: [
                  // 2. Room Top Header Bar
                  _buildTopHeader(),

                  const SizedBox(height: 10),

                  // 3. Multi-Mic Seats Grid (Host + 7 Guest Seats)
                  _buildMicSeatGrid(),

                  const SizedBox(height: 10),

                  // 4. Floating Vinyl Record DJ Music Player
                  if (_isVinylPlayerVisible)
                    _buildVinylRecordPlayer(currentTrack, music),

                  // 5. Live Room Chat Stream & Welcome Notices
                  Expanded(
                    child: _buildChatStream(),
                  ),

                  // 6. Bottom Control & Action Bar (Speaker, Mic, Emoji, Chat, Gift, Game)
                  _buildBottomActionBar(),
                ],
              ),
            ),

            // 7. Full-Screen Floating Emoji Reactions
            ..._reactions.map((r) => _buildAnimatedReaction(r)),

            // 8. Full-Screen Celebratory Gift Overlay
            if (_activeGiftOverlay != null) _buildGiftCelebrationOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    final hostPhoto =
        widget.room.hostPhoto ?? AuthService().currentUser?.profilePhoto;
    final hostImage = _resolveAvatarImage(hostPhoto);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Minimize / Back Button
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Minimize Room',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 6),

            // Host Profile & Prominent Room Title (Tap to inspect Room Profile)
            GestureDetector(
              onTap: () => RoomProfileDialog.show(context, room: widget.room),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primaryPurple,
                      backgroundImage: hostImage,
                      child: hostImage != null
                          ? null
                          : Text(
                              widget.room.hostName.isNotEmpty
                                  ? widget.room.hostName[0]
                                  : 'H',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 12),
                            ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.room.gameTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              letterSpacing: 0.1,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ID: ${widget.room.roomCode}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.trophyGold
                                        .withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.emoji_events_rounded,
                                          size: 9, color: AppColors.trophyGold),
                                      const SizedBox(width: 2),
                                      Text(
                                        '$_charmPoints',
                                        style: const TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.trophyGold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 6),

            // Right Controls: Follow, Spectators, Themes, Leave
            // Follow Room Button
            ListenableBuilder(
              listenable: VoiceRoomManager(),
              builder: (context, _) {
                final isFollowed =
                    VoiceRoomManager().isFollowingRoom(widget.room.roomCode);
                return GestureDetector(
                  onTap: () {
                    VoiceRoomManager().toggleFollowRoom(widget.room.roomCode);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isFollowed
                            ? 'Unfollowed room'
                            : 'Following room! Added to your Favorites ⭐'),
                        duration: const Duration(milliseconds: 900),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isFollowed
                          ? AppColors.onlineGreen
                          : AppColors.primaryPurple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isFollowed ? 'Following ✓' : '+ Follow',
                      style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),

            // Spectators Count Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_alt_rounded,
                      size: 11, color: AppColors.accentCyan),
                  const SizedBox(width: 2),
                  Text(
                    '$_activeSpectators/${widget.room.maxPlayers}',
                    style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),

            // Themes Button
            IconButton(
              icon: const Icon(Icons.palette_rounded,
                  color: AppColors.coinAmber, size: 19),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '10 Room Themes',
              onPressed: () => _showThemeSelectorSheet(context),
            ),
            const SizedBox(width: 4),

            // Power / Exit Button
            IconButton(
              icon: const Icon(Icons.power_settings_new_rounded,
                  color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Leave / Minimize Room',
              onPressed: () {
                final user = AuthService().currentUser;
                final isHost = widget.room.hostName == (user?.name ?? '') ||
                    widget.room.hostName == '${user?.name} 👑' ||
                    widget.room.hostName.startsWith(user?.name ?? '');

                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1B4B),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Voice Party Room'),
                    content: Text(
                      isHost
                          ? 'Do you want to minimize this room to the floating mini-player, leave it, or delete this room permanently?'
                          : 'Do you want to minimize this room to the floating mini-player, or leave completely?',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    actions: [
                      if (isHost)
                        TextButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                backgroundColor: const Color(0xFF1E1B4B),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                title: const Text('Confirm Deletion',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                content: Text(
                                  'Are you sure you want to permanently delete "${widget.room.gameTitle}"?',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Cancel',
                                        style:
                                            TextStyle(color: Colors.white60)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.dangerRose),
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Delete',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              AuthService().deleteRoom(widget.room.id);
                              if (mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Room "${widget.room.gameTitle}" deleted.'),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Delete Room',
                              style: TextStyle(color: AppColors.dangerRose)),
                        ),
                      TextButton(
                        onPressed: () {
                          // Minimize: pop screen, keeps room active in background with floating mini-player!
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Minimize to Floating Player',
                            style: TextStyle(color: AppColors.accentCyan)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent),
                        onPressed: () {
                          // Leave: stop audio, clear active room, pop screen
                          Navigator.of(ctx).pop();
                          VoiceRoomManager().leaveRoom();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Leave Room'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicSeatGrid() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Row 1: Seats 1 to 4
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(4, (i) => _buildSeatItem(_seats[i], i)),
          ),
          const SizedBox(height: 12),
          // Row 2: Seats 5 to 8
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                List.generate(4, (i) => _buildSeatItem(_seats[i + 4], i + 4)),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatItem(MicSeatData seat, int index) {
    final isOccupied = seat.userName != null;
    final avatarImage = _resolveAvatarImage(seat.userPhoto);

    return GestureDetector(
      onTap: () => _toggleMicSeat(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Speaking Wave Glow Animation
              if (seat.isSpeaking && !seat.isMuted)
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF06B6D4), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.45),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

              // Circle Seat Avatar / Empty Mic Icon
              CircleAvatar(
                radius: 23,
                backgroundColor: isOccupied
                    ? (seat.userColor ?? AppColors.primaryPurple)
                    : Colors.white.withValues(alpha: 0.12),
                backgroundImage: avatarImage,
                child: isOccupied
                    ? (avatarImage != null
                        ? null
                        : Text(
                            seat.userName!.isNotEmpty ? seat.userName![0] : 'U',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16),
                          ))
                    : const Icon(Icons.mic_none_rounded,
                        color: Colors.white54, size: 20),
              ),

              // Status Badge (Muted or Mic Number)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: seat.isMuted ? Colors.redAccent : Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    seat.isMuted
                        ? Icons.mic_off_rounded
                        : (isOccupied ? Icons.mic_rounded : Icons.add_rounded),
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Seat Label or Username
          SizedBox(
            width: 60,
            child: Text(
              isOccupied ? seat.userName! : '${seat.seatIndex}',
              style: TextStyle(
                fontSize: 10,
                color: isOccupied ? Colors.white : Colors.white54,
                fontWeight: isOccupied ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Floating Vinyl Record DJ Music Player (Identical to user's uploaded screenshot)
  Widget _buildVinylRecordPlayer(
      MusicTrack currentTrack, InAppMusicService music) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E284A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: currentTrack.accentColor.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Spinning Vinyl Turntable Disc Animation
          RotationTransition(
            turns: music.isPlaying
                ? _vinylAnimCtrl
                : const AlwaysStoppedAnimation(0.0),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFFE2E8F0),
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                    Color(0xFF020617),
                  ],
                  stops: [0.15, 0.45, 0.85, 1.0],
                ),
                border: Border.all(color: currentTrack.accentColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: currentTrack.accentColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: currentTrack.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // 2. Track Title & Room Live Audio Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        currentTrack.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (currentTrack.isUserUploaded) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC4899),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('PHONE MP3',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ],
                  ],
                ),
                Text(
                  music.isPlaying
                      ? '🎵 Playing Live in Room for all members'
                      : 'Room music paused',
                  style: TextStyle(
                    fontSize: 10,
                    color: music.isPlaying
                        ? currentTrack.accentColor
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // 3. Play / Pause Button
          IconButton(
            icon: Icon(
              music.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 32,
            ),
            onPressed: () {
              final currentUserName = AuthService().currentUser?.name;
              if (!VoiceRoomManager().canControlMusic(currentUserName)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        '🔒 Only Room Host or assigned Admins can control room music.'),
                    backgroundColor: Colors.redAccent,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              music.toggleMusic();
            },
          ),

          // 4. Next Track Button
          IconButton(
            icon: const Icon(Icons.skip_next_rounded,
                color: Colors.white, size: 26),
            onPressed: () {
              final currentUserName = AuthService().currentUser?.name;
              if (!VoiceRoomManager().canControlMusic(currentUserName)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        '🔒 Only Room Host or assigned Admins can change tracks.'),
                    backgroundColor: Colors.redAccent,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              final nextIndex =
                  (music.currentTrackIndex + 1) % music.tracks.length;
              music.selectTrack(nextIndex);
            },
          ),

          // 5. Music Store & Upload Menu
          IconButton(
            icon: const Icon(Icons.queue_music_rounded,
                color: AppColors.accentCyan, size: 24),
            tooltip: 'Choose / Upload Music',
            onPressed: () {
              final currentUserName = AuthService().currentUser?.name;
              if (!VoiceRoomManager().canControlMusic(currentUserName)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        '🔒 Only Room Host or assigned Admins can choose or upload music.'),
                    backgroundColor: Colors.redAccent,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              MusicPlayerSheet.show(context);
            },
          ),

          // 6. Close / Minimize Button
          GestureDetector(
            onTap: () {
              setState(() {
                _isVinylPlayerVisible = false;
              });
            },
            child: const Icon(Icons.close_rounded,
                color: Colors.white54, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildChatStream() {
    return ListView.builder(
      controller: _chatScrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];

        // 1. Join Room Notice Banner
        if (msg.isJoinAnnouncement) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => UserProfileDialog.show(
                    context,
                    name: msg.senderName,
                    avatarColor: msg.senderColor,
                  ),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: msg.senderColor,
                    child: Text(
                      msg.senderName.isNotEmpty ? msg.senderName[0] : 'U',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${msg.senderName} ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 12),
                        ),
                        TextSpan(
                          text: msg.message,
                          style: const TextStyle(
                              color: Color(0xFFFDE047), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                // Invite to Mic button
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Invited ${msg.senderName} to Mic Seat!'),
                        backgroundColor: AppColors.surfaceLight,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic_none_rounded,
                            size: 12, color: Colors.white),
                        SizedBox(width: 3),
                        Text('Invite',
                            style:
                                TextStyle(fontSize: 10, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 2. Gift Announcement Banner (Golden VIP Party banner)
        if (msg.isGiftAnnouncement) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  const Color(0xFFEC4899).withValues(alpha: 0.25),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.trophyGold.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Text(msg.gift?.icon ?? '🎁',
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${msg.senderName} ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.trophyGold,
                              fontSize: 12),
                        ),
                        TextSpan(
                          text: msg.message,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 3. Regular Player Chat Bubble
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => UserProfileDialog.show(
                  context,
                  name: msg.senderName,
                  avatarColor: msg.senderColor,
                  level: msg.level,
                ),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: msg.senderColor,
                  child: Text(
                    msg.senderName.isNotEmpty ? msg.senderName[0] : 'P',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => UserProfileDialog.show(
                            context,
                            name: msg.senderName,
                            avatarColor: msg.senderColor,
                            level: msg.level,
                          ),
                          child: Text(
                            msg.senderName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Lv.${msg.level}',
                            style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg.message,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.black.withValues(alpha: 0.5),
      child: Row(
        children: [
          // 1. Speaker Toggle (Mute/Unmute Room Audio)
          IconButton(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            icon: Icon(
              _isRoomAudioMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              color: _isRoomAudioMuted ? Colors.redAccent : Colors.white,
              size: 22,
            ),
            tooltip: 'Room Audio',
            onPressed: () {
              setState(() {
                _isRoomAudioMuted = !_isRoomAudioMuted;
                InAppMusicService().setVolume(_isRoomAudioMuted ? 0.0 : 0.8);
              });
            },
          ),
          const SizedBox(width: 4),

          // 2. Microphone Mute / Unmute Toggle
          IconButton(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            icon: Icon(
              _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: _isMicMuted ? Colors.redAccent : AppColors.accentCyan,
              size: 22,
            ),
            tooltip: 'My Mic',
            onPressed: () {
              setState(() {
                _isMicMuted = !_isMicMuted;
                final user = AuthService().currentUser;
                final myIdx =
                    _seats.indexWhere((s) => s.userName == user?.name);
                if (myIdx != -1) {
                  _seats[myIdx] = _seats[myIdx]
                      .copyWith(isMuted: _isMicMuted, isSpeaking: !_isMicMuted);
                }
              });
              GameSoundService.buttonTap();
            },
          ),
          const SizedBox(width: 4),

          // 3. Emoji Reactions Button
          IconButton(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.mood_rounded,
                color: Color(0xFFFDE047), size: 22),
            tooltip: 'Reactions',
            onPressed: () {
              _addFloatingReaction(
                  ['❤️', '🔥', '🎉', '🎲', '👑'][Random().nextInt(5)]);
            },
          ),
          const SizedBox(width: 6),

          // 4. Chat Input Field
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _chatInputCtrl,
                style: const TextStyle(fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Say something in room...',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded,
                        size: 16, color: AppColors.accentCyan),
                    onPressed: () => _sendMessage(_chatInputCtrl.text),
                  ),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),

          const SizedBox(width: 6),

          // 5. Gifts Shop Button with Bonus Badge
          GestureDetector(
            onTap: _showGiftDrawer,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEC4899)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.card_giftcard_rounded,
                  color: Colors.white, size: 22),
            ),
          ),

          const SizedBox(width: 6),

          // 6. Mini-Game Launcher Button (Play Tic-Tac-Toe, Ludo, Carrom directly in room!)
          IconButton(
            icon: const Icon(Icons.casino_rounded,
                color: AppColors.coinAmber, size: 26),
            tooltip: 'Launch ${widget.room.gameTitle}',
            onPressed: _launchRoomGame,
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedReaction(FloatingReaction reaction) {
    return TweenAnimationBuilder<double>(
      key: reaction.key,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1800),
      builder: (context, val, _) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final dy = screenHeight * (0.85 - val * 0.6);
        final dx = screenWidth * reaction.startX + sin(val * pi * 3) * 15;
        final opacity = (1.0 - val).clamp(0.0, 1.0);

        return Positioned(
          top: dy,
          left: dx,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: 0.8 + val * 0.6,
              child: Text(reaction.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGiftCelebrationOverlay() {
    final gift = _activeGiftOverlay!;
    final sender = _activeGiftSender ?? 'Player';

    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _giftAnimCtrl,
          builder: (context, _) {
            final t = _giftAnimCtrl.value;
            final scale = (sin(t * pi) * 1.3).clamp(0.0, 1.6);
            final opacity = (sin(t * pi) * 1.5).clamp(0.0, 1.0);

            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        gift.glowColor.withValues(alpha: 0.95),
                        const Color(0xFF1E1B4B).withValues(alpha: 0.95),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: gift.glowColor.withValues(alpha: 0.7),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(gift.icon, style: const TextStyle(fontSize: 72)),
                      const SizedBox(height: 10),
                      Text(
                        gift.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$sender showered ${widget.room.hostName}!',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
