import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_friends/models/room_model.dart';
import 'package:play_friends/models/user_model.dart';
import 'package:play_friends/services/auth_service.dart';
import 'package:play_friends/services/backend_api_service.dart';
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
        const UserModel(
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

    test(
        'toggleFollowUser instantly adds user to AuthService friends list when following',
        () {
      final vm = VoiceRoomManager();
      final auth = AuthService();
      const friendName = 'Samira Gamer';
      const friendTag = '@samira_pro';

      expect(auth.friends.any((f) => f.name == friendName), isFalse);

      vm.toggleFollowUser(friendName, tag: friendTag);
      expect(vm.isFollowingUser(friendName), isTrue);
      expect(auth.friends.any((f) => f.name == friendName), isTrue);

      vm.toggleFollowUser(friendName, tag: friendTag);
      expect(vm.isFollowingUser(friendName), isFalse);
      expect(auth.friends.any((f) => f.name == friendName), isFalse);
    });

    test('RoomModel.isDemoRoom correctly flags and rejects demo rooms', () {
      const demoRoom1 = RoomModel(
        id: 'r_demo_1',
        roomCode: 'PF-8821',
        gameTitle: 'Bollywood & Gaming',
        hostName: 'Kabir 👑',
        currentPlayers: 1,
        maxPlayers: 100,
        isPrivate: false,
        status: 'live',
      );
      expect(RoomModel.isDemoRoom(demoRoom1), isTrue);

      const demoRoom5050 = RoomModel(
        id: 'r_seed_5050',
        roomCode: '5050',
        gameTitle: 'Game Friends Party',
        hostName: 'Game Friends',
        currentPlayers: 10,
        maxPlayers: 100,
        isPrivate: false,
        status: 'live',
      );
      expect(RoomModel.isDemoRoom(demoRoom5050), isTrue);

      const demoRoom4912 = RoomModel(
        id: 'r_seed_2',
        roomCode: 'PF-4912',
        gameTitle: '🎲 Ludo Friends & Gift Party',
        hostName: 'Aanya 🌸',
        currentPlayers: 88,
        maxPlayers: 150,
        isPrivate: false,
        status: 'live',
      );
      expect(RoomModel.isDemoRoom(demoRoom4912), isTrue);

      const demoRoom1034 = RoomModel(
        id: 'r_seed_3',
        roomCode: 'pf1034',
        gameTitle: '✨ Chill Lounge & Songs',
        hostName: 'Rohan 🎧',
        currentPlayers: 195,
        maxPlayers: 500,
        isPrivate: false,
        status: 'live',
      );
      expect(RoomModel.isDemoRoom(demoRoom1034), isTrue);

      const demoAnnya = RoomModel(
        id: 'room_annya_live',
        roomCode: 'PF-7722',
        gameTitle: 'Singing with Annya',
        hostName: 'annya',
        currentPlayers: 20,
        maxPlayers: 100,
        isPrivate: false,
        status: 'live',
      );
      expect(RoomModel.isDemoRoom(demoAnnya), isTrue);

      const realUserRoom = RoomModel(
        id: 'r_real_99',
        roomCode: 'PF-4421',
        gameTitle: "Shubham's Room",
        hostName: 'Shubham',
        currentPlayers: 1,
        maxPlayers: 100,
        isPrivate: false,
        status: 'live',
      );
      expect(RoomModel.isDemoRoom(realUserRoom), isFalse);
    });

    test('Search players by security IDs 01883183 and 01215830', () async {
      final auth = AuthService();
      const user1 = UserModel(
        id: '01883183',
        name: 'Player One',
        tag: '@player_one',
        email: 'p1@playfriends.com',
        phoneNumber: '+919876543210',
        avatarColor: Colors.blue,
        avatarInitial: 'P',
        level: 5,
        coins: 1200,
        trophies: 10,
        winRate: 0.7,
        totalMatches: 20,
      );
      const user2 = UserModel(
        id: '01215830',
        name: 'Player Two',
        tag: '@player_two',
        email: 'p2@playfriends.com',
        phoneNumber: '+919876543211',
        avatarColor: Colors.purple,
        avatarInitial: 'P',
        level: 8,
        coins: 2500,
        trophies: 25,
        winRate: 0.8,
        totalMatches: 35,
      );

      auth.addRegisteredUserForTesting(user1);
      auth.addRegisteredUserForTesting(user2);

      final search1 = await BackendApiService().searchUsers('01883183');
      expect(search1, isNotEmpty);
      expect(search1.first['id'], equals('01883183'));
      expect(search1.first['securityId'], equals('01883183'));
      expect(search1.first['name'], equals('Player One'));

      final search2 = await BackendApiService().searchUsers('01215830');
      expect(search2, isNotEmpty);
      expect(search2.first['id'], equals('01215830'));
      expect(search2.first['securityId'], equals('01215830'));
      expect(search2.first['name'], equals('Player Two'));
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
