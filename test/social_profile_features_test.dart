import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_friends/models/room_model.dart';
import 'package:play_friends/models/user_model.dart';
import 'package:play_friends/services/auth_service.dart';
import 'package:play_friends/services/voice_room_manager.dart';
import 'package:play_friends/widgets/room_profile_dialog.dart';
import 'package:play_friends/widgets/user_profile_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gamer Tag Auto-Generation Tests', () {
    test(
        'generateUniqueTagFromEmail generates clean gamer tag from email prefix',
        () {
      final auth = AuthService();
      final tag = auth.generateUniqueTagFromEmail('alex.hunter@example.com');
      expect(tag, startsWith('@'));
      expect(tag, equals('@alex_hunter'));
    });

    test('generateUniqueTagFromEmail guarantees 1:1 mapping for same email',
        () {
      final auth = AuthService();
      final tag1 = auth.generateUniqueTagFromEmail('gamer_pro@playfriends.io');
      final tag2 = auth.generateUniqueTagFromEmail('gamer_pro@playfriends.io');
      expect(tag1, equals(tag2));
    });

    test(
        'generateUniqueTagFromEmail resolves duplicates with unique sequence tags',
        () {
      final auth = AuthService();
      // Simulate existing user with @player
      auth.addRegisteredUserForTesting(
        UserModel(
          id: 'u_player_1',
          name: 'Player One',
          tag: '@player',
          email: 'player@domainA.com',
          avatarInitial: 'P',
          avatarColor: Colors.blue,
          level: 1,
        ),
      );

      // Second user with player prefix in another domain gets disambiguated tag
      final tag2 = auth.generateUniqueTagFromEmail('player@domainB.com');
      expect(tag2, isNot(equals('@player')));
      expect(tag2, startsWith('@player'));
    });
  });

  group('Mutual Follow & Social Stats Tests', () {
    test('isMutualFollow returns true ONLY when both users follow each other',
        () {
      final vm = VoiceRoomManager();
      const userA = 'TargetUserA';

      // Initially neither follows
      expect(vm.isFollowingUser(userA), isFalse);
      expect(vm.isFollowedByUser(userA), isFalse);
      expect(vm.isMutualFollow(userA), isFalse);

      // Current user follows TargetUserA
      vm.toggleFollowUser(userA);
      expect(vm.isFollowingUser(userA), isTrue);
      // Still not mutual until TargetUserA follows back
      expect(vm.isMutualFollow(userA), isFalse);

      // TargetUserA follows back
      vm.setUserFollowsMe(userA, true);
      expect(vm.isFollowedByUser(userA), isTrue);
      expect(vm.isMutualFollow(userA), isTrue);

      // If current user unfollows, mutual status becomes false
      vm.toggleFollowUser(userA);
      expect(vm.isFollowingUser(userA), isFalse);
      expect(vm.isMutualFollow(userA), isFalse);
    });

    test(
        'Social stats (followers, following, visitors) increment and return correct counts',
        () {
      final vm = VoiceRoomManager();
      const userB = 'GamerB';

      final initialFollowers = vm.getUserFollowers(userB);
      final initialFollowing = vm.getUserFollowing(userB);
      final visitors = vm.getUserVisitors(userB);

      expect(initialFollowers, isNonNegative);
      expect(initialFollowing, isNonNegative);
      expect(visitors, isNonNegative);

      // Follow userB
      vm.toggleFollowUser(userB);
      expect(vm.getUserFollowers(userB), equals(initialFollowers + 1));

      // Unfollow userB
      vm.toggleFollowUser(userB);
      expect(vm.getUserFollowers(userB), equals(initialFollowers));
    });

    test('Room followers increment and decrement upon toggleFollowRoom', () {
      final vm = VoiceRoomManager();
      const testRoomCode = 'TEST_ROOM_999';

      expect(vm.isFollowingRoom(testRoomCode), isFalse);
      final initialCount = vm.getRoomFollowers(testRoomCode);

      vm.toggleFollowRoom(testRoomCode);
      expect(vm.isFollowingRoom(testRoomCode), isTrue);
      expect(vm.getRoomFollowers(testRoomCode), equals(initialCount + 1));

      vm.toggleFollowRoom(testRoomCode);
      expect(vm.isFollowingRoom(testRoomCode), isFalse);
      expect(vm.getRoomFollowers(testRoomCode), equals(initialCount));
    });
  });

  group('Profile Dialogs Widget Tests', () {
    testWidgets(
        'UserProfileDialog renders followers, following, visitors, level and gamer tag',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserProfileDialog(
              name: 'Elena Rostova',
              tag: '@elenarostova',
              level: 7,
              avatarColor: Colors.deepPurple,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Elena Rostova'), findsOneWidget);
      expect(find.text('@elenarostova'), findsOneWidget);
      expect(find.text('Lv.7'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Visitors'), findsOneWidget);
      expect(find.text('+ Follow'), findsOneWidget);
    });

    testWidgets(
        'RoomProfileDialog renders room level, room followers count, and room ID',
        (tester) async {
      const sampleRoom = RoomModel(
        id: 'r_test_100',
        roomCode: 'VIP8888',
        gameTitle: 'Ludo Stars Championship',
        hostName: 'HostMaster',
        currentPlayers: 4,
        maxPlayers: 100,
        isPrivate: false,
        status: 'active',
        giftPoints: 450,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoomProfileDialog(room: sampleRoom),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ludo Stars Championship'), findsOneWidget);
      expect(find.text('Room ID: VIP8888'), findsOneWidget);
      expect(find.text('Room Level'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.textContaining('HostMaster'), findsOneWidget);
    });
  });
}
