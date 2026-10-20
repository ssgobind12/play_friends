import 'package:flutter/material.dart';
import '../config/brevo_config.dart';
import '../services/auth_service.dart';
import '../services/brevo_email_service.dart';
import '../theme/app_theme.dart';
import '../widgets/demo_banner.dart';

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
    final user = AuthService().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'App & Legal Info',
            onPressed: () => _showAboutDialog(context),
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
                          'Level ${user?.level ?? 1}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.trophyGold,
                          ),
                        ),
                        const Text(
                          '7,420 / 10,000 XP',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: const LinearProgressIndicator(
                        value: 0.742,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurpleLight),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const DemoBanner(
                message: 'All player statistics and achievements are sample demo profiles.',
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
                        user?.isGuest == true ? 'Guest Session (Demo)' : 'Registered Player',
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
                      leading: Icon(
                        Icons.mark_email_read_rounded,
                        color: BrevoConfig.isConfigured
                            ? AppColors.onlineGreen
                            : AppColors.primaryBlueLight,
                      ),
                      title: const Text('Email OTP Service (Brevo)'),
                      subtitle: Text(
                        BrevoConfig.isConfigured
                            ? 'Brevo Live SMTP (Active)'
                            : 'Demo Simulated (Tap to configure API Key)',
                        style: TextStyle(
                          color: BrevoConfig.isConfigured
                              ? AppColors.onlineGreen
                              : AppColors.coinAmber,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () => _showBrevoConfigDialog(context),
                    ),
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
                      onChanged: (val) => setState(() => _soundEnabled = val),
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

              const SizedBox(height: 24),

              // Version info footer
              const Text(
                'Play Friends v1.0.0 (Build 1)',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              const Text(
                '100% Free Social Gaming • Non-gambling Application',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
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

  void _showBrevoConfigDialog(BuildContext context) {
    final apiKeyController = TextEditingController(text: BrevoConfig.apiKey);
    final senderEmailController = TextEditingController(text: BrevoConfig.senderEmail);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.mark_email_read_rounded, color: AppColors.primaryBlueLight),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Brevo Email API Setup',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (BrevoConfig.isConfigured
                              ? AppColors.onlineGreen
                              : AppColors.coinAmber)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: BrevoConfig.isConfigured
                            ? AppColors.onlineGreen
                            : AppColors.coinAmber,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          BrevoConfig.isConfigured
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          size: 18,
                          color: BrevoConfig.isConfigured
                              ? AppColors.onlineGreen
                              : AppColors.coinAmber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            BrevoConfig.isConfigured
                                ? 'Brevo Live SMTP is ACTIVE! Real OTP emails will be sent.'
                                : 'Demo Simulated Mode active (codes displayed in-app).',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: BrevoConfig.isConfigured
                                  ? AppColors.onlineGreen
                                  : AppColors.coinAmber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'To enable real emails via Brevo:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '1. Get API Key from Brevo -> SMTP & API -> API Keys (starts with xkeysib-)\n2. Add your verified sender email from Brevo -> Senders & IPs.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: apiKeyController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Brevo API Key (xkeysib-...)',
                      hintText: 'xkeysib-xxxxxxxx...',
                      prefixIcon: const Icon(Icons.key_rounded, size: 18, color: AppColors.primaryPurpleLight),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: senderEmailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Verified Sender Email',
                      hintText: 'verified_sender@domain.com',
                      prefixIcon: const Icon(Icons.email_outlined, size: 18, color: AppColors.primaryBlueLight),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 14),
                label: const Text('Test Email'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlueLight,
                  side: const BorderSide(color: AppColors.primaryBlueLight),
                ),
                onPressed: () async {
                  final key = apiKeyController.text.trim();
                  final email = senderEmailController.text.trim();
                  BrevoConfig.apiKey = key;
                  BrevoConfig.senderEmail = email;

                  final recipient = AuthService().currentUser?.email ?? email;
                  final result = await BrevoEmailService.sendOtpEmail(
                    recipientEmail: recipient,
                    recipientName: AuthService().currentUser?.name ?? 'Admin',
                    otpCode: '888999',
                    purpose: 'registration',
                  );

                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (testCtx) => AlertDialog(
                        title: Row(
                          children: [
                            Icon(
                              result.success
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              color: result.success
                                  ? AppColors.onlineGreen
                                  : AppColors.dangerRose,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                result.success
                                    ? 'Brevo Delivered!'
                                    : 'Brevo Delivery Error',
                                style: const TextStyle(fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        content: Text(
                          result.message,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(testCtx).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final key = apiKeyController.text.trim();
                  final email = senderEmailController.text.trim();
                  BrevoConfig.apiKey = key;
                  BrevoConfig.senderEmail = email;
                  setDialogState(() {});
                  setState(() {});
                  Navigator.of(ctx).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        BrevoConfig.isConfigured
                            ? 'Brevo Live API configured! Real OTP emails will be sent.'
                            : 'Brevo credentials updated.',
                      ),
                      backgroundColor: AppColors.surfaceLight,
                    ),
                  );
                },
                child: const Text('Save & Apply'),
              ),
            ],
          );
        },
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
              'Play Friends is an Android-first social gaming application built with Flutter & Material 3.',
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            SizedBox(height: 12),
            Text(
              'Legal & Fair Play Policy:',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPurpleLight),
            ),
            SizedBox(height: 4),
            Text(
              '• Strictly non-gambling and free-to-play.\n• No real-money betting, cash prizes, or in-app purchases.\n• Local Tic-Tac-Toe duel is playable offline.\n• All coins and trophies are strictly in-game demo points.',
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
