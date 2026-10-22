import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AccountEditScreen extends StatefulWidget {
  const AccountEditScreen({super.key});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  // Available interests
  static const List<String> kInterestOptions = [
    'Gaming 🎮',
    'Music 🎵',
    'Ludo 🎲',
    'Carrom ⚪',
    'Anime 🌸',
    'Movies 🍿',
    'Tech 💻',
    'Fitness 🏋️',
    'Travel ✈️',
    'Photography 📸',
  ];

  // Available languages
  static const List<String> kLanguageOptions = [
    'English',
    'Hindi',
    'Arabic',
    'Spanish',
    'French',
    'German',
    'Russian',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final user = AuthService().currentUser;
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('User not logged in')),
          );
        }

        final completionPct = user.profileCompletionPercentage;

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
              'Account',
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with Completion Arc Header
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // Circular Avatar with Progress Ring
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 106,
                              height: 106,
                              child: CustomPaint(
                                painter: _ProfileProgressPainter(
                                  percentage: completionPct,
                                  trackColor: const Color(0xFFF1F5F9),
                                  progressColor: const Color(0xFF7C3AED),
                                  strokeWidth: 3.5,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showAvatarPicker(context, user),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: user.avatarColor,
                                backgroundImage:
                                    _resolveAvatarImage(user.profilePhoto),
                                child: user.profilePhoto == null
                                    ? Text(
                                        user.avatarInitial,
                                        style: const TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Progress percentage
                        Text(
                          '$completionPct% complete',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C3AED),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Subtitle
                        const Text(
                          'Complete your account info to attract more like-minded mates',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Section Header: Personal info
                  const Text(
                    'Personal info',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 1. Avatar
                  _buildSettingRow(
                    label: 'Avatar',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF43F5E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: Color(0xFFCBD5E1)),
                      ],
                    ),
                    onTap: () => _showAvatarPicker(context, user),
                  ),

                  // 2. Gender
                  _buildSettingRow(
                    label: 'Gender',
                    trailing: Text(
                      user.gender ?? 'Male',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => _editGender(context, user),
                  ),

                  // 3. Nickname
                  _buildSettingRow(
                    label: 'Nickname',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: Color(0xFFCBD5E1)),
                      ],
                    ),
                    onTap: () => _editNickname(context, user),
                  ),

                  // 4. Birthday
                  _buildSettingRow(
                    label: 'Birthday',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.birthday ?? '1999-01-01',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: Color(0xFFCBD5E1)),
                      ],
                    ),
                    onTap: () => _editBirthday(context, user),
                  ),

                  // 5. Interests
                  _buildSettingRow(
                    label: 'Interests',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (user.interests.isNotEmpty)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              user.interests.join(', '),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: Color(0xFFCBD5E1)),
                      ],
                    ),
                    onTap: () => _editInterests(context, user),
                  ),

                  // 6. Education
                  _buildSettingRow(
                    label: 'Education',
                    trailing:
                        user.education != null && user.education!.isNotEmpty
                            ? Text(
                                user.education!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : _buildPlusButton(
                                onTap: () => _editTextAttribute(
                                  context: context,
                                  title: 'Education',
                                  currentValue: user.education,
                                  hintText: 'e.g. Bachelor\'s Degree',
                                  onSave: (val) => AuthService()
                                      .updateExtendedProfile(education: val),
                                ),
                              ),
                    onTap: () => _editTextAttribute(
                      context: context,
                      title: 'Education',
                      currentValue: user.education,
                      hintText: 'e.g. Bachelor\'s Degree',
                      onSave: (val) =>
                          AuthService().updateExtendedProfile(education: val),
                    ),
                  ),

                  // 7. School
                  _buildSettingRow(
                    label: 'School',
                    trailing: user.school != null && user.school!.isNotEmpty
                        ? Text(
                            user.school!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : _buildPlusButton(
                            onTap: () => _editTextAttribute(
                              context: context,
                              title: 'School',
                              currentValue: user.school,
                              hintText: 'e.g. Stanford University',
                              onSave: (val) => AuthService()
                                  .updateExtendedProfile(school: val),
                            ),
                          ),
                    onTap: () => _editTextAttribute(
                      context: context,
                      title: 'School',
                      currentValue: user.school,
                      hintText: 'e.g. Stanford University',
                      onSave: (val) =>
                          AuthService().updateExtendedProfile(school: val),
                    ),
                  ),

                  // 8. Occupation
                  _buildSettingRow(
                    label: 'Occupation',
                    trailing:
                        user.occupation != null && user.occupation!.isNotEmpty
                            ? Text(
                                user.occupation!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : _buildPlusButton(
                                onTap: () => _editTextAttribute(
                                  context: context,
                                  title: 'Occupation',
                                  currentValue: user.occupation,
                                  hintText: 'e.g. Software Engineer',
                                  onSave: (val) => AuthService()
                                      .updateExtendedProfile(occupation: val),
                                ),
                              ),
                    onTap: () => _editTextAttribute(
                      context: context,
                      title: 'Occupation',
                      currentValue: user.occupation,
                      hintText: 'e.g. Software Engineer',
                      onSave: (val) =>
                          AuthService().updateExtendedProfile(occupation: val),
                    ),
                  ),

                  // 9. Spoken Language
                  _buildSettingRow(
                    label: 'Spoken Language',
                    trailing: user.spokenLanguages != null &&
                            user.spokenLanguages!.isNotEmpty
                        ? Text(
                            user.spokenLanguages!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : _buildPlusButton(
                            onTap: () => _editLanguages(context, user),
                          ),
                    onTap: () => _editLanguages(context, user),
                  ),

                  // 10. About me
                  _buildSettingRow(
                    label: 'About me',
                    trailing: user.aboutMe != null && user.aboutMe!.isNotEmpty
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              user.aboutMe!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          )
                        : _buildPlusButton(
                            onTap: () => _editTextAttribute(
                              context: context,
                              title: 'About me',
                              currentValue: user.aboutMe,
                              hintText: 'Write a self-introduction...',
                              isMultiline: true,
                              onSave: (val) => AuthService()
                                  .updateExtendedProfile(aboutMe: val),
                            ),
                          ),
                    onTap: () => _editTextAttribute(
                      context: context,
                      title: 'About me',
                      currentValue: user.aboutMe,
                      hintText: 'Write a self-introduction...',
                      isMultiline: true,
                      onSave: (val) =>
                          AuthService().updateExtendedProfile(aboutMe: val),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Section Header: My answers
                  const Text(
                    'My answers',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Q1: What sports are you into?
                  _buildSettingRow(
                    label: 'What sports are you into?',
                    trailing: user.sportsAnswer != null &&
                            user.sportsAnswer!.isNotEmpty
                        ? Text(
                            user.sportsAnswer!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : _buildPlusButton(
                            onTap: () => _editTextAttribute(
                              context: context,
                              title: 'What sports are you into?',
                              currentValue: user.sportsAnswer,
                              hintText: 'e.g. Cricket, Football, Chess',
                              onSave: (val) => AuthService()
                                  .updateExtendedProfile(sportsAnswer: val),
                            ),
                          ),
                    onTap: () => _editTextAttribute(
                      context: context,
                      title: 'What sports are you into?',
                      currentValue: user.sportsAnswer,
                      hintText: 'e.g. Cricket, Football, Chess',
                      onSave: (val) => AuthService()
                          .updateExtendedProfile(sportsAnswer: val),
                    ),
                  ),

                  // Q2: What music do you like?
                  _buildSettingRow(
                    label: 'What music do you like?',
                    trailing:
                        user.musicAnswer != null && user.musicAnswer!.isNotEmpty
                            ? Text(
                                user.musicAnswer!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : _buildPlusButton(
                                onTap: () => _editTextAttribute(
                                  context: context,
                                  title: 'What music do you like?',
                                  currentValue: user.musicAnswer,
                                  hintText: 'e.g. EDM, Pop, Ambient, Hip-Hop',
                                  onSave: (val) => AuthService()
                                      .updateExtendedProfile(musicAnswer: val),
                                ),
                              ),
                    onTap: () => _editTextAttribute(
                      context: context,
                      title: 'What music do you like?',
                      currentValue: user.musicAnswer,
                      hintText: 'e.g. EDM, Pop, Ambient, Hip-Hop',
                      onSave: (val) =>
                          AuthService().updateExtendedProfile(musicAnswer: val),
                    ),
                  ),

                  // Q3: What's your favorite food?
                  _buildSettingRow(
                    label: 'What\'s your favorite food?',
                    trailing:
                        user.foodAnswer != null && user.foodAnswer!.isNotEmpty
                            ? Text(
                                user.foodAnswer!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : _buildPlusButton(
                                onTap: () => _editTextAttribute(
                                  context: context,
                                  title: 'What\'s your favorite food?',
                                  currentValue: user.foodAnswer,
                                  hintText: 'e.g. Pizza, Biryani, Sushi',
                                  onSave: (val) => AuthService()
                                      .updateExtendedProfile(foodAnswer: val),
                                ),
                              ),
                    onTap: () => _editTextAttribute(
                      context: context,
                      title: 'What\'s your favorite food?',
                      currentValue: user.foodAnswer,
                      hintText: 'e.g. Pizza, Biryani, Sushi',
                      onSave: (val) =>
                          AuthService().updateExtendedProfile(foodAnswer: val),
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingRow({
    required String label,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildPlusButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFF7C3AED),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  ImageProvider? _resolveAvatarImage(String? photo) {
    if (photo == null || photo.isEmpty) return null;
    if (photo.startsWith('data:image')) {
      try {
        final b64 = photo.split(',').last;
        return MemoryImage(base64Decode(b64));
      } catch (_) {
        return null;
      }
    }
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return NetworkImage(photo);
    }
    return null;
  }

  void _editGender(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Gender',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            ...['Male', 'Female', 'Other'].map(
              (g) => ListTile(
                title: Text(g,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: user.gender == g
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF7C3AED))
                    : null,
                onTap: () {
                  AuthService().updateExtendedProfile(gender: g);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editNickname(BuildContext context, UserModel user) {
    final ctrl = TextEditingController(text: user.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Nickname'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nickname',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
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
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                AuthService().updateExtendedProfile(name: newName);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editBirthday(BuildContext context, UserModel user) async {
    DateTime initial = DateTime(1999, 1, 1);
    if (user.birthday != null) {
      try {
        initial = DateTime.parse(user.birthday!);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7C3AED),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      AuthService().updateExtendedProfile(birthday: formatted);
    }
  }

  void _editInterests(BuildContext context, UserModel user) {
    final selected = Set<String>.from(user.interests);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Choose Interests'),
            content: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kInterestOptions.map((item) {
                  final isSelected = selected.contains(item);
                  return FilterChip(
                    label: Text(item),
                    selected: isSelected,
                    selectedColor:
                        const Color(0xFF7C3AED).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFF7C3AED),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF334155),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setModalState(() {
                        if (val) {
                          selected.add(item);
                        } else {
                          selected.remove(item);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
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
                  AuthService()
                      .updateExtendedProfile(interests: selected.toList());
                  Navigator.of(ctx).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editLanguages(BuildContext context, UserModel user) {
    final selected = user.spokenLanguages != null
        ? user.spokenLanguages!.split(', ').toSet()
        : <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Spoken Languages'),
            content: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kLanguageOptions.map((item) {
                  final isSelected = selected.contains(item);
                  return FilterChip(
                    label: Text(item),
                    selected: isSelected,
                    selectedColor:
                        const Color(0xFF7C3AED).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFF7C3AED),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF334155),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setModalState(() {
                        if (val) {
                          selected.add(item);
                        } else {
                          selected.remove(item);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
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
                  AuthService().updateExtendedProfile(
                      spokenLanguages: selected.join(', '));
                  Navigator.of(ctx).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editTextAttribute({
    required BuildContext context,
    required String title,
    required String? currentValue,
    required String hintText,
    required Function(String) onSave,
    bool isMultiline = false,
  }) {
    final ctrl = TextEditingController(text: currentValue ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: isMultiline ? 3 : 1,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
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
              onSave(ctrl.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAvatarPicker(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Change Avatar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FE),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.palette_rounded, color: Color(0xFF7C3AED)),
              ),
              title: const Text('Choose Avatar Style',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Select gaming avatars or color presets'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showAvatarPresetsModal(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFCE7F3),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.image_rounded, color: Color(0xFFEC4899)),
              ),
              title: const Text('Set Preset Gamer Photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Apply HD gamer profile portraits'),
              onTap: () {
                Navigator.of(ctx).pop();
                AuthService().updateProfilePhoto(
                    'https://images.unsplash.com/photo-1566492031773-4f4e44671857?w=400&auto=format&fit=crop&q=80');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarPresetsModal(BuildContext context) {
    final List<Map<String, dynamic>> avatars = [
      {'icon': Icons.sports_esports_rounded, 'color': const Color(0xFF7C3AED)},
      {'icon': Icons.bolt_rounded, 'color': const Color(0xFF06B6D4)},
      {'icon': Icons.military_tech_rounded, 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.rocket_launch_rounded, 'color': const Color(0xFFEC4899)},
      {'icon': Icons.auto_awesome_rounded, 'color': const Color(0xFF10B981)},
      {'icon': Icons.shield_rounded, 'color': const Color(0xFF3B82F6)},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Preset Avatar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: avatars.map((a) {
                return GestureDetector(
                  onTap: () {
                    AuthService().updateProfilePhoto(null);
                    Navigator.of(ctx).pop();
                  },
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: a['color'] as Color,
                    child: Icon(a['icon'] as IconData,
                        color: Colors.white, size: 26),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the completion arc around the avatar
class _ProfileProgressPainter extends CustomPainter {
  final int percentage;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _ProfileProgressPainter({
    required this.percentage,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (percentage / 100) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProfileProgressPainter oldDelegate) {
    return oldDelegate.percentage != percentage;
  }
}
