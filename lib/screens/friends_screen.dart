import 'package:flutter/material.dart';
import '../data/sample_data.dart';
import '../models/friend_model.dart';
import '../theme/app_theme.dart';
import '../widgets/demo_banner.dart';
import '../widgets/friend_tile.dart';

class FriendsScreen extends StatefulWidget {
  final VoidCallback onOpenChat;

  const FriendsScreen({
    super.key,
    required this.onOpenChat,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<FriendModel> get _allFriends {
    return SampleData.friends.where((f) {
      return f.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.tag.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<FriendModel> get _onlineFriends {
    return _allFriends.where((f) => f.isOnline).toList();
  }

  @override
  Widget build(BuildContext context) {
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
            Tab(text: 'All (${_allFriends.length})'),
            Tab(text: 'Online (${_onlineFriends.length})'),
            const Tab(text: 'Requests (2)'),
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
            const DemoBanner(
              message: 'Social squad profiles are demo mocks. Adding friends and inviting players triggers simulated events.',
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search friends by name or tag...',
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
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: All Friends
                  _buildFriendsList(_allFriends),

                  // Tab 2: Online Friends
                  _buildFriendsList(_onlineFriends),

                  // Tab 3: Pending Friend Requests
                  _buildRequestsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList(List<FriendModel> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'No friends found',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final friend = list[index];
        return FriendTile(
          friend: friend,
          onTap: () => _showFriendProfile(context, friend),
          onInvite: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invited ${friend.name} to game! (Simulated)'),
                backgroundColor: AppColors.surfaceLight,
              ),
            );
          },
          onChat: widget.onOpenChat,
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    final sampleRequests = [
      {'name': 'Zack Snyder', 'tag': '@zack_s', 'initial': 'Z', 'level': 8},
      {'name': 'Natasha Roman', 'tag': '@nat_r', 'initial': 'N', 'level': 17},
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sampleRequests.length,
      itemBuilder: (context, index) {
        final req = sampleRequests[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryPurple,
                radius: 22,
                child: Text(
                  req['initial'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req['name'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${req['tag']} • LVL ${req['level']}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Accepted ${req['name']}! (Demo)'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(60, 32),
                ),
                child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFriendProfile(BuildContext context, FriendModel friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: friend.avatarColor,
              child: Text(
                friend.initial,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              friend.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              friend.tag,
              style: const TextStyle(color: AppColors.primaryBlueLight, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniStat('Level', '${friend.level}', AppColors.trophyGold),
                  Container(width: 1, height: 24, color: AppColors.cardBorder),
                  _miniStat('Status', friend.isOnline ? 'Online' : 'Offline',
                      friend.isOnline ? AppColors.onlineGreen : AppColors.textMuted),
                  Container(width: 1, height: 24, color: AppColors.cardBorder),
                  _miniStat('Favorite', friend.favoriteGame.split(' ').first, AppColors.primaryPurpleLight),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Send Message'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      widget.onOpenChat();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.sports_esports_rounded, size: 18),
                    label: const Text('Invite to Play'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invited ${friend.name} to duel! (Demo)')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: AppColors.primaryBlueLight),
            SizedBox(width: 10),
            Text('Add New Friend'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your friend\'s 6-character player tag or code:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g. PF-9914 or @gamertag',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.share_rounded, size: 18, color: AppColors.primaryPurpleLight),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your code: PF-ALEX-14',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Friend code copied to clipboard! (Simulated)')),
                      );
                    },
                    child: const Text('Copy', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.trim();
              Navigator.of(ctx).pop();
              if (code.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Friend request sent to $code! (Simulated)'),
                  ),
                );
              }
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }
}
