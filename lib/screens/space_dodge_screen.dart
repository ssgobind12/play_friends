import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class Asteroid {
  double x;
  double y;
  final double radius;
  final double speed;
  Asteroid({required this.x, required this.y, required this.radius, required this.speed});
}

class SpaceItem {
  double x;
  double y;
  final bool isStar;
  SpaceItem({required this.x, required this.y, required this.isStar});
}

class SpaceDodgeGameScreen extends StatefulWidget {
  const SpaceDodgeGameScreen({super.key});

  @override
  State<SpaceDodgeGameScreen> createState() => _SpaceDodgeGameScreenState();
}

typedef SpaceDodgeScreen = SpaceDodgeGameScreen;

class _SpaceDodgeGameScreenState extends State<SpaceDodgeGameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _gameLoop;
  double _shipX = 0.5; // normalized 0..1
  double _shipY = 0.8;
  final List<Asteroid> _asteroids = [];
  final List<SpaceItem> _items = [];
  int _score = 0;
  int _lives = 3;
  bool _isPlaying = true;
  int _secondsSurvived = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _gameLoop = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_updateGame);
    _startGame();
  }

  @override
  void dispose() {
    _gameLoop.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _asteroids.clear();
    _items.clear();
    _score = 0;
    _lives = 3;
    _secondsSurvived = 0;
    _shipX = 0.5;
    _shipY = 0.8;
    _isPlaying = true;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isPlaying) return;
      setState(() {
        _secondsSurvived++;
        _score += 5;
      });
      // Spawn asteroid
      if (Random().nextDouble() < 0.85) {
        _asteroids.add(Asteroid(
          x: Random().nextDouble(),
          y: -0.1,
          radius: 12 + Random().nextDouble() * 16,
          speed: 0.006 + (_secondsSurvived * 0.0002),
        ));
      }
      // Spawn bonus items
      if (Random().nextDouble() < 0.4) {
        _items.add(SpaceItem(
          x: Random().nextDouble(),
          y: -0.1,
          isStar: Random().nextBool(),
        ));
      }
    });

    _gameLoop.repeat();
  }

  void _updateGame() {
    if (!_isPlaying) return;

    // Move asteroids
    for (final a in _asteroids) {
      a.y += a.speed;
    }
    // Move items
    for (final item in _items) {
      item.y += 0.008;
    }

    // Check ship collisions with asteroids
    final toRemoveAsteroids = <Asteroid>[];
    for (final a in _asteroids) {
      final dx = a.x - _shipX;
      final dy = a.y - _shipY;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 0.07) {
        toRemoveAsteroids.add(a);
        _lives--;
        if (_lives <= 0) {
          _gameOver();
          return;
        }
      } else if (a.y > 1.1) {
        toRemoveAsteroids.add(a);
      }
    }
    _asteroids.removeWhere(toRemoveAsteroids.contains);

    // Check item pickups
    final toRemoveItems = <SpaceItem>[];
    for (final item in _items) {
      final dx = item.x - _shipX;
      final dy = item.y - _shipY;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 0.08) {
        toRemoveItems.add(item);
        _score += item.isStar ? 50 : 25;
      } else if (item.y > 1.1) {
        toRemoveItems.add(item);
      }
    }
    _items.removeWhere(toRemoveItems.contains);

    setState(() {});
  }

  void _gameOver() {
    _isPlaying = false;
    _gameLoop.stop();
    _timer?.cancel();

    final won = _score >= 150 || _secondsSurvived >= 30;
    final unlockedTitle = AuthService().recordMatchResult(
      gameId: 'space_dodge',
      won: won,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(won ? Icons.military_tech_rounded : Icons.cancel_rounded, color: won ? AppColors.coinAmber : AppColors.dangerRose),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                won ? 'Mission Complete!' : 'Spaceship Down!',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Final Score: $_score Points • Survived: ${_secondsSurvived}s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              won ? 'Heroic piloting skills! Target survived.' : 'Asteroid hit! Upgrade your reflexes and try again.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _rewardBadge(Icons.bolt_rounded, won ? '+100 XP' : '+30 XP', AppColors.primaryBlueLight),
                _rewardBadge(Icons.monetization_on_rounded, won ? '+50 Coins' : '+15 Coins', AppColors.coinAmber),
                _rewardBadge(Icons.timer_rounded, '${_secondsSurvived}s', AppColors.onlineGreen),
              ],
            ),
            if (unlockedTitle != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primaryPurple, AppColors.accentCyan]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('🎉 NEW GAME UNLOCKED: $unlockedTitle!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Exit Arcade', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
            onPressed: () {
              Navigator.of(ctx).pop();
              _startGame();
            },
            child: const Text('Play Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _rewardBadge(IconData icon, String text, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Cyber Space Dodge', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Score: $_score', style: const TextStyle(color: AppColors.coinAmber, fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(
                    children: List.generate(
                      3,
                      (i) => Icon(
                        i < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                  ),
                  Text('Time: ${_secondsSurvived}s', style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onPanUpdate: (details) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    setState(() {
                      _shipX = (details.globalPosition.dx / renderBox.size.width).clamp(0.08, 0.92);
                      _shipY = ((details.globalPosition.dy - 100) / (renderBox.size.height - 180)).clamp(0.1, 0.9);
                    });
                  }
                },
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1124),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.4)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Stars background
                        Positioned.fill(
                          child: CustomPaint(painter: _StarFieldPainter()),
                        ),
                        // Asteroids
                        ..._asteroids.map((a) => Positioned(
                              left: a.x * 320,
                              top: a.y * 500,
                              child: Container(
                                width: a.radius * 2,
                                height: a.radius * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(colors: [Color(0xFF64748B), Color(0xFF334155)]),
                                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.6)),
                                ),
                              ),
                            )),
                        // Bonus Items
                        ..._items.map((item) => Positioned(
                              left: item.x * 320,
                              top: item.y * 500,
                              child: Icon(
                                item.isStar ? Icons.star_rounded : Icons.diamond_rounded,
                                color: item.isStar ? Colors.amber : AppColors.accentCyan,
                                size: 22,
                              ),
                            )),
                        // Spaceship
                        Positioned(
                          left: (_shipX * 320) - 20,
                          top: (_shipY * 500) - 20,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(colors: [AppColors.accentCyan, AppColors.primaryPurple]),
                              boxShadow: [
                                BoxShadow(color: AppColors.accentCyan.withValues(alpha: 0.7), blurRadius: 12),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.navigation_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text('Drag across the screen to steer spaceship & dodge asteroids!', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(42);
    final paint = Paint()..color = Colors.white24;
    for (int i = 0; i < 40; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height), 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
