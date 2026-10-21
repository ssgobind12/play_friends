import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_friends/main.dart';
import 'package:play_friends/screens/tic_tac_toe_screen.dart';
import 'package:play_friends/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService().resetStatsForTesting();
  });

  testWidgets('App renders Home screen with BottomNavigationBar', (WidgetTester tester) async {
    AuthService().login('alex@playfriends.io', 'password123');
    await tester.pumpWidget(const PlayFriendsApp());
    await tester.pumpAndSettle();

    // Verify app brand / greeting
    expect(find.text('Hey Alex!'), findsOneWidget);
    expect(find.text('Tic-Tac-Toe Duel'), findsWidgets);

    // Verify Bottom Navigation items
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Switch to Games tab
    await tester.tap(find.text('Games'));
    await tester.pumpAndSettle();
    expect(find.text('Game Arcade'), findsOneWidget);

    // Switch to Friends tab
    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();
    expect(find.text('Friends Squad'), findsOneWidget);

    // Switch to Profile tab
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Player Profile'), findsOneWidget);
    expect(find.text('Alex Vance'), findsOneWidget);
  });

  testWidgets('TicTacToe screen plays a local move', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TicTacToeScreen()));
    await tester.pumpAndSettle();

    // Verify scoreboard and turn indicator
    expect(find.text('Tic-Tac-Toe Arena'), findsOneWidget);
    expect(find.text("Player X's Turn"), findsOneWidget);

    // Tap center cell (index 4)
    final gridItems = find.byType(GestureDetector);
    expect(gridItems, findsWidgets);

    // Tap first grid cell
    await tester.tap(gridItems.at(3));
    await tester.pumpAndSettle();

    // Board should register move
    expect(find.text('X'), findsOneWidget);
  });

  testWidgets('Auth flow: Logout shows Login screen, Guest login works', (WidgetTester tester) async {
    AuthService().login('alex@playfriends.io', 'password123');
    await tester.pumpWidget(const PlayFriendsApp());
    await tester.pumpAndSettle();

    // Go to profile tab
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    // Scroll down to find Sign Out
    final signOutFinder = find.text('Sign Out / Switch Account');
    await tester.scrollUntilVisible(signOutFinder, 150);
    await tester.tap(signOutFinder);
    await tester.pumpAndSettle();

    // Dialog appears with Sign Out confirm button
    expect(find.text('Sign Out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Out'));
    await tester.pumpAndSettle();

    // Now on Login Screen
    expect(find.text('Play Friends'), findsWidgets);
    expect(find.text('Login to Play'), findsOneWidget);

    // Scroll down to reveal Continue as Guest
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();

    // Should be in Home screen as Guest
    expect(find.text('Hey Guest!'), findsOneWidget);
  });
}
