import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'account_edit_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_use_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _matchSwitch = true;
  bool _notifications = true;
  bool _messageNotifications = true;
  String _cacheSize = '70.63M';
  String _chatCacheSize = '12.45M';

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              // Group 1: Account, Match switch, Privacy
              _buildSettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'Account',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AccountEditScreen()),
                  );
                },
              ),
              _buildSettingsTile(
                icon: Icons.alt_route_rounded,
                title: 'Match switch',
                trailing: Switch(
                  value: _matchSwitch,
                  activeThumbColor: const Color(0xFF7C3AED),
                  onChanged: (val) {
                    setState(() => _matchSwitch = val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(val
                            ? 'Auto-matchmaking enabled'
                            : 'Auto-matchmaking paused'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                onTap: () {
                  setState(() => _matchSwitch = !_matchSwitch);
                },
              ),
              _buildSettingsTile(
                icon: Icons.shield_outlined,
                title: 'Privacy',
                onTap: () => _showPrivacyControls(context),
              ),

              _buildSectionDivider(),

              // Group 2: Notifications, Message Notification, Blocked list
              _buildSettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                trailing: Switch(
                  value: _notifications,
                  activeThumbColor: const Color(0xFF7C3AED),
                  onChanged: (val) {
                    setState(() => _notifications = val);
                  },
                ),
                onTap: () {
                  setState(() => _notifications = !_notifications);
                },
              ),
              _buildSettingsTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Message Notification',
                trailing: Switch(
                  value: _messageNotifications,
                  activeThumbColor: const Color(0xFF7C3AED),
                  onChanged: (val) {
                    setState(() => _messageNotifications = val);
                  },
                ),
                onTap: () {
                  setState(
                      () => _messageNotifications = !_messageNotifications);
                },
              ),
              _buildSettingsTile(
                icon: Icons.person_off_outlined,
                title: 'Blocked list',
                onTap: () => _showBlockedListDialog(context),
              ),

              _buildSectionDivider(),

              // Group 3: System language, Content Language
              _buildSettingsTile(
                icon: Icons.translate_rounded,
                title: 'System language',
                valueText: 'English',
                onTap: () => _showLanguageSelector(context, 'System Language'),
              ),
              _buildSettingsTile(
                icon: Icons.language_rounded,
                title: 'Content Language',
                valueText: 'English',
                onTap: () => _showLanguageSelector(context, 'Content Language'),
              ),

              _buildSectionDivider(),

              // Group 4: Share app, Check for update, Help & feedback, Privacy policy, Terms of use, About
              _buildSettingsTile(
                icon: Icons.share_outlined,
                title: 'Share app',
                onTap: () => _shareApp(context),
              ),
              _buildSettingsTile(
                icon: Icons.sync_rounded,
                title: 'Check for update',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('You are using the latest version: v1.0.14 ✓'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & feedback',
                onTap: () => _showHelpFeedback(context),
              ),
              _buildSettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy policy',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()),
                  );
                },
              ),
              _buildSettingsTile(
                icon: Icons.article_outlined,
                title: 'Terms of use',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
                  );
                },
              ),
              _buildSettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About',
                onTap: () => _showAboutDialog(context),
              ),

              _buildSectionDivider(),

              // Group 5: Clear cache, Clear chat cache
              _buildSettingsTile(
                icon: Icons.cleaning_services_outlined,
                title: 'Clear cache',
                valueText: _cacheSize,
                onTap: () {
                  setState(() => _cacheSize = '0.00M');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('App cache cleared successfully! 🧹'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                icon: Icons.cleaning_services_outlined,
                title: 'Clear chat cache',
                valueText: _chatCacheSize,
                onTap: () {
                  setState(() => _chatCacheSize = '0.00M');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat cache cleared successfully! 🧹'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),

              const SizedBox(height: 36),

              // Bottom Actions: Log out & Delete account
              Center(
                child: TextButton(
                  onPressed: () => _confirmLogout(context),
                  child: const Text(
                    'Log out',
                    style: TextStyle(
                      color: Color(0xFFF43F5E),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: TextButton(
                    onPressed: () => _confirmDeleteAccount(context, user),
                    child: const Text(
                      'Delete account',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? valueText,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF0F172A)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            if (trailing != null)
              trailing
            else if (valueText != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    valueText,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Color(0xFFCBD5E1)),
                ],
              )
            else
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        color: Color(0xFFF1F5F9),
        thickness: 6,
      ),
    );
  }

  void _showPrivacyControls(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show Online Status'),
              subtitle: const Text('Allow friends to see when you are active'),
              value: true,
              activeThumbColor: const Color(0xFF7C3AED),
              onChanged: (_) {},
            ),
            SwitchListTile(
              title: const Text('Allow Direct Messages'),
              subtitle:
                  const Text('Direct chat is protected by mutual following'),
              value: true,
              activeThumbColor: const Color(0xFF7C3AED),
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockedListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Blocked List'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, size: 48, color: Color(0xFF7C3AED)),
            SizedBox(height: 12),
            Text(
              'No blocked users.\nPlayers you block from chats or rooms will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select $title',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            ...['English', 'Hindi', 'Arabic', 'Spanish'].map(
              (lang) => ListTile(
                title: Text(lang),
                trailing: lang == 'English'
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF7C3AED))
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title set to $lang'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareApp(BuildContext context) {
    Clipboard.setData(const ClipboardData(
        text: 'Join me on Play Friends! Download from https://playfriends.io'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('App invite link copied to clipboard! 📋'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showHelpFeedback(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Help & Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Need help or have suggestions? Send us feedback directly:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe your issue or suggestion...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Support: playgamefriendes@gmail.com',
              style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED)),
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
              backgroundColor: const Color(0xFF7C3AED),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Thank you! Your feedback has been sent to support.'),
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.sports_esports_rounded,
                color: Color(0xFF7C3AED), size: 26),
            SizedBox(width: 10),
            Text('About Play Friends'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Play Friends v1.0.14',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              'Social Gaming, Real-Time Voice Party Rooms, Carrom, Ludo, Tic-Tac-Toe, Music & Friends.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              'Owned & Operated by RAABTA TECHNOLOGY PTE. LTD.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7C3AED),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Support: playgamefriendes@gmail.com',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Logout'),
        content:
            const Text('Are you sure you want to log out of Play Friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              AuthService().logout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF43F5E), size: 26),
            SizedBox(width: 8),
            Text('Delete Account'),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete your account?\n\n'
          'All your data, rooms, music, game history, and coins will be permanently removed. This action cannot be undone.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              AuthService().deleteCurrentUser();
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}
