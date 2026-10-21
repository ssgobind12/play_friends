import 'package:flutter/services.dart';

/// GameSoundService: Provides haptic and system-sound feedback for game events.
/// Uses only Flutter built-in SystemSound and HapticFeedback (no audio assets needed).
class GameSoundService {
  static bool soundEnabled = true;

  // -------------------------------------------------------------------
  // LUDO SOUNDS
  // -------------------------------------------------------------------

  /// Dice roll shake feedback
  static Future<void> ludoDiceRoll() async {
    if (!soundEnabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.mediumImpact();
  }

  /// Token moved on board
  static Future<void> ludoTokenMove() async {
    if (!soundEnabled) return;
    await HapticFeedback.selectionClick();
  }

  /// Token captured / cut by opponent
  static Future<void> ludoTokenCaptured() async {
    if (!soundEnabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
  }

  /// Token reached safe star or home
  static Future<void> ludoTokenHome() async {
    if (!soundEnabled) return;
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
  }

  /// Game won
  static Future<void> ludoWin() async {
    if (!soundEnabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  // -------------------------------------------------------------------
  // TIC-TAC-TOE SOUNDS
  // -------------------------------------------------------------------

  /// Cell tapped / placed X or O
  static Future<void> ticTacToeCellTap() async {
    if (!soundEnabled) return;
    await HapticFeedback.selectionClick();
  }

  /// Game won
  static Future<void> ticTacToeWin() async {
    if (!soundEnabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// Draw / tie
  static Future<void> ticTacToeDraw() async {
    if (!soundEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  // -------------------------------------------------------------------
  // CARROM SOUNDS
  // -------------------------------------------------------------------

  /// Striker flicked
  static Future<void> carromStrike() async {
    if (!soundEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Coin pocketed
  static Future<void> carromCoinPocketed() async {
    if (!soundEnabled) return;
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await SystemSound.play(SystemSoundType.click);
  }

  // -------------------------------------------------------------------
  // SPACE DODGE SOUNDS
  // -------------------------------------------------------------------

  /// Ship destroyed / hit by asteroid
  static Future<void> spaceDodgeHit() async {
    if (!soundEnabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
  }

  /// Star / bonus item collected
  static Future<void> spaceDodgeStar() async {
    if (!soundEnabled) return;
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 40));
    await HapticFeedback.lightImpact();
  }

  /// Game over
  static Future<void> gameOver() async {
    if (!soundEnabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await HapticFeedback.heavyImpact();
  }

  // -------------------------------------------------------------------
  // UI SOUNDS
  // -------------------------------------------------------------------

  static Future<void> buttonTap() async {
    if (!soundEnabled) return;
    await SystemSound.play(SystemSoundType.click);
  }

  static Future<void> errorFeedback() async {
    if (!soundEnabled) return;
    await HapticFeedback.heavyImpact();
  }
}
