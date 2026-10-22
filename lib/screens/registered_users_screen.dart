import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/aws_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_profile_dialog.dart';

class RegisteredUsersScreen extends StatefulWidget {
  const RegisteredUsersScreen({super.key});

  @override
  State<RegisteredUsersScreen> createState() => _RegisteredUsersScreenState();
}

class _RegisteredUsersScreenState extends State<RegisteredUsersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    final results = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    // 1. Currently authenticated user
    final current = AuthService().currentUser;
    if (current != null) {
      seenIds.add(current.id);
      results.add({
        'id': current.id,
        'securityId': current.id,
        'name': current.name,
        'gamerTag': current.tag,
        'email': current.email,
        'phoneNumber': current.phoneNumber ?? 'Not set',
        'level': current.level,
        'coins': current.coins,
        'trophies': current.trophies,
        'profilePhoto': current.profilePhoto,
        'isCurrent': true,
      });
    }

    // 2. Locally registered users
    for (final u in AuthService().registeredUsers) {
      if (!seenIds.contains(u.id)) {
        seenIds.add(u.id);
        results.add({
          'id': u.id,
          'securityId': u.id,
          'name': u.name,
          'gamerTag': u.tag,
          'email': u.email,
          'phoneNumber': u.phoneNumber ?? 'Not set',
          'level': u.level,
          'coins': u.coins,
          'trophies': u.trophies,
          'profilePhoto': u.profilePhoto,
          'isCurrent': current?.id == u.id,
        });
      }
    }

    // 3. Cloud users from AWS DynamoDB / cache
    try {
      final cloudUsers = await AwsStorageService.searchUsers('');
      for (final u in cloudUsers) {
        final id = (u['id'] ?? u['securityId'] ?? u['userId'] ?? '').toString();
        if (id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          results.add({
            'id': id,
            'securityId': id,
            'name': u['name'] ?? 'Player',
            'gamerTag': u['gamerTag'] ?? u['tag'] ?? '@player',
            'email': u['email'] ?? 'Registered User',
            'phoneNumber': u['phoneNumber'] ?? 'Registered',
            'level': (u['level'] as num?)?.toInt() ?? 1,
            'coins': (u['coins'] as num?)?.toInt() ?? 500,
            'trophies': (u['trophies'] as num?)?.toInt() ?? 0,
            'profilePhoto': u['profilePhoto'],
            'isCurrent': false,
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _users = results;
        _isLoading = false;
      });
    }
  }

  ImageProvider? _resolvePhoto(String? photo) {
    if (photo == null || photo.isEmpty) return null;
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return NetworkImage(photo);
    }
    try {
      final cleanBase64 = photo.contains(',') ? photo.split(',').last : photo;
      return MemoryImage(base64Decode(cleanBase64));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _users.where((u) {
      if (_searchFilter.isEmpty) return true;
      final q = _searchFilter.toLowerCase().replaceAll('@', '');
      final name = (u['name'] ?? '').toString().toLowerCase();
      final tag = (u['gamerTag'] ?? '').toString().toLowerCase().replaceAll('@', '');
      final secId = (u['securityId'] ?? u['id'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phoneNumber'] ?? '').toString().toLowerCase();

      return name.contains(q) ||
          tag.contains(q) ||
          secId.contains(q) ||
          email.contains(q) ||
          phone.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Text(
              'Registered Players',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Text(
                '${_users.length}',
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh User List',
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E1B4B),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: (val) {
                  setState(() => _searchFilter = val.trim());
                },
                decoration: InputDecoration(
                  hintText: 'Search by Gamer Tag, Security ID, Name...',
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.accentCyan, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white54, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchFilter = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.accentCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.accentCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.accentCyan,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            // Users List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accentCyan),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      color: AppColors.accentCyan,
                      child: filtered.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primaryPurple
                                              .withValues(alpha: 0.15),
                                        ),
                                        child: const Icon(
                                          Icons.person_search_rounded,
                                          size: 48,
                                          color: AppColors.accentCyan,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchFilter.isEmpty
                                            ? 'No Registered Players Found'
                                            : 'No player matches "$_searchFilter"',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 32),
                                        child: Text(
                                          'Registered players appear here automatically after signing up.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final u = filtered[i];
                                final name = u['name']?.toString() ?? 'Player';
                                final tag = u['gamerTag']?.toString() ??
                                    '@${name.toLowerCase()}';
                                final secId = u['securityId']?.toString() ??
                                    u['id']?.toString() ??
                                    '01----';
                                final email = u['email']?.toString() ?? '';
                                final phone = u['phoneNumber']?.toString() ?? '';
                                final level = (u['level'] as num?)?.toInt() ?? 1;
                                final coins = (u['coins'] as num?)?.toInt() ?? 500;
                                final trophies =
                                    (u['trophies'] as num?)?.toInt() ?? 0;
                                final photo = u['profilePhoto']?.toString();
                                final isCurrent = u['isCurrent'] == true;
                                final photoImg = _resolvePhoto(photo);
                                final initial = name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : 'P';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1E284A),
                                        Color(0xFF131738)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isCurrent
                                          ? AppColors.onlineGreen
                                          : AppColors.accentCyan
                                              .withValues(alpha: 0.3),
                                      width: isCurrent ? 1.5 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () => UserProfileDialog.show(
                                        context,
                                        name: name,
                                        tag: tag,
                                        securityId: secId,
                                        profilePhoto: photo,
                                        level: level,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Avatar
                                            Stack(
                                              children: [
                                                CircleAvatar(
                                                  radius: 26,
                                                  backgroundColor:
                                                      AppColors.primaryPurple,
                                                  backgroundImage: photoImg,
                                                  child: photoImg != null
                                                      ? null
                                                      : Text(
                                                          initial,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                ),
                                                Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 4,
                                                        vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.trophyGold,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      'Lv.$level',
                                                      style: const TextStyle(
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(width: 12),

                                            // Details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          name,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      if (isCurrent) ...[
                                                        const SizedBox(
                                                            width: 6),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 1),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: AppColors
                                                                .onlineGreen
                                                                .withValues(
                                                                    alpha: 0.2),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                            border: Border.all(
                                                              color: AppColors
                                                                  .onlineGreen,
                                                              width: 0.8,
                                                            ),
                                                          ),
                                                          child: const Text(
                                                            'YOU',
                                                            style: TextStyle(
                                                              color: AppColors
                                                                  .onlineGreen,
                                                              fontSize: 8,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),

                                                  const SizedBox(height: 3),

                                                  // Tag & Security ID Row
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: [
                                                      Text(
                                                        tag,
                                                        style: const TextStyle(
                                                          color: AppColors
                                                              .primaryBlueLight,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontFamily:
                                                              'monospace',
                                                        ),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 1),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppColors
                                                              .accentCyan
                                                              .withValues(
                                                                  alpha: 0.15),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                          border: Border.all(
                                                            color: AppColors
                                                                .accentCyan
                                                                .withValues(
                                                                    alpha: 0.4),
                                                            width: 0.8,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .security_rounded,
                                                              size: 10,
                                                              color: AppColors
                                                                  .accentCyan,
                                                            ),
                                                            const SizedBox(
                                                                width: 3),
                                                            Text(
                                                              secId,
                                                              style:
                                                                  const TextStyle(
                                                                color: AppColors
                                                                    .accentCyan,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                letterSpacing:
                                                                    0.5,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  const SizedBox(height: 6),

                                                  // Contact Info
                                                  if (email.isNotEmpty ||
                                                      phone.isNotEmpty)
                                                    Text(
                                                      [
                                                        if (email.isNotEmpty)
                                                          email,
                                                        if (phone.isNotEmpty &&
                                                            phone != 'Not set')
                                                          phone
                                                      ].join(' • '),
                                                      style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 11,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),

                                                  const SizedBox(height: 6),

                                                  // Stats Row: Coins & Trophies
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .monetization_on_rounded,
                                                        size: 13,
                                                        color: AppColors
                                                            .coinAmber,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        '$coins',
                                                        style: const TextStyle(
                                                          color: AppColors
                                                              .coinAmber,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      const Icon(
                                                        Icons
                                                            .emoji_events_rounded,
                                                        size: 13,
                                                        color: AppColors
                                                            .trophyGold,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        '$trophies wins',
                                                        style: const TextStyle(
                                                          color: AppColors
                                                              .trophyGold,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: Colors.white30,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
