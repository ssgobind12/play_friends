import 'package:flutter_test/flutter_test.dart';
import 'package:play_friends/models/room_model.dart';
import 'package:play_friends/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService().resetStatsForTesting();
  });

  group('Game Progression & Level Unlock Tests', () {
    test('Initial user starts clean at Level 1 with 0 wins and only Tic-Tac-Toe unlocked', () {
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

    test('Winning 20 games levels up player to Level 5 and unlocks Ludo Friends', () {
      expect(AuthService().isGameUnlocked('ludo'), isFalse);

      String? lastUnlocked;
      for (int i = 0; i < 20; i++) {
        final unlocked = AuthService().recordMatchResult(gameId: 'tic_tac_toe', won: true);
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
  });
}
