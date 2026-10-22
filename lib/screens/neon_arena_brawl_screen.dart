import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/game_sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/music_player_sheet.dart';

enum BrawlDifficulty { easy, medium, hard }

class NeonArenaBrawlScreen extends StatefulWidget {
  const NeonArenaBrawlScreen({super.key});

  @override
  State<NeonArenaBrawlScreen> createState() => _NeonArenaBrawlScreenState();
}

class _NeonArenaBrawlScreenState extends State<NeonArenaBrawlScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _loop;

  // Player 1 (User)
  double _p1X = 0.25;
  double _p1Y = 0.5;
  int _p1Hp = 100;
  bool _p1Attacking = false;
  bool _p1Shielding = false;

  // Player 2 (AI Bot)
  double _p2X = 0.75;
  double _p2Y = 0.5;
  int _p2Hp = 100;
  bool _p2Attacking = false;

  // Projectiles
  final List<Point<double>> _p1Lasers = [];
  final List<Point<double>> _p2Lasers = [];

  BrawlDifficulty _difficulty = BrawlDifficulty.medium;
  bool _isGameOver = false;
  Timer? _aiTimer;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_updatePhysics);
    _resetGame();
  }

  @override
  void dispose() {
    _loop.dispose();
    _aiTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _p1X = 0.25;
      _p1Y = 0.5;
      _p1Hp = 100;
      _p1Attacking = false;
      _p1Shielding = false;

      _p2X = 0.75;
      _p2Y = 0.5;
      _p2Hp = 100;
      _p2Attacking = false;

      _p1Lasers.clear();
      _p2Lasers.clear();
      _isGameOver = false;
    });

    _loop.repeat();
    _startAi();
  }

  void _startAi() {
    _aiTimer?.cancel();
    final interval = _difficulty == BrawlDifficulty.easy
        ? const Duration(milliseconds: 800)
        : (_difficulty == BrawlDifficulty.medium
            ? const Duration(milliseconds: 450)
            : const Duration(milliseconds: 250));

    _aiTimer = Timer.periodic(interval, (_) {
      if (_isGameOver || !mounted) return;

      final rng = Random();
      final dist = sqrt(pow(_p2X - _p1X, 2) + pow(_p2Y - _p1Y, 2));

      setState(() {
        // Move towards or evade
        if (dist > 0.3) {
          _p2X += (_p1X > _p2X ? 0.04 : -0.04);
          _p2Y += (_p1Y > _p2Y ? 0.04 : -0.04);
        } else {
          // Close combat
          if (rng.nextBool()) {
            _p2Attacking = true;
            GameSoundService.carromStrike();
            if (!_p1Shielding) {
              _p1Hp = (_p1Hp - 12).clamp(0, 100);
              GameSoundService.spaceDodgeHit();
            }
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) setState(() => _p2Attacking = false);
            });
          } else {
            // Shoot laser
            _p2Lasers.add(Point(_p2X - 0.05, _p2Y));
            GameSoundService.buttonTap();
          }
        }
        _p2X = _p2X.clamp(0.1, 0.9);
        _p2Y = _p2Y.clamp(0.15, 0.85);

        if (_p1Hp <= 0) {
          _onMatchEnd(won: false);
        }
      });
    });
  }

  void _updatePhysics() {
    if (_isGameOver) return;

    // Move P1 Lasers
    for (int i = _p1Lasers.length - 1; i >= 0; i--) {
      final l = _p1Lasers[i];
      final nextX = l.x + 0.02;
      _p1Lasers[i] = Point(nextX, l.y);

      // Check hit on P2
      final dist = sqrt(pow(nextX - _p2X, 2) + pow(l.y - _p2Y, 2));
      if (dist < 0.08) {
        _p1Lasers.removeAt(i);
        _p2Hp = (_p2Hp - 18).clamp(0, 100);
        GameSoundService.spaceDodgeHit();
        if (_p2Hp <= 0) {
          _onMatchEnd(won: true);
          return;
        }
      } else if (nextX > 1.0) {
        _p1Lasers.removeAt(i);
      }
    }

    // Move P2 Lasers
    for (int i = _p2Lasers.length - 1; i >= 0; i--) {
      final l = _p2Lasers[i];
      final nextX = l.x - 0.02;
      _p2Lasers[i] = Point(nextX, l.y);

      // Check hit on P1
      final dist = sqrt(pow(nextX - _p1X, 2) + pow(l.y - _p1Y, 2));
      if (dist < 0.08) {
        _p2Lasers.removeAt(i);
        if (!_p1Shielding) {
          _p1Hp = (_p1Hp - 18).clamp(0, 100);
          GameSoundService.spaceDodgeHit();
          if (_p1Hp <= 0) {
            _onMatchEnd(won: false);
            return;
          }
        }
      } else if (nextX < 0.0) {
        _p2Lasers.removeAt(i);
      }
    }

    setState(() {});
  }

  void _p1Punch() {
    if (_isGameOver || _p1Attacking) return;
    setState(() => _p1Attacking = true);
    GameSoundService.carromStrike();

    final dist = sqrt(pow(_p2X - _p1X, 2) + pow(_p2Y - _p1Y, 2));
    if (dist < 0.22) {
      setState(() {
        _p2Hp = (_p2Hp - 20).clamp(0, 100);
        _p2X = (_p2X + 0.08).clamp(0.1, 0.9); // Knockback
      });
      GameSoundService.spaceDodgeHit();
      if (_p2Hp <= 0) {
        _onMatchEnd(won: true);
        return;
      }
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _p1Attacking = false);
    });
  }

  void _p1ShootLaser() {
    if (_isGameOver) return;
    GameSoundService.buttonTap();
    setState(() {
      _p1Lasers.add(Point(_p1X + 0.06, _p1Y));
    });
  }

  void _onMatchEnd({required bool won}) {
    _isGameOver = true;
    _loop.stop();
    _aiTimer?.cancel();

    if (won) {
      GameSoundService.ludoWin();
    } else {
      GameSoundService.gameOver();
    }

    final unlocked =
        AuthService().recordMatchResult(gameId: 'arena_brawl', won: won);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(won ? Icons.emoji_events_rounded : Icons.cancel_rounded,
                color: won ? AppColors.trophyGold : AppColors.dangerRose,
                size: 28),
            const SizedBox(width: 10),
            Text(won ? 'Victory in Arena!' : 'Brawler Defeated!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(won
                ? 'You knocked out the neon champion!'
                : 'Great combat attempt. Boost your reflexes and try again!'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(Icons.bolt_rounded, won ? '+100 XP' : '+30 XP',
                      AppColors.primaryBlueLight),
                  _statItem(Icons.monetization_on_rounded,
                      won ? '+50 Coins' : '+15 Coins', AppColors.coinAmber),
                ],
              ),
            ),
            if (unlocked != null) ...[
              const SizedBox(height: 10),
              Text('🎉 UNLOCKED: $unlocked!',
                  style: const TextStyle(
                      color: AppColors.onlineGreen,
                      fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Exit Arena'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetGame();
            },
            child: const Text('Rematch'),
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      appBar: AppBar(
        title: const Text('Neon Arena Brawl',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.music_note_rounded),
            tooltip: 'Music Store',
            onPressed: () => MusicPlayerSheet.show(context),
          ),
          PopupMenuButton<BrawlDifficulty>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Difficulty: ${_difficulty.name.toUpperCase()}',
            initialValue: _difficulty,
            onSelected: (mode) {
              setState(() => _difficulty = mode);
              _resetGame();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: BrawlDifficulty.easy,
                  child: Text(
                      'Easy ${_difficulty == BrawlDifficulty.easy ? "✓" : ""}')),
              PopupMenuItem(
                  value: BrawlDifficulty.medium,
                  child: Text(
                      'Medium ${_difficulty == BrawlDifficulty.medium ? "✓" : ""}')),
              PopupMenuItem(
                  value: BrawlDifficulty.hard,
                  child: Text(
                      'Hard ${_difficulty == BrawlDifficulty.hard ? "✓" : ""}')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetGame,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Health Bars
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('You (Cyan Knight)',
                            style: TextStyle(
                                color: AppColors.accentCyan,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: _p1Hp / 100.0,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation(
                              AppColors.accentCyan),
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('AI Bot (${_difficulty.name.toUpperCase()})',
                            style: const TextStyle(
                                color: AppColors.dangerRose,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: _p2Hp / 100.0,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation(
                              AppColors.dangerRose),
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Arena Canvas
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;

                  return Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: AppColors.primaryPurple.withValues(alpha: 0.5),
                          width: 3),
                      boxShadow: [
                        BoxShadow(
                            color:
                                AppColors.primaryPurple.withValues(alpha: 0.3),
                            blurRadius: 18),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Lasers P1
                        ..._p1Lasers.map((l) => Positioned(
                              left: l.x * w,
                              top: l.y * h,
                              child: Container(
                                width: 14,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.accentCyan,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: AppColors.accentCyan,
                                        blurRadius: 8)
                                  ],
                                ),
                              ),
                            )),

                        // Lasers P2
                        ..._p2Lasers.map((l) => Positioned(
                              left: l.x * w,
                              top: l.y * h,
                              child: Container(
                                width: 14,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.dangerRose,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: AppColors.dangerRose,
                                        blurRadius: 8)
                                  ],
                                ),
                              ),
                            )),

                        // Player 1 Fighter
                        Positioned(
                          left: (_p1X * w) - 22,
                          top: (_p1Y * h) - 22,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(colors: [
                                AppColors.accentCyan,
                                Color(0xFF0284C7)
                              ]),
                              border: Border.all(
                                color:
                                    _p1Shielding ? Colors.amber : Colors.white,
                                width: _p1Shielding ? 4 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _p1Shielding
                                      ? Colors.amber
                                      : AppColors.accentCyan,
                                  blurRadius: _p1Attacking ? 20 : 10,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.flash_on_rounded,
                                  color: Colors.white, size: 24),
                            ),
                          ),
                        ),

                        // Player 2 Fighter (AI)
                        Positioned(
                          left: (_p2X * w) - 22,
                          top: (_p2Y * h) - 22,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(colors: [
                                AppColors.dangerRose,
                                Color(0xFF991B1B)
                              ]),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.dangerRose,
                                  blurRadius: _p2Attacking ? 20 : 10,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.smart_toy_rounded,
                                  color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // D-Pad navigation
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_upward_rounded),
                        onPressed: () => setState(
                            () => _p1Y = (_p1Y - 0.08).clamp(0.15, 0.85)),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () => setState(
                                () => _p1X = (_p1X - 0.08).clamp(0.1, 0.9)),
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded),
                            onPressed: () => setState(
                                () => _p1X = (_p1X + 0.08).clamp(0.1, 0.9)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward_rounded),
                        onPressed: () => setState(
                            () => _p1Y = (_p1Y + 0.08).clamp(0.15, 0.85)),
                      ),
                    ],
                  ),

                  // Action Buttons
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _p1Punch,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sports_mma_rounded, size: 22),
                            SizedBox(height: 4),
                            Text('Punch',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _p1ShootLaser,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 22),
                            SizedBox(height: 4),
                            Text('Laser',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          setState(() => _p1Shielding = !_p1Shielding);
                          GameSoundService.buttonTap();
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                _p1Shielding
                                    ? Icons.shield_rounded
                                    : Icons.shield_outlined,
                                size: 22),
                            const SizedBox(height: 4),
                            Text(_p1Shielding ? 'Block' : 'Shield',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
