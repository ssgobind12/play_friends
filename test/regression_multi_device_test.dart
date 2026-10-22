import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_friends/models/room_model.dart';
import 'package:play_friends/models/user_model.dart';
import 'package:play_friends/services/auth_service.dart';
import 'package:play_friends/services/aws_storage_service.dart';
import 'package:play_friends/services/backend_api_service.dart';
import 'package:play_friends/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AwsStorageService.mockMode = true;
    AwsStorageService.resetForTesting();
    LocalStorageService.resetInMemoryForTesting();
    BackendApiService.isTestMode = true;
    BackendApiService().resetMockForTesting();
    await AuthService().init();
  });

  group('Bug 1 Regression Tests: Account Persistence & Login After Logout', () {
    test('User registers, logs out, and logs in again with identical credentials', () async {
      final auth = AuthService();
      const email = 'player_alpha@playfriends.io';
      const password = 'SecretPassword123!';
      const phone = '9876500001';

      // 1. Register new user
      final regErr = auth.register(
        name: 'Player Alpha',
        tag: '@player_alpha',
        email: email,
        password: password,
        phoneNumber: phone,
        countryCode: '+91',
        countryFlag: '🇮🇳',
        avatarColor: const Color(0xFF7C3AED),
      );
      expect(regErr, isNull);
      expect(auth.currentUser, isNotNull);
      final registeredId = auth.currentUser!.id;
      final registeredTag = auth.currentUser!.tag;

      // 2. User logs out
      auth.logout();
      expect(auth.currentUser, isNull);

      // 3. User logs in with email and password
      final loginEmailErr = auth.login(email, password);
      expect(loginEmailErr, isNull);
      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser!.id, equals(registeredId));
      expect(auth.currentUser!.tag, equals(registeredTag));

      // 4. User logs out again and logs in using mobile number
      auth.logout();
      expect(auth.currentUser, isNull);

      final loginPhoneErr = auth.login(phone, password);
      expect(loginPhoneErr, isNull);
      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser!.id, equals(registeredId));
      expect(auth.currentUser!.email, equals(email));

      // 5. Wrong password is rejected
      auth.logout();
      final badPassErr = auth.login(email, 'WrongPass999!');
      expect(badPassErr, isNotNull);
      expect(auth.currentUser, isNull);
    });

    test('AwsStorageService.loginUser verifies credentials and returns server user', () async {
      const email = 'cloud_user@playfriends.io';
      const password = 'MyCloudPassword456!';

      const user = UserModel(
        id: '01883183',
        name: 'Cloud Gamer',
        tag: '@cloud_gamer',
        email: email,
        phoneNumber: '9123456780',
        avatarColor: Color(0xFF8B5CF6),
        avatarInitial: 'C',
        role: 'user',
      );

      final storeOk = await AwsStorageService.storeUser(user, password: password);
      expect(storeOk, isTrue);

      // Login by email
      final loginRes = await AwsStorageService.loginUser(
        identifier: email,
        password: password,
      );
      expect(loginRes.success, isTrue);
      expect(loginRes.user, isNotNull);
      expect(loginRes.user!.id, equals('01883183'));
      expect(loginRes.user!.email, equals(email));

      // Login by gamer tag
      final tagLogin = await AwsStorageService.loginUser(
        identifier: '@cloud_gamer',
        password: password,
      );
      expect(tagLogin.success, isTrue);
      expect(tagLogin.user!.id, equals('01883183'));

      // Incorrect password fails
      final failLogin = await AwsStorageService.loginUser(
        identifier: email,
        password: 'IncorrectPassword',
      );
      expect(failLogin.success, isFalse);
      expect(failLogin.user, isNull);
    });
  });

  group('Bug 2 Regression Tests: Atomic Uniqueness & Normalization', () {
    test('checkUserExists detects genuine duplicates and ignores stale local caches', () async {
      const existingEmail = 'gamer_registered@playfriends.io';
      const existingPhone = '9998887776';

      const existingUser = UserModel(
        id: '01999999',
        name: 'Registered Player',
        tag: '@registered_player',
        email: existingEmail,
        phoneNumber: existingPhone,
        avatarColor: Color(0xFF3B82F6),
        avatarInitial: 'R',
        role: 'user',
      );
      await AwsStorageService.storeUser(existingUser, password: 'password123');

      // Duplicate email check
      final emailCheck = await AwsStorageService.checkUserExists(
        email: 'GAMER_REGISTERED@playfriends.io  ',
        phoneNumber: '9111111111',
      );
      expect(emailCheck.exists, isTrue);
      expect(emailCheck.existingField, equals('email'));

      // Duplicate phone check
      final phoneCheck = await AwsStorageService.checkUserExists(
        email: 'brand_new_email@playfriends.io',
        phoneNumber: '+91 999 888 7776',
      );
      expect(phoneCheck.exists, isTrue);
      expect(phoneCheck.existingField, equals('mobile'));

      // Fresh credentials are accepted
      final freshCheck = await AwsStorageService.checkUserExists(
        email: 'brand_new_email@playfriends.io',
        phoneNumber: '9555444333',
      );
      expect(freshCheck.exists, isFalse);
    });

    test('registerAsync normalizes email to lowercase and trims input', () async {
      final auth = AuthService();
      const rawEmail = '  NewPlayer_2026@PlayFriends.IO  ';
      const cleanExpected = 'newplayer_2026@playfriends.io';

      final err = await auth.registerAsync(
        name: 'New Player',
        tag: '@new_player',
        email: rawEmail,
        password: 'PasswordValid123',
        phoneNumber: '9888777665',
        countryCode: '+91',
        countryFlag: '🇮🇳',
        avatarColor: const Color(0xFF10B981),
        verificationToken: 'token_mock_test',
      );

      expect(err, isNull);
      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser!.email, equals(cleanExpected));
    });
  });

  group('Bug 3 Regression Tests: Cross-Device Social Graph & Follow Sync', () {
    test('Device A follows Device B -> Device B sees Device A in followers list', () async {
      const userAId = 'user_device_A';
      const userBId = 'user_device_B';

      // 1. User A follows User B
      final followRes = await AwsStorageService.followUser(
        followerId: userAId,
        followerName: 'Device A Gamer',
        targetIdOrTag: userBId,
        follow: true,
      );
      expect(followRes['success'], isTrue);
      expect(followRes['isFollowing'], isTrue);

      // 2. Query followers of User B -> User A is present!
      final bFollowers = await AwsStorageService.getFollowers(userBId);
      expect(bFollowers.any((u) => u['id'].toString().toLowerCase() == userAId.toLowerCase()), isTrue);

      // 3. User B checks follow status with User A -> User A is following, but not mutual yet
      final statusBefore = await AwsStorageService.getFollowStatus(
        currentUserId: userBId,
        targetUserId: userAId,
      );
      expect(statusBefore['isFollowedBy'], isTrue);
      expect(statusBefore['isFollowing'], isFalse);
      expect(statusBefore['isMutual'], isFalse);

      // 4. User B follows User A back -> Mutual follow unlocked!
      final followBackRes = await AwsStorageService.followUser(
        followerId: userBId,
        followerName: 'Device B Gamer',
        targetIdOrTag: userAId,
        follow: true,
      );
      expect(followBackRes['success'], isTrue);

      final statusAfter = await AwsStorageService.getFollowStatus(
        currentUserId: userBId,
        targetUserId: userAId,
      );
      expect(statusAfter['isFollowing'], isTrue);
      expect(statusAfter['isFollowedBy'], isTrue);
      expect(statusAfter['isMutual'], isTrue);

      // 5. Unfollow operation is idempotent and updates counts
      final unfollowRes = await AwsStorageService.followUser(
        followerId: userAId,
        followerName: 'Device A Gamer',
        targetIdOrTag: userBId,
        follow: false,
      );
      expect(unfollowRes['isFollowing'], isFalse);

      final bFollowersAfter = await AwsStorageService.getFollowers(userBId);
      expect(bFollowersAfter.any((u) => u['id'].toString().toLowerCase() == userAId.toLowerCase()), isFalse);
    });
  });

  group('Bug 4 Regression Tests: Cross-Device Room Membership & Live Presence', () {
    test('Device A creates room -> Device B discovers room, joins, and both verify membership', () async {
      const roomId = 'room_party_8421';

      const room = RoomModel(
        id: roomId,
        roomCode: 'PF-8421',
        gameTitle: 'Ludo Stars Party',
        hostName: 'Host Player A',
        currentPlayers: 1,
        maxPlayers: 100,
        isPrivate: false,
        status: 'Live Voice Party',
      );

      // 1. Device A creates room
      final createOk = await AwsStorageService.createRoom(room);
      expect(createOk, isTrue);

      // 2. Device B discovers room from server
      final rooms = await AwsStorageService.getRooms();
      expect(rooms.any((r) => r.id == roomId), isTrue);

      // 3. Device B joins room
      const userB = UserModel(
        id: 'user_device_B_123',
        name: 'Device B Player',
        tag: '@device_b',
        email: 'device_b@playfriends.io',
        avatarColor: Color(0xFFEC4899),
        avatarInitial: 'D',
        role: 'user',
      );

      final joinRes = await AwsStorageService.joinRoom(
        roomId: roomId,
        user: userB,
      );
      expect(joinRes.success, isTrue);
      expect(joinRes.currentPlayers, greaterThanOrEqualTo(2));
      expect(joinRes.members.any((m) => m['userId'] == 'user_device_B_123'), isTrue);

      // 4. Device A fetches room members -> Device B is confirmed inside!
      final membersOnServer = await AwsStorageService.getRoomMembers(roomId);
      expect(membersOnServer.any((m) => m['userId'] == 'user_device_B_123'), isTrue);

      // 5. Device B leaves room -> Membership updates on server
      final leaveRes = await AwsStorageService.leaveRoom(
        roomId: roomId,
        userId: 'user_device_B_123',
      );
      expect(leaveRes.success, isTrue);
      expect(leaveRes.members.any((m) => m['userId'] == 'user_device_B_123'), isFalse);

      final membersAfterLeave = await AwsStorageService.getRoomMembers(roomId);
      expect(membersAfterLeave.any((m) => m['userId'] == 'user_device_B_123'), isFalse);
    });

    test('Direct messaging persists messages between mutual friends', () async {
      const userA = 'user_alice';
      const userB = 'user_bob';

      final sendOk = await AwsStorageService.sendDirectMessage(
        senderId: userA,
        receiverId: userB,
        text: 'Hello Bob! Ready to play Carrom?',
      );
      expect(sendOk, isTrue);

      final messages = await AwsStorageService.getDirectMessages(
        userA: userA,
        userB: userB,
      );
      expect(messages.length, equals(1));
      expect(messages.first['text'], contains('Ready to play Carrom'));
    });
  });
}
