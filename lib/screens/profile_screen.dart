import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/game_sound_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _notificationsEnabled = true;

  IconData _getAvatarIcon(String key) {
    switch (key) {
      case 'icon:ninja':
        return Icons.sports_martial_arts_rounded;
      case 'icon:arcade':
        return Icons.videogame_asset_rounded;
      case 'icon:dragon':
        return Icons.local_fire_department_rounded;
      case 'icon:space':
        return Icons.rocket_launch_rounded;
      case 'icon:shield':
        return Icons.shield_rounded;
      case 'icon:crown':
        return Icons.military_tech_rounded;
      case 'icon:bolt':
        return Icons.bolt_rounded;
      case 'icon:wizard':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final user = AuthService().currentUser;
        final currentWins = user?.totalWins ?? 0;
        final currentLevel = user?.level ?? 1;
        final currentXp = user?.xp ?? 0;
        final levelTargetWins = currentLevel * 4;
        final winProgress = (currentWins % 4) / 4.0;
        final profilePhoto = user?.profilePhoto;
        final hasNetworkPhoto = profilePhoto != null &&
            (profilePhoto.startsWith('http://') || profilePhoto.startsWith('https://'));
        final hasIconPhoto = profilePhoto != null && profilePhoto.startsWith('icon:');

        return Scaffold(
          appBar: AppBar(
            title: const Text('Player Profile'),
            actions: [
              if (user != null && !user.isGuest)
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded),
                  tooltip: 'Edit Profile',
                  onPressed: () => _showEditProfileDialog(context, user),
                ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Player Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E2648), Color(0xFF121933)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: user?.isAdmin == true
                            ? AppColors.coinAmber.withValues(alpha: 0.6)
                            : AppColors.primaryPurple.withValues(alpha: 0.35),
                        width: user?.isAdmin == true ? 1.8 : 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Avatar with Edit Button
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: () => _showPhotoPicker(context),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: user?.avatarColor ?? AppColors.primaryPurple,
                                backgroundImage: hasNetworkPhoto ? NetworkImage(profilePhoto) : null,
                                child: hasNetworkPhoto
                                    ? null
                                    : hasIconPhoto
                                        ? Icon(
                                            _getAvatarIcon(profilePhoto),
                                            size: 44,
                                            color: Colors.white,
                                          )
                                        : Text(
                                            user?.avatarInitial ?? 'P',
                                            style: const TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _showPhotoPicker(context),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryPurple,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            if (user?.isGuest == true)
                              Positioned(
                                top: 0,
                                left: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.coinAmber,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'GUEST',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user?.name ?? 'Player',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.tag ?? '@player',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primaryBlueLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Security ID Badge (Always starts with 01)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.security_rounded, size: 13, color: AppColors.accentCyan),
                              const SizedBox(width: 5),
                              Text(
                                'Security ID: ${user?.id ?? "01----"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentCyan,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Golden Admin Banner if user is Admin
                        if (user?.isAdmin == true) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.coinAmber.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.black),
                                SizedBox(width: 6),
                                Text(
                                  '👑 SYSTEM ADMIN • ALL GAMES UNLOCKED',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        // Level & XP Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Level $currentLevel',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.trophyGold,
                              ),
                            ),
                            Text(
                              '$currentXp XP • $currentWins / $levelTargetWins Wins',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: winProgress == 0 && currentWins > 0 ? 1.0 : winProgress,
                            backgroundColor: AppColors.surfaceLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurpleLight),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Statistics Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.sports_esports_rounded,
                          value: '${user?.totalMatches ?? 0}',
                          label: 'Matches Played',
                          color: AppColors.primaryBlueLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.pie_chart_rounded,
                          value: '${(user?.winRate ?? 0).toStringAsFixed(1)}%',
                          label: 'Win Rate',
                          color: AppColors.onlineGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.emoji_events_rounded,
                          value: '${user?.trophies ?? 0}',
                          label: 'Trophies Won',
                          color: AppColors.trophyGold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.monetization_on_rounded,
                          value: '${user?.coins ?? 0}',
                          label: 'Game Coins',
                          color: AppColors.coinAmber,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Account & Session Section
                  Material(
                    color: AppColors.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.cardBorder, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Account & Session',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.badge_rounded, color: AppColors.primaryPurpleLight),
                          title: const Text('Account Status'),
                          subtitle: Text(
                            user?.isAdmin == true
                                ? '👑 Administrator Account'
                                : (user?.isGuest == true ? 'Guest Session' : 'Registered Player'),
                            style: TextStyle(
                              color: user?.isAdmin == true
                                  ? AppColors.coinAmber
                                  : (user?.isGuest == true ? AppColors.coinAmber : AppColors.onlineGreen),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (user != null && !user.isGuest) ...[
                          const Divider(height: 1, indent: 56, color: AppColors.cardBorder),
                          ListTile(
                            leading: const Icon(Icons.edit_rounded, color: AppColors.primaryBlueLight),
                            title: const Text('Edit Profile Details'),
                            subtitle: const Text(
                              'Change your player name and gamer tag',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                            onTap: () => _showEditProfileDialog(context, user),
                          ),
                          const Divider(height: 1, indent: 56, color: AppColors.cardBorder),
                          ListTile(
                            leading: const Icon(Icons.add_a_photo_rounded, color: AppColors.accentCyan),
                            title: const Text('Player Avatar / Photo'),
                            subtitle: const Text(
                              'Upload or change your gamer avatar photo',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                            onTap: () => _showPhotoPicker(context),
                          ),
                        ],
                        if (user?.email != null && user!.email.isNotEmpty) ...[
                          const Divider(height: 1, indent: 56, color: AppColors.cardBorder),
                          ListTile(
                            leading: const Icon(Icons.email_rounded, color: AppColors.primaryBlueLight),
                            title: const Text('Email Address'),
                            subtitle: Text(
                              user.email,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        ],
                        if (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty) ...[
                          const Divider(height: 1, indent: 56, color: AppColors.cardBorder),
                          ListTile(
                            leading: const Icon(Icons.phone_android_rounded, color: AppColors.coinAmber),
                            title: const Text('Verified Phone'),
                            subtitle: Text(
                              '${user.countryFlag} ${user.countryCode} ${user.phoneNumber}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        ],
                        const Divider(height: 1, indent: 56, color: AppColors.cardBorder),
                        ListTile(
                          leading: const Icon(Icons.logout_rounded, color: AppColors.primaryPurpleLight),
                          title: const Text(
                            'Sign Out / Switch Account',
                            style: TextStyle(
                              color: AppColors.primaryPurpleLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Return to login screen or switch profiles',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          onTap: () => _confirmSignOut(context),
                        ),
                        // Dedicated "Delete My Account" option for the active user
                        if (user != null && !user.isGuest) ...[
                          const Divider(height: 1, indent: 56, color: AppColors.cardBorder),
                          ListTile(
                            leading: const Icon(Icons.delete_forever_rounded, color: AppColors.dangerRose),
                            title: const Text(
                              'Delete My Account',
                              style: TextStyle(
                                color: AppColors.dangerRose,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: const Text(
                              'Permanently delete only your account and game progress',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.dangerRose),
                            onTap: () => _confirmDeleteAccount(context, user),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Settings Section
                  Material(
                    color: AppColors.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.cardBorder, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Game Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        SwitchListTile(
                          secondary: const Icon(Icons.volume_up_rounded, color: AppColors.primaryPurpleLight),
                          title: const Text('Sound Effects'),
                          value: _soundEnabled,
                          activeThumbColor: AppColors.primaryPurple,
                          onChanged: (val) {
                            setState(() {
                              _soundEnabled = val;
                              GameSoundService.soundEnabled = val;
                            });
                          },
                        ),
                        const Divider(height: 1, indent: 56, color: AppColors.cardBorder),
                        SwitchListTile(
                          secondary: const Icon(Icons.vibration_rounded, color: AppColors.primaryBlueLight),
                          title: const Text('Haptic Vibration'),
                          value: _hapticsEnabled,
                          activeThumbColor: AppColors.primaryBlue,
                          onChanged: (val) => setState(() => _hapticsEnabled = val),
                        ),
                        const Divider(height: 1, indent: 56, color: AppColors.cardBorder),
                        SwitchListTile(
                          secondary: const Icon(Icons.notifications_rounded, color: AppColors.coinAmber),
                          title: const Text('Notifications'),
                          value: _notificationsEnabled,
                          activeThumbColor: AppColors.coinAmber,
                          onChanged: (val) => setState(() => _notificationsEnabled = val),
                        ),
                        const Divider(height: 1, indent: 56, color: AppColors.cardBorder),
                        ListTile(
                          leading: const Icon(Icons.gavel_rounded, color: AppColors.textSecondary),
                          title: const Text('Fair Play & Disclaimer'),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          onTap: () => _showAboutDialog(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoPicker(BuildContext context) {
    final urlController = TextEditingController();
    const avatarPresets = [
      {'key': 'icon:ninja', 'label': 'Cyber Ninja', 'icon': Icons.sports_martial_arts_rounded, 'color': Color(0xFF06B6D4)},
      {'key': 'icon:dragon', 'label': 'Fire Dragon', 'icon': Icons.local_fire_department_rounded, 'color': Color(0xFFEF4444)},
      {'key': 'icon:arcade', 'label': 'Retro Gamer', 'icon': Icons.videogame_asset_rounded, 'color': Color(0xFF8B5CF6)},
      {'key': 'icon:space', 'label': 'Cosmic Pilot', 'icon': Icons.rocket_launch_rounded, 'color': Color(0xFFEC4899)},
      {'key': 'icon:crown', 'label': 'Champion King', 'icon': Icons.military_tech_rounded, 'color': Color(0xFFF59E0B)},
      {'key': 'icon:shield', 'label': 'Guardian Knight', 'icon': Icons.shield_rounded, 'color': Color(0xFF10B981)},
      {'key': 'icon:bolt', 'label': 'Thunder Striker', 'icon': Icons.bolt_rounded, 'color': Color(0xFF3B82F6)},
      {'key': 'icon:wizard', 'label': 'Neon Mystic', 'icon': Icons.auto_awesome_rounded, 'color': Color(0xFFA855F7)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.photo_camera_rounded, color: AppColors.primaryBlueLight),
                  SizedBox(width: 10),
                  Text(
                    'Choose Player Avatar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a gamer avatar badge or enter a custom photo image URL:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              // Preset Avatar Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: avatarPresets.length,
                itemBuilder: (context, i) {
                  final preset = avatarPresets[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      AuthService().updateProfilePhoto(preset['key'] as String);
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Avatar updated to ${preset['label']}!'),
                          backgroundColor: AppColors.onlineGreen,
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (preset['color'] as Color).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: preset['color'] as Color,
                            child: Icon(preset['icon'] as IconData, color: Colors.white, size: 22),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            preset['label'] as String,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('Or Enter Photo URL:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: urlController,
                      decoration: InputDecoration(
                        hintText: 'https://example.com/avatar.png',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.cardBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
                    onPressed: () {
                      final url = urlController.text.trim();
                      if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
                        AuthService().updateProfilePhoto(url);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile photo updated successfully!'),
                            backgroundColor: AppColors.onlineGreen,
                          ),
                        );
                      }
                    },
                    child: const Text('Save Photo'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Option to remove custom photo
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reset to Default Initial'),
                  onPressed: () {
                    AuthService().updateProfilePhoto(null);
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileDialog(BuildContext context, UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final tagCtrl = TextEditingController(text: user.tag);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppColors.primaryBlueLight),
            SizedBox(width: 10),
            Text('Edit Profile Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tagCtrl,
              decoration: const InputDecoration(
                labelText: 'Gamer Tag',
                hintText: '@username',
                border: OutlineInputBorder(),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                AuthService().updateProfileDetails(
                  name: nameCtrl.text.trim(),
                  tag: tagCtrl.text.trim(),
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile details updated!'),
                    backgroundColor: AppColors.onlineGreen,
                  ),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.dangerRose, size: 28),
            SizedBox(width: 10),
            Text('Delete Account?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete your account (ID: ${user.id})?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            const Text(
              '• Only your active account will be deleted.\n• All your game progression, stats, coins, and unlocks will be permanently removed.\n• This action cannot be reversed.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              AuthService().deleteCurrentUser();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Account ${user.id} has been permanently deleted.'),
                  backgroundColor: AppColors.dangerRose,
                ),
              );
            },
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.dangerRose),
            SizedBox(width: 10),
            Text('Sign Out?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of Play Friends? You can sign back in anytime or continue as guest.',
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              AuthService().logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.primaryBlueLight),
            SizedBox(width: 10),
            Text('About Play Friends'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Play Friends is an Android-first social gaming application.',
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            SizedBox(height: 12),
            Text(
              'Legal & Fair Play Policy:',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPurpleLight),
            ),
            SizedBox(height: 4),
            Text(
              '• Strictly non-gambling and free-to-play.\n• No real-money betting, cash prizes, or in-app purchases.\n• Offline duels and local rooms available.\n• All coins and trophies are strictly in-game entertainment rewards.',
              style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
