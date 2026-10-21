import 'package:flutter/material.dart';
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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Player Profile'),
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
                        color: AppColors.primaryPurple.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: user?.avatarColor ?? AppColors.primaryPurple,
                              child: Text(
                                user?.avatarInitial ?? 'P',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (user?.isGuest == true)
                              Positioned(
                                bottom: 0,
                                right: 0,
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
                        user?.isGuest == true ? 'Guest Session' : 'Registered Player',
                        style: TextStyle(
                          color: user?.isGuest == true ? AppColors.coinAmber : AppColors.onlineGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
                      leading: const Icon(Icons.logout_rounded, color: AppColors.dangerRose),
                      title: const Text(
                        'Sign Out / Switch Account',
                        style: TextStyle(
                          color: AppColors.dangerRose,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Return to login screen or switch profiles',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.dangerRose),
                      onTap: () => _confirmSignOut(context),
                    ),
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
                    const Divider(height: 1, indent: 56, color: AppColors.coinAmber),
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
