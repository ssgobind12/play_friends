import 'package:flutter_test/flutter_test.dart';
import 'package:play_friends/models/room_model.dart';
import 'package:play_friends/models/room_theme_model.dart';
import 'package:play_friends/services/aws_storage_service.dart';
import 'package:play_friends/services/in_app_music_service.dart';
import 'package:play_friends/services/privacy_filter_service.dart';
import 'package:play_friends/services/voice_room_manager.dart';

void main() {
  group('PrivacyFilterService Tests', () {
    test('Allows safe room messages', () {
      expect(PrivacyFilterService.checkMessage('Hey everyone, welcome to the voice room!').isAllowed, isTrue);
      expect(PrivacyFilterService.checkMessage('Let us play Ludo and Word Rush!').isAllowed, isTrue);
      expect(PrivacyFilterService.checkMessage('GG nice game!').isAllowed, isTrue);
    });

    test('Blocks phone numbers', () {
      expect(PrivacyFilterService.checkMessage('Call me on 9876543210').isAllowed, isFalse);
      expect(PrivacyFilterService.checkMessage('My number is 85730 29430').isAllowed, isFalse);
      expect(PrivacyFilterService.checkMessage('+91-9876543210 WhatsApp me').isAllowed, isFalse);
    });

    test('Blocks email addresses', () {
      expect(PrivacyFilterService.checkMessage('Email me at ssgobind12@gmail.com').isAllowed, isFalse);
      expect(PrivacyFilterService.checkMessage('Contact: user@domain.com').isAllowed, isFalse);
    });

    test('Blocks external social media handles', () {
      expect(PrivacyFilterService.checkMessage('My insta id is @cool_gamer').isAllowed, isFalse);
      expect(PrivacyFilterService.checkMessage('Follow my instagram: gamer123').isAllowed, isFalse);
      expect(PrivacyFilterService.checkMessage('Add me on telegram: t.me/myhandle').isAllowed, isFalse);
      expect(PrivacyFilterService.checkMessage('Join my whatsapp group: chat.whatsapp.com/xyz').isAllowed, isFalse);
      expect(PrivacyFilterService.checkMessage('My snapchat is coolguy_99').isAllowed, isFalse);
    });
  });

  group('LevelProgressionService Tests', () {
    test('Calculates level based on coin thresholds (1000, 3000, 5000, 8000, 12000)', () {
      expect(LevelProgressionService.calculateLevel(0), equals(1));
      expect(LevelProgressionService.calculateLevel(500), equals(1));
      expect(LevelProgressionService.calculateLevel(999), equals(1));
      expect(LevelProgressionService.calculateLevel(1000), equals(2));
      expect(LevelProgressionService.calculateLevel(2500), equals(2));
      expect(LevelProgressionService.calculateLevel(3000), equals(3));
      expect(LevelProgressionService.calculateLevel(4999), equals(3));
      expect(LevelProgressionService.calculateLevel(5000), equals(4));
      expect(LevelProgressionService.calculateLevel(7999), equals(4));
      expect(LevelProgressionService.calculateLevel(8000), equals(5));
      expect(LevelProgressionService.calculateLevel(11999), equals(5));
      expect(LevelProgressionService.calculateLevel(12000), equals(6));
      expect(LevelProgressionService.calculateLevel(50000), equals(6));
    });

    test('Returns next level target correctly', () {
      expect(LevelProgressionService.coinsForNextLevel(500), equals(1000));
      expect(LevelProgressionService.coinsForNextLevel(1500), equals(3000));
      expect(LevelProgressionService.coinsForNextLevel(3500), equals(5000));
      expect(LevelProgressionService.coinsForNextLevel(6000), equals(8000));
      expect(LevelProgressionService.coinsForNextLevel(9000), equals(12000));
    });
  });

  group('VoiceRoomManager Tests', () {
    const testRoom = RoomModel(
      id: 'test_1',
      roomCode: 'PF-9999',
      gameTitle: 'Music Party',
      hostName: 'HostPlayer',
      currentPlayers: 1,
      maxPlayers: 100,
      isPrivate: false,
      status: 'Live',
    );

    setUp(() {
      VoiceRoomManager().leaveRoom();
    });

    test('Host is automatically room admin and can control music', () {
      final manager = VoiceRoomManager();
      manager.joinRoom(testRoom);

      expect(manager.hasActiveRoom, isTrue);
      expect(manager.canControlMusic('HostPlayer'), isTrue);
      expect(manager.canControlMusic('RandomGuest'), isFalse);
    });

    test('Host can assign and remove room admins who can control music', () {
      final manager = VoiceRoomManager();
      manager.joinRoom(testRoom);

      expect(manager.canControlMusic('Guest1'), isFalse);

      manager.toggleAdminPermission('Guest1');
      expect(manager.canControlMusic('Guest1'), isTrue);

      manager.toggleAdminPermission('Guest1');
      expect(manager.canControlMusic('Guest1'), isFalse);
    });

    test('Follow room and follow user toggles work', () {
      final manager = VoiceRoomManager();
      const roomCode = 'TEST-ROOM-123';
      const userName = 'TestFriend99';

      expect(manager.isFollowingRoom(roomCode), isFalse);
      manager.toggleFollowRoom(roomCode);
      expect(manager.isFollowingRoom(roomCode), isTrue);
      manager.toggleFollowRoom(roomCode);
      expect(manager.isFollowingRoom(roomCode), isFalse);

      expect(manager.isFollowingUser(userName), isFalse);
      manager.toggleFollowUser(userName);
      expect(manager.isFollowingUser(userName), isTrue);
      manager.toggleFollowUser(userName);
      expect(manager.isFollowingUser(userName), isFalse);
    });

    test('Room join starts silent and does not auto-play music', () {
      final manager = VoiceRoomManager();
      final music = InAppMusicService();

      manager.joinRoom(testRoom);
      expect(music.isPlaying, isFalse);
    });
  });

  group('Room Themes Tests', () {
    test('Provides exactly 10 distinct room themes', () {
      expect(RoomThemeData.presetThemes.length, equals(10));
      final ids = RoomThemeData.presetThemes.map((t) => t.id).toSet();
      expect(ids.length, equals(10));
    });
  });

  group('Server Photo & Song Storage Tests', () {
    test('Server updates and deletes user profile photo', () async {
      const userId = 'user_photo_test';
      const email = 'photo_test@example.com';
      const photoUri = 'data:image/jpeg;base64,mockphotodata';

      final saveSuccess = await AwsStorageService.updateUserProfilePhoto(
        userId: userId,
        email: email,
        profilePhoto: photoUri,
      );
      expect(saveSuccess, isTrue);

      final deleteSuccess = await AwsStorageService.deleteUserProfilePhoto(
        userId: userId,
        email: email,
      );
      expect(deleteSuccess, isTrue);
    });

    test('Server stores and fetches user uploaded songs', () async {
      const userId = 'user_song_test';

      await AwsStorageService.uploadSongToServer(
        userId: userId,
        songId: 99,
        title: 'Server Beat 1',
        genre: 'Lofi',
        bpm: '90 BPM',
        audioPathOrUrl: '/path/song.mp3',
      );

      final userSongs = await AwsStorageService.getUserSongsFromServer(userId);
      expect(userSongs.any((s) => s['title'] == 'Server Beat 1'), isTrue);

      await AwsStorageService.deleteSongFromServer(userId: userId, songId: 99);
      final remaining = await AwsStorageService.getUserSongsFromServer(userId);
      expect(remaining.any((s) => s['title'] == 'Server Beat 1'), isFalse);
    });
  });
}
