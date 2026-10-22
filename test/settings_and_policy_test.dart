import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_friends/models/user_model.dart';
import 'package:play_friends/screens/account_edit_screen.dart';
import 'package:play_friends/screens/privacy_policy_screen.dart';
import 'package:play_friends/screens/registered_users_screen.dart';
import 'package:play_friends/screens/settings_screen.dart';
import 'package:play_friends/screens/terms_of_use_screen.dart';
import 'package:play_friends/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Seed test authenticated user
    AuthService().setCurrentUserForTesting(
      const UserModel(
        id: 'u_test_settings',
        name: 'shubh',
        tag: '@shubh',
        email: 'shubh@example.com',
        avatarInitial: 'S',
        avatarColor: Color(0xFF7C3AED),
        level: 3,
        gender: 'Male',
        birthday: '1999-01-01',
      ),
    );
  });

  group('Settings Screen Widget Tests', () {
    testWidgets('SettingsScreen renders all navigation tiles and actions',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Registered Players Directory'), findsOneWidget);
      expect(find.text('Match switch'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Message Notification'), findsOneWidget);
      expect(find.text('Blocked list'), findsOneWidget);
      expect(find.text('System language'), findsOneWidget);
      expect(find.text('Content Language'), findsOneWidget);
      expect(find.text('Share app'), findsOneWidget);
      expect(find.text('Check for update'), findsOneWidget);
      expect(find.text('Help & feedback'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Terms of use'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Clear cache'), findsOneWidget);
      expect(find.text('70.63M'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
    });

    testWidgets('Tapping Clear cache updates cache text to 0.00M',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Clear cache'), 100);
      expect(find.text('70.63M'), findsOneWidget);
      await tester.tap(find.text('Clear cache'));
      await tester.pumpAndSettle();

      expect(find.text('0.00M'), findsOneWidget);
    });
  });

  group('Account Edit Screen Widget Tests', () {
    testWidgets(
        'AccountEditScreen renders completion percentage, personal info, and questions',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AccountEditScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account'), findsOneWidget);
      expect(find.textContaining('% complete'), findsOneWidget);
      expect(find.text('Personal info'), findsOneWidget);
      expect(find.text('Avatar'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Gender'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Nickname'), findsOneWidget);
      expect(find.text('shubh'), findsOneWidget);
      expect(find.text('Birthday'), findsOneWidget);
      expect(find.text('1999-01-01'), findsOneWidget);
      expect(find.text('Interests'), findsOneWidget);
      expect(find.text('Education'), findsOneWidget);
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Occupation'), findsOneWidget);
      expect(find.text('Spoken Language'), findsOneWidget);
      expect(find.text('About me'), findsOneWidget);
      expect(find.text('My answers'), findsOneWidget);
      expect(find.text('What sports are you into?'), findsOneWidget);
      expect(find.text('What music do you like?'), findsOneWidget);
      expect(find.text('What\'s your favorite food?'), findsOneWidget);
    });

    test('updateExtendedProfile updates user fields in AuthService', () {
      final auth = AuthService();
      auth.updateExtendedProfile(
        name: 'shubh_pro',
        gender: 'Male',
        birthday: '1999-01-01',
        interests: ['Gaming', 'Carrom'],
        education: 'Bachelor of Technology',
        school: 'Tech Institute',
        occupation: 'Software Engineer',
        aboutMe: 'Passionate mobile gamer and engineer',
      );

      final user = auth.currentUser!;
      expect(user.name, equals('shubh_pro'));
      expect(user.interests, contains('Gaming'));
      expect(user.education, equals('Bachelor of Technology'));
      expect(user.school, equals('Tech Institute'));
      expect(user.occupation, equals('Software Engineer'));
      expect(user.aboutMe, equals('Passionate mobile gamer and engineer'));
      expect(user.profileCompletionPercentage, greaterThanOrEqualTo(50));
    });
  });

  group('Terms of Use / User Agreement Screen Tests', () {
    testWidgets(
        'TermsOfUseScreen renders User Agreement and all legal sections',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TermsOfUseScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms of use'), findsOneWidget);
      expect(find.text('User Agreement'), findsOneWidget);
      expect(find.text('Last Updated: 05-09-2026'), findsOneWidget);
      expect(
          find.text('Operated by ssgobind.space'), findsOneWidget);
      expect(find.text('1. Special Notices'), findsOneWidget);
      expect(find.text('2. Services Content'), findsOneWidget);
      expect(find.text('4. Paid Services & Virtual Items'), findsOneWidget);
      expect(find.text('Virtual Items and In-App Currency'), findsOneWidget);
      expect(find.textContaining('العملات الذهبية'), findsOneWidget);
      expect(find.text('9. Prohibition of CSAE'), findsOneWidget);
      expect(find.text('11. Contact Us'), findsOneWidget);
      expect(find.text('playgamefriendes@gmail.com'), findsOneWidget);
    });
  });

  group('Privacy Policy Screen Tests', () {
    testWidgets('PrivacyPolicyScreen renders Privacy Policy and sections',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Play Friends Privacy Policy'), findsOneWidget);
      expect(find.text('Updated on: February 2, 2026'), findsOneWidget);
      expect(
          find.text('Operated by ssgobind.space'), findsOneWidget);
      expect(find.text('1. What information does Play Friends collect?'),
          findsOneWidget);
      expect(find.text('2. System permission inquired by Play Friends'),
          findsOneWidget);
      expect(find.text('7. Account Deletion'), findsOneWidget);
      expect(find.text('8. Your Rights'), findsOneWidget);
      expect(find.text('playgamefriendes@gmail.com'), findsOneWidget);
    });
  });

  group('Registered Users Screen Tests', () {
    testWidgets('RegisteredUsersScreen renders player directory and search bar',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisteredUsersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Registered Players'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('shubh'), findsWidgets);
    });
  });
}
