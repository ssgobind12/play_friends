import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../services/auth_service.dart';
import '../services/voice_room_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/friend_tile.dart';
import '../widgets/user_profile_dialog.dart';
import 'tic_tac_toe_screen.dart';

class FriendsScreen extends StatefulWidget {
  final VoidCallback onOpenChat;

  const FriendsScreen({
    super.key,
    required this.onOpenChat,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    VoiceRoomManager().syncFollowsFromServer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<FriendModel> _filterFriends(List<FriendModel> list) {
    return list.where((f) {
      return f.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.tag.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final allFriends = _filterFriends(AuthService().friends);
        final onlineFriends = allFriends.where((f) => f.isOnline).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Friends Squad'),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_rounded),
                tooltip: 'Add Friend',
                color: AppColors.primaryBlueLight,
                onPressed: () => _showAddFriendDialog(context),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryBlueLight,
              indicatorWeight: 3,
              labelColor: AppColors.primaryBlueLight,
              unselectedLabelColor: AppColors.textMuted,
              tabs: [
                Tab(text: 'All (${allFriends.length})'),
                Tab(text: 'Online (${onlineFriends.length})'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add Friend'),
            onPressed: () => _showAddFriendDialog(context),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search friends by name or tag...',
                      hintStyle: const TextStyle(
                          color: AppColors.textMuted, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textSecondary),
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: AppColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: AppColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: AppColors.primaryPurple, width: 1.5),
                      ),
                    ),
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFriendsList(allFriends, 'No friends added yet.'),
                      _buildFriendsList(
                          onlineFriends, 'No online friends right now.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendsList(List<FriendModel> list, String emptyMessage) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => VoiceRoomManager().syncFollowsFromServer(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryPurple.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  size: 36,
                  color: AppColors.primaryPurpleLight,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Squad is Empty',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add First Friend'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _showAddFriendDialog(context),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => VoiceRoomManager().syncFollowsFromServer(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final friend = list[index];
          return FriendTile(
            friend: friend,
            onTap: () => _showFriendProfile(context, friend),
            onInvite: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TicTacToeScreen()),
              );
            },
            onChat: widget.onOpenChat,
          );
        },
      ),
    );
  }

  void _showFriendProfile(BuildContext context, FriendModel friend) {
    UserProfileDialog.show(
      context,
      name: friend.name,
      tag: friend.tag,
      avatarColor: friend.avatarColor,
      level: friend.level,
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    final nameController = TextEditingController();
    final tagController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: AppColors.primaryBlueLight),
            SizedBox(width: 10),
            Text('Add Friend to Squad',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your friend\'s name and gamer tag:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Player Name',
                hintText: 'e.g. Marcus or Sarah',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tagController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Gamer Tag',
                hintText: 'e.g. @marcus_play',
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
              final name = nameController.text.trim();
              final tag = tagController.text.trim();
              if (name.isNotEmpty) {
                AuthService().addFriend(
                  name: name,
                  tag: tag.isNotEmpty ? tag : '@${name.toLowerCase()}',
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added $name to your Squad!'),
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
}
