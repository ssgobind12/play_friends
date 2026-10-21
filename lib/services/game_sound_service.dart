import 'package:flutter/services.dart';

/// GameSoundService: Provides real audible sound and haptic feedback for game events.
/// Uses native Android AudioTrack / STREAM_MUSIC for real game audio + HapticFeedback.
class GameSoundService {
  static bool soundEnabled = true;
  static const MethodChannel _channel = MethodChannel('com.playfriends.game_sound');

  static Future<void> _playNative(String sound) async {
    if (!soundEnabled) return;
    try {
      await _channel.invokeMethod('play', {'sound': sound});
    } catch (_) {
      // Ignored for tests or non-Android environments
    }
  }

  // -------------------------------------------------------------------
  // LUDO SOUNDS
  // -------------------------------------------------------------------

  /// Dice roll sound & shake feedback
  static Future<void> ludoDiceRoll() async {
    if (!soundEnabled) return;
    _playNative('diceRoll');
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Token moved on board
  static Future<void> ludoTokenMove() async {
    if (!soundEnabled) return;
    _playNative('tokenMove');
    await HapticFeedback.selectionClick();
  }

  /// Token captured / cut by opponent
  static Future<void> ludoTokenCaptured() async {
    if (!soundEnabled) return;
    _playNative('tokenCaptured');
    await HapticFeedback.heavyImpact();
  }

  /// Token reached safe star or home
  static Future<void> ludoTokenHome() async {
    if (!soundEnabled) return;
    _playNative('tokenHome');
    await HapticFeedback.lightImpact();
  }

  /// Game won
  static Future<void> ludoWin() async {
    if (!soundEnabled) return;
    _playNative('win');
    await HapticFeedback.heavyImpact();
  }

  // -------------------------------------------------------------------
  // TIC-TAC-TOE SOUNDS
  // -------------------------------------------------------------------

  /// Cell tapped / placed X or O
  static Future<void> ticTacToeCellTap() async {
    if (!soundEnabled) return;
    _playNative('cellTap');
    await HapticFeedback.selectionClick();
  }

  /// Game won
  static Future<void> ticTacToeWin() async {
    if (!soundEnabled) return;
    _playNative('win');
    await HapticFeedback.heavyImpact();
  }

  /// Draw / tie
  static Future<void> ticTacToeDraw() async {
    if (!soundEnabled) return;
    _playNative('draw');
    await HapticFeedback.mediumImpact();
  }

  // -------------------------------------------------------------------
  // CARROM SOUNDS
  // -------------------------------------------------------------------

  /// Striker flicked
  static Future<void> carromStrike() async {
    if (!soundEnabled) return;
    _playNative('strike');
    await HapticFeedback.mediumImpact();
  }

  /// Coin pocketed
  static Future<void> carromCoinPocketed() async {
    if (!soundEnabled) return;
    _playNative('pocket');
    await HapticFeedback.lightImpact();
  }

  // -------------------------------------------------------------------
  // SPACE DODGE SOUNDS
  // -------------------------------------------------------------------

  /// Ship destroyed / hit by asteroid
  static Future<void> spaceDodgeHit() async {
    if (!soundEnabled) return;
    _playNative('hit');
    await HapticFeedback.heavyImpact();
  }

  /// Star / bonus item collected
  static Future<void> spaceDodgeStar() async {
    if (!soundEnabled) return;
    _playNative('star');
    await HapticFeedback.lightImpact();
  }

  /// Game over
  static Future<void> gameOver() async {
    if (!soundEnabled) return;
    _playNative('gameOver');
    await HapticFeedback.heavyImpact();
  }

  // -------------------------------------------------------------------
  // UI SOUNDS
  // -------------------------------------------------------------------

  static Future<void> buttonTap() async {
    if (!soundEnabled) return;
    _playNative('cellTap');
    await SystemSound.play(SystemSoundType.click);
  }

  static Future<void> errorFeedback() async {
    if (!soundEnabled) return;
    _playNative('draw');
    await HapticFeedback.heavyImpact();
  }
}
