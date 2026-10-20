import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/games_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/rooms_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PlayFriendsApp());
}

class PlayFriendsApp extends StatelessWidget {
  const PlayFriendsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Play Friends',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: ListenableBuilder(
        listenable: AuthService(),
        builder: (context, _) {
          if (!AuthService().isAuthenticated) {
            return const LoginScreen();
          }
          return const MainNavigationScaffold();
        },
      ),
    );
  }
}

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;

  void _onSelectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openRoomsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RoomsScreen()),
    );
  }

  void _openChatScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onNavigateTab: _onSelectTab,
        onOpenRooms: _openRoomsScreen,
        onOpenChat: _openChatScreen,
      ),
      const GamesScreen(),
      FriendsScreen(
        onOpenChat: _openChatScreen,
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.cardBorder, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onSelectTab,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_esports_outlined),
              activeIcon: Icon(Icons.sports_esports_rounded),
              label: 'Games',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded),
              activeIcon: Icon(Icons.people_rounded),
              label: 'Friends',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
