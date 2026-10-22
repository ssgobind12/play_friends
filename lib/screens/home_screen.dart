import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/backend_api_service.dart';
import '../services/voice_room_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/music_player_sheet.dart';
import '../widgets/user_profile_dialog.dart';
import 'voice_party_room_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigateTab;
  final VoidCallback onOpenRooms;
  final VoidCallback onOpenChat;

  const HomeScreen({
    super.key,
    required this.onNavigateTab,
    required this.onOpenRooms,
    required this.onOpenChat,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await BackendApiService().searchUsers(cleanQ);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
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
            Icon(Icons.person_add_alt_1_rounded,
                color: AppColors.primaryBlueLight),
            SizedBox(width: 10),
            Text('Add New Friend',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                final tag = tagCtrl.text.trim().isNotEmpty
                    ? tagCtrl.text.trim()
                    : '@${nameCtrl.text.trim().toLowerCase()}';
                AuthService().addFriend(
                  name: nameCtrl.text.trim(),
                  tag: tag,
                );
                VoiceRoomManager().toggleFollowUser(nameCtrl.text.trim(), tag: tag);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Added ${nameCtrl.text.trim()} to your Squad!'),
                    backgroundColor: AppColors.onlineGreen,
                  ),
                );
              }
            },
            child:
                const Text('Add Friend', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  ImageProvider? _resolvePhoto(String? photo) {
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
      listenable: AuthService(),
      builder: (context, _) {
        final auth = AuthService();
        final user = auth.currentUser;
        final userName = user?.name.split(' ').first ?? 'Player';
        final userInitial = user?.avatarInitial ?? 'P';
        final userColor = user?.avatarColor ?? AppColors.primaryPurple;
        final userProfilePhoto = user?.profilePhoto;
        final isBase64Photo = userProfilePhoto != null &&
            userProfilePhoto.startsWith('data:image');
        final hasNetworkPhoto = userProfilePhoto != null &&
            (userProfilePhoto.startsWith('http://') ||
                userProfilePhoto.startsWith('https://'));
        ImageProvider? topAvatarImage;
        if (isBase64Photo) {
          topAvatarImage =
              MemoryImage(base64Decode(userProfilePhoto.split(',')[1]));
        } else if (hasNetworkPhoto) {
          topAvatarImage = NetworkImage(userProfilePhoto);
        }
        final userLevel = user?.level ?? 1;
        final userCoins = user?.coins ?? 500;
        final friends = auth.friends;
        final liveRooms = auth.activeRooms;

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
                          onTap: () => widget.onNavigateTab(3),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: userColor,
                                backgroundImage: topAvatarImage,
                                child: topAvatarImage != null
                                    ? null
                                    : Text(
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
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
                        const SizedBox(width: 4),
                        IconButton(
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.music_note_rounded, size: 22),
                          color: AppColors.primaryBlueLight,
                          tooltip: 'Music Store & Upload',
                          onPressed: () => MusicPlayerSheet.show(context),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 22),
                          color: AppColors.primaryPurpleLight,
                          tooltip: 'Social Chat',
                          onPressed: widget.onOpenChat,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Search Option for Gamer Tag (@tag) or Security ID (PF-USR)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _searchCtrl.text.isNotEmpty
                              ? AppColors.primaryBlueLight
                              : AppColors.cardBorder,
                          width: 1.2,
                        ),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13.5),
                        onChanged: (val) => _performSearch(val),
                        decoration: InputDecoration(
                          hintText:
                              'Search by Gamer Tag (@tag) or Security ID...',
                          hintStyle: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12.5),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: AppColors.primaryBlueLight),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      color: Colors.white70, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _performSearch('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  // Instant Search Results Dropdown / Card
                  if (_searchResults.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        children: _searchResults
                            .map((u) => _buildUserSearchResultCard(u))
                            .toList(),
                      ),
                    )
                  else if (_searchCtrl.text.trim().isNotEmpty && !_isSearching)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_off_rounded,
                                color: AppColors.textMuted, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No player found for "${_searchCtrl.text.trim()}". Check Gamer Tag or Security ID.',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Dedicated Music Store & Upload Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InkWell(
                      onTap: () => MusicPlayerSheet.show(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E1065), Color(0xFF1E1B4B)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.music_note_rounded,
                                  color: Color(0xFFC084FC), size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🎵 Music Store & Custom Upload',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.white),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Upload custom songs from device or play game music',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Upload / Play',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

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
                            onTap: widget.onOpenRooms,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionTile(
                            icon: Icons.login_rounded,
                            title: 'Join Room',
                            subtitle: 'Enter 6-digit code',
                            color: AppColors.primaryBlueLight,
                            onTap: widget.onOpenRooms,
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
                              color: AppColors.primaryPurple
                                  .withValues(alpha: 0.2),
                            ),
                            child: const Icon(Icons.person_add_rounded,
                                color: AppColors.primaryPurpleLight),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Squad is empty',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                Text(
                                    'Follow or add friends to see them here!',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _showAddFriendModal(context),
                            child: const Text('Add',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
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
                          return GestureDetector(
                            onTap: () {
                              UserProfileDialog.show(
                                context,
                                name: friend.name,
                                tag: friend.tag,
                                avatarColor: friend.avatarColor,
                                level: friend.level,
                              );
                            },
                            child: Container(
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
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Who is Live Now Section (Party Voice Rooms)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444), // Live Red
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFEF4444),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Who is Live Now',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.explore_rounded,
                              size: 16, color: AppColors.accentCyan),
                          label: const Text('View All',
                              style: TextStyle(
                                  color: AppColors.accentCyan,
                                  fontWeight: FontWeight.bold)),
                          onPressed: widget.onOpenRooms,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (liveRooms.isEmpty)
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
                              color: AppColors.accentCyan.withValues(alpha: 0.2),
                            ),
                            child: const Icon(
                                Icons.radio_button_checked_rounded,
                                color: AppColors.accentCyan),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('No Live Rooms Active',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                Text(
                                    'Create a live party room to chat and play games with friends!',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onPressed: widget.onOpenRooms,
                            child: const Text('Host Room',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                    )
                  else ...[

                  // Horizontal Live Voice Hosts Avatars
                  SizedBox(
                    height: 98,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: liveRooms.length,
                      itemBuilder: (context, i) {
                        final room = liveRooms[i];
                        final hostImage = _resolvePhoto(room.hostPhoto);

                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      VoicePartyRoomScreen(room: room)),
                            );
                          },
                          child: Container(
                            width: 78,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFF06B6D4),
                                            width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF06B6D4)
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundColor: AppColors.primaryPurple,
                                      backgroundImage: hostImage,
                                      child: hostImage != null
                                          ? null
                                          : Text(
                                              room.hostName.isNotEmpty
                                                  ? room.hostName[0]
                                                  : 'H',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white),
                                            ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'LIVE',
                                          style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  room.hostName,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Vertical Live Party Rooms Feed
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: liveRooms.map((room) {
                        final hostImage = _resolvePhoto(room.hostPhoto);
                        final roomLevel =
                            LevelProgressionService.calculateLevel(
                                room.giftPoints);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E284A), Color(0xFF131738)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF06B6D4)
                                  .withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          VoicePartyRoomScreen(room: room)),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundColor:
                                              AppColors.primaryPurple,
                                          backgroundImage: hostImage,
                                          child: hostImage != null
                                              ? null
                                              : Text(
                                                  room.hostName.isNotEmpty
                                                      ? room.hostName[0]
                                                      : 'H',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                      fontSize: 18),
                                                ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text('LIVE',
                                                style: TextStyle(
                                                    fontSize: 7,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  room.gameTitle,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Colors.white),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryPurple
                                                      .withValues(alpha: 0.5),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'Lv.$roomLevel',
                                                  style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppColors.accentCyan),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Host: ${room.hostName} • ID: ${room.roomCode}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                  Icons.people_alt_rounded,
                                                  size: 12,
                                                  color: AppColors.accentCyan),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${room.currentPlayers}/${room.maxPlayers} in Room',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.accentCyan,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                              const SizedBox(width: 10),
                                              const Icon(
                                                  Icons.emoji_events_rounded,
                                                  size: 12,
                                                  color: AppColors.trophyGold),
                                              const SizedBox(width: 3),
                                              Text(
                                                '${room.giftPoints}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.trophyGold,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF06B6D4),
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  VoicePartyRoomScreen(
                                                      room: room)),
                                        );
                                      },
                                      child: const Text('Join Room',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildUserSearchResultCard(Map<String, dynamic> u) {
    final name = u['name']?.toString() ?? 'Player';
    final tag = u['gamerTag']?.toString() ?? '@${name.toLowerCase()}';
    final secId =
        u['securityId']?.toString() ?? u['id']?.toString() ?? 'PF-USR';
    final level = (u['level'] as num?)?.toInt() ?? 1;
    final photo = u['profilePhoto']?.toString();
    final hasPhoto = photo != null && photo.isNotEmpty;
    final followingCount = (u['followingCount'] as num?)?.toInt() ?? 5;
    final visitorsCount = (u['visitorsCount'] as num?)?.toInt() ?? 20;

    return ListenableBuilder(
      listenable: VoiceRoomManager(),
      builder: (context, _) {
        final vm = VoiceRoomManager();
        final isFollowing = vm.isFollowingUser(name);
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
        final followersCount = vm.getUserFollowers(name);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFollowing
                  ? AppColors.onlineGreen.withValues(alpha: 0.6)
                  : AppColors.primaryPurple.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => UserProfileDialog.show(
                  context,
                  name: name,
                  tag: tag,
                  profilePhoto: photo,
                  level: level,
                ),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryPurple,
                      backgroundImage:
                          hasPhoto ? _resolvePhoto(photo) : null,
                      child: hasPhoto
                          ? null
                          : Text(
                              initial,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 16),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.trophyGold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Lv.$level',
                          style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => UserProfileDialog.show(
                    context,
                    name: name,
                    tag: tag,
                    profilePhoto: photo,
                    level: level,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlueLight
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppColors.primaryBlueLight
                                      .withValues(alpha: 0.5),
                                  width: 0.8),
                            ),
                            child: Text(
                              secId,
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryBlueLight),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tag,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentCyan),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Followers: $followersCount • Following: $followingCount • Visitors: $visitorsCount',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing
                      ? AppColors.surfaceLight
                      : AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isFollowing
                        ? const BorderSide(
                            color: AppColors.onlineGreen, width: 1)
                        : BorderSide.none,
                  ),
                ),
                onPressed: () {
                  vm.toggleFollowUser(
                    name,
                    tag: tag,
                    profilePhoto: photo,
                    level: level,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isFollowing
                          ? 'Unfollowed $name'
                          : 'Following $name! Added to your Online Friends! ⭐'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                icon: Icon(
                  isFollowing
                      ? Icons.check_rounded
                      : Icons.person_add_rounded,
                  size: 13,
                  color:
                      isFollowing ? AppColors.onlineGreen : Colors.white,
                ),
                label: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isFollowing
                        ? AppColors.onlineGreen
                        : Colors.white,
                  ),
                ),
              ),
            ],
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
