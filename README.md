# 🎮 Play Friends - Social Gaming Application

**Play Friends** is an Android-first social gaming mobile application built with Flutter & Material 3. It features a modern dark navy theme with vibrant purple and cyan accents, rounded cards, clean typography, interactive social mockups, and a fully playable local Tic-Tac-Toe game engine (supporting 2-player Pass & Play and a smart AI opponent).

---

## 📱 Features & Screens

1. **Home Screen (`lib/screens/home_screen.dart`)**:
   - Player profile header with level badge (`Level 14 - Master`), coin counter (`1,450`), and quick-access chat button.
   - Highlighted quick-action card for **Playable Tic-Tac-Toe Duel**.
   - Action tiles: **Create Room** and **Join Room**.
   - **Online Friends Reel**: Horizontally scrollable avatars with live status indicators and instant invite triggers.
   - **Featured Games**: Highlighting Tic-Tac-Toe, Ludo Friends, and Carrom Clash.

2. **Games Arcade (`lib/screens/games_screen.dart`)**:
   - Filterable categories: *All*, *Board Games*, *Action Games*, and *Casual*.
   - Live search bar filtering by game title and keywords.
   - Game cards with player counts, star ratings, and status tags (`PLAYABLE NOW` vs `DEMO PREVIEW`).
   - Direct launch into the playable Tic-Tac-Toe game.

3. **Playable Local Tic-Tac-Toe Engine (`lib/screens/tic_tac_toe_screen.dart`)**:
   - **Pass & Play Mode**: Local 2-player hotseat duel on one device.
   - **Vs AI Bot Mode**: Challenge a smart automated opponent with offensive/defensive strategy.
   - Real-time score tracking: Player X wins, Player O wins, and Draws.
   - Visual winning pattern highlight across rows, columns, and diagonals.
   - Interactive game over dialog with quick rematch or board inspection options.

4. **Friends Squad (`lib/screens/friends_screen.dart`)**:
   - Filter tabs: *All Friends (6)*, *Online (4)*, and *Requests (2)*.
   - Player cards with avatars, online status dots, level badges, and favorite games.
   - **Add Friend Modal**: Input 6-character player tag (e.g. `PF-9914`) or copy own friend code (`PF-ALEX-14`).
   - Tap any friend to inspect mini profile sheet with quick invite and chat shortcuts.

5. **Rooms & Lobbies (`lib/screens/rooms_screen.dart`)**:
   - **Create Room**: Select game, max player limit (2, 4, 6), toggle private PIN lock, and generate custom room PIN (e.g. `PF-4912`).
   - **Join Room**: Enter 6-digit PIN code.
   - **Simulated Lobby View**: Host badges, player slots, ready toggles, and game launch.

6. **Social Chat (`lib/screens/chat_screen.dart`)**:
   - Tabbed view: *Direct Messages* and *Room Chats*.
   - Interactive conversation thread with speech bubbles, timestamps, and active message composer.
   - Send simulated local messages that appear instantly in the chat log.

7. **Profile & Settings (`lib/screens/profile_screen.dart`)**:
   - Player avatar, rank, and XP progress bar (7,420 / 10,000 XP towards Level 15).
   - Stats grid: Total Matches (152), Win Rate (68.5%), Trophies (28), and Best Streak (5 Wins).
   - Toggles: Sound Effects, Haptic Vibration, Notifications.
   - Fair play & non-gambling disclaimer dialog.

---

## 🎨 Design System

- **Background:** Deep Navy (`#0B0E1B` / `#131A2E`)
- **Primary Accent:** Neon Violet (`#8B5CF6`)
- **Secondary Accent:** Cyber Cyan (`#06B6D4`)
- **Status Accents:** Emerald Green (`#10B981`), Amber Gold (`#F59E0B`), Rose (`#F43F5E`)
- **Cards:** Rounded rectangles (18–24dp) with subtle glowing border strokes (`#2E8B5CF6`).

---

## 🚀 How to Run the App on Android

### Prerequisites
1. **Flutter SDK**: Ensure Flutter is installed and added to your `PATH`.
2. **Android SDK**: Present at `C:\Users\Admin\AppData\Local\Android\Sdk`.
3. **Java JDK**: Present at `C:\Program Files\Java\jdk-21`.

### Option A: Running on an Android Emulator
1. Open Android Studio or run the emulator command:
   ```powershell
   & "$HOME\AppData\Local\Android\Sdk\emulator\emulator.exe" -list-avds
   & "$HOME\AppData\Local\Android\Sdk\emulator\emulator.exe" -avd <Your_AVD_Name>
   ```
2. Navigate to the project directory:
   ```powershell
   cd c:\Users\Admin\Desktop\Game\play_friends
   ```
3. Fetch dependencies:
   ```powershell
   flutter pub get
   ```
4. Run the app:
   ```powershell
   flutter run
   ```

### Option B: Running on a Physical Android Phone
1. On your Android phone, enable **Developer Options**:
   - Go to **Settings > About Phone** and tap **Build Number** 7 times.
   - Go to **Settings > System > Developer Options** and enable **USB Debugging**.
2. Connect your phone to your PC with a USB cable.
3. Check that the device is detected:
   ```powershell
   & "$HOME\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices
   ```
4. Run on your physical device:
   ```powershell
   cd c:\Users\Admin\Desktop\Game\play_friends
   flutter run -d android
   ```

### Option C: Build an APK for Manual Installation
To build a standalone APK file to transfer and install on any Android phone:
```powershell
cd c:\Users\Admin\Desktop\Game\play_friends
flutter build apk --debug
```
The output APK will be generated at:
`build\app\outputs\flutter-apk\app-debug.apk`

---

## 🧪 Testing & Verification

1. **Run standalone logic test:**
   ```powershell
   cd c:\Users\Admin\Desktop\Game\play_friends
   dart run test/verify_logic.dart
   ```
   *Result:* All 8 win conditions, draws, rows, columns, and diagonal patterns are validated with 0 failures.

2. **Run Flutter widget & integration tests:**
   ```powershell
   cd c:\Users\Admin\Desktop\Game\play_friends
   flutter test
   ```

---

## ⚖️ Non-Gambling & Demo Notice
Play Friends is built strictly for social gaming entertainment:
- **No real-money betting**, cash prizes, or in-app payment processing.
- All coins, gems, and trophies are free virtual points for demo purposes.
- Local Tic-Tac-Toe is 100% playable offline without requiring API keys or cloud backend services.
