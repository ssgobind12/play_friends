import 'package:flutter_test/flutter_test.dart';
import 'package:play_friends/models/room_model.dart';
import 'package:play_friends/services/auth_service.dart';
import 'package:play_friends/services/backend_api_service.dart';
import 'package:play_friends/services/aws_storage_service.dart';
import 'package:play_friends/services/in_app_music_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    BackendApiService.isTestMode = true;
    AwsStorageService.mockMode = true;
    AuthService().resetStatsForTesting();
  });

  group('Game Progression & Level Unlock Tests', () {
    test(
        'Initial user starts clean at Level 1 with 0 wins and only Tic-Tac-Toe unlocked',
        () {
      final user = AuthService().currentUser;
      expect(user, isNotNull);
      expect(user!.level, 1);
      expect(user.totalWins, 0);
      expect(user.totalMatches, 0);

      // Tic-Tac-Toe is unlocked by default
      expect(AuthService().isGameUnlocked('tic_tac_toe'), isTrue);

      // Other games require Level / Wins
      expect(AuthService().isGameUnlocked('ludo'), isFalse);
      expect(AuthService().isGameUnlocked('carrom'), isFalse);
      expect(AuthService().isGameUnlocked('space_dodge'), isFalse);
    });

    test(
        'Winning 20 games levels up player to Level 5 and unlocks Ludo Friends',
        () {
      expect(AuthService().isGameUnlocked('ludo'), isFalse);

      String? lastUnlocked;
      for (int i = 0; i < 20; i++) {
        final unlocked =
            AuthService().recordMatchResult(gameId: 'tic_tac_toe', won: true);
        if (unlocked != null) {
          lastUnlocked = unlocked;
        }
      }

      final user = AuthService().currentUser!;
      expect(user.totalWins, 20);
      expect(user.level, greaterThanOrEqualTo(5));
      expect(AuthService().isGameUnlocked('ludo'), isTrue);
      expect(lastUnlocked, 'Ludo Friends');
    });

    test('Quick unlock unlocks all games immediately', () {
      AuthService().unlockAllGames();
      expect(AuthService().isGameUnlocked('tic_tac_toe'), isTrue);
      expect(AuthService().isGameUnlocked('ludo'), isTrue);
      expect(AuthService().isGameUnlocked('carrom'), isTrue);
      expect(AuthService().isGameUnlocked('space_dodge'), isTrue);
    });

    test('Friends can be added dynamically without demo data', () {
      final auth = AuthService();
      final initialCount = auth.friends.length;

      auth.addFriend(name: 'Rohan Sharma', tag: '@rohan_pro');
      expect(auth.friends.length, initialCount + 1);
      expect(auth.friends.any((f) => f.name == 'Rohan Sharma'), isTrue);

      final added = auth.friends.firstWhere((f) => f.name == 'Rohan Sharma');
      auth.removeFriend(added.id);
      expect(auth.friends.any((f) => f.name == 'Rohan Sharma'), isFalse);
    });

    test('Rooms can be created and managed dynamically', () {
      final auth = AuthService();
      final initialRooms = auth.activeRooms.length;

      const testRoom = RoomModel(
        id: 'r_test_1',
        roomCode: 'PF-9999',
        gameTitle: 'Ludo Friends',
        hostName: 'TestHost',
        currentPlayers: 1,
        maxPlayers: 4,
        isPrivate: false,
        status: 'Waiting',
      );

      auth.addRoom(testRoom);
      expect(auth.activeRooms.length, initialRooms + 1);
      expect(auth.activeRooms.any((r) => r.roomCode == 'PF-9999'), isTrue);
    });

    test('Admin user has all games unlocked and starts with 01 ID', () {
      final auth = AuthService();
      final err = auth.login('ssgobind12@gamil.com', 'test_admin_pass_2026!');
      expect(err, isNull);
      expect(auth.currentUser?.isAdmin, isTrue);
      expect(auth.currentUser?.id.startsWith('01'), isTrue);
      expect(auth.isGameUnlocked('tic_tac_toe'), isTrue);
      expect(auth.isGameUnlocked('ludo'), isTrue);
      expect(auth.isGameUnlocked('carrom'), isTrue);
      expect(auth.isGameUnlocked('space_dodge'), isTrue);
      expect(auth.isGameUnlocked('arena_brawl'), isTrue);
      expect(auth.isGameUnlocked('word_rush'), isTrue);
    });

    test('Delete current user removes only their own account', () {
      final auth = AuthService();
      auth.resetStatsForTesting();
      final testUserId = auth.currentUser!.id;
      expect(auth.currentUser, isNotNull);

      final success = auth.deleteCurrentUser();
      expect(success, isTrue);
      expect(auth.currentUser, isNull);
      expect(auth.registeredUsers.any((u) => u.id == testUserId), isFalse);
      // Admin still remains in registered users
      expect(auth.registeredUsers.any((u) => u.id == AuthService.adminUser.id),
          isTrue);
    });

    test('User can upload and update profile photo', () {
      final auth = AuthService();
      auth.resetStatsForTesting();
      expect(auth.currentUser?.profilePhoto, isNull);

      auth.updateProfilePhoto('https://example.com/my_avatar.png');
      expect(
          auth.currentUser?.profilePhoto, 'https://example.com/my_avatar.png');

      auth.updateProfilePhoto('icon:ninja');
      expect(auth.currentUser?.profilePhoto, 'icon:ninja');

      auth.updateProfilePhoto(
          'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD');
      expect(auth.currentUser?.profilePhoto?.startsWith('data:image'), isTrue);

      auth.updateProfilePhoto(null);
      expect(auth.currentUser?.profilePhoto, isNull);
    });

    test(
        'User can upload custom music to in-app music store and phone local audio',
        () {
      final musicService = InAppMusicService();
      final initialCount = musicService.tracks.length;

      final uploaded = musicService.uploadCustomMusic(
        title: 'Cyberpunk Synthwave Beat',
        genre: 'Synthwave',
        bpm: '130 BPM',
        audioPathOrUrl: '/storage/emulated/0/Music/Cyberpunk.mp3',
      );

      expect(musicService.tracks.length, initialCount + 1);
      expect(uploaded.title, 'Cyberpunk Synthwave Beat');
      expect(uploaded.isUserUploaded, isTrue);
      expect(uploaded.audioSource, '/storage/emulated/0/Music/Cyberpunk.mp3');
      expect(musicService.currentTrack.title, 'Cyberpunk Synthwave Beat');
      expect(musicService.isPlaying, isTrue);
    });

    test('User can spend coins for room gifts and recharge bonus', () {
      final auth = AuthService();
      auth.resetStatsForTesting();
      expect(auth.currentUser?.coins, 500);

      // Spend 100 coins for Lucky Dice gift
      final success = auth.spendCoins(100);
      expect(success, isTrue);
      expect(auth.currentUser?.coins, 400);

      // Insufficient coins test
      final failed = auth.spendCoins(1000);
      expect(failed, isFalse);
      expect(auth.currentUser?.coins, 400);

      // Claim recharge bonus
      auth.addCoins(1000);
      expect(auth.currentUser?.coins, 1400);
    });

    test('Party rooms support capacities over 100 people and gift points', () {
      final auth = AuthService();
      const megaRoom = RoomModel(
        id: 'r_mega_1',
        roomCode: 'PF-5555',
        gameTitle: '🎵 Mega Chalo Party',
        hostName: 'DJ Star',
        currentPlayers: 120,
        maxPlayers: 500,
        isPrivate: false,
        status: 'Live Voice Party',
        giftPoints: 4500,
      );

      auth.addRoom(megaRoom);
      expect(auth.activeRooms.any((r) => r.roomCode == 'PF-5555'), isTrue);
      final retrieved =
          auth.activeRooms.firstWhere((r) => r.roomCode == 'PF-5555');
      expect(retrieved.maxPlayers, 500);
      expect(retrieved.giftPoints, 4500);

      // Delete room test
      final deleted = auth.deleteRoom(megaRoom.id);
      expect(deleted, isTrue);
      expect(auth.activeRooms.any((r) => r.roomCode == 'PF-5555'), isFalse);
    });

    test('Deleting user purges data everywhere (account, rooms, songs)', () {
      final auth = AuthService();
      auth.resetStatsForTesting();
      final current = auth.currentUser!;

      // Add a custom room for this user
      final userRoom = RoomModel(
        id: 'r_user_custom',
        roomCode: 'PF-9999',
        gameTitle: 'Alex Party Room',
        hostName: current.name,
        currentPlayers: 1,
        maxPlayers: 50,
        isPrivate: false,
        status: 'Live Voice Party',
      );
      auth.addRoom(userRoom);
      expect(auth.activeRooms.any((r) => r.id == 'r_user_custom'), isTrue);

      // Upload custom music
      InAppMusicService().uploadCustomMusic(
        title: 'Alex Theme',
        genre: 'Synth',
        bpm: '128',
        audioPathOrUrl: '/storage/alex.mp3',
      );

      // Perform account deletion
      final res = auth.deleteCurrentUser();
      expect(res, isTrue);
      expect(auth.currentUser, isNull);
      expect(auth.activeRooms.any((r) => r.id == 'r_user_custom'), isFalse);
      expect(InAppMusicService().tracks.any((t) => t.title == 'Alex Theme'),
          isFalse);
    });
  });
}
