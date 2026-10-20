import 'dart:math';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class CarromPiece {
  Offset position;
  Offset velocity;
  final double radius;
  final Color color;
  final int points;
  final bool isStriker;
  bool isPocketed;

  CarromPiece({
    required this.position,
    this.velocity = Offset.zero,
    required this.radius,
    required this.color,
    required this.points,
    this.isStriker = false,
    this.isPocketed = false,
  });
}

class CarromGameScreen extends StatefulWidget {
  const CarromGameScreen({super.key});

  @override
  State<CarromGameScreen> createState() => _CarromGameScreenState();
}

class _CarromGameScreenState extends State<CarromGameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<CarromPiece> _pieces = [];
  late CarromPiece _striker;
  double _strikerX = 0.5; // normalized 0..1 along baseline
  Offset? _dragStart;
  Offset? _dragCurrent;
  int _score = 0;
  int _shotsRemaining = 8;
  bool _isMoving = false;
  final double _boardSize = 340.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_updatePhysics);
    _resetBoard();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _resetBoard() {
    _pieces.clear();
    _score = 0;
    _shotsRemaining = 8;
    _isMoving = false;
    _strikerX = 0.5;

    final center = Offset(_boardSize / 2, _boardSize / 2);

    // Red Queen in center
    _pieces.add(CarromPiece(
      position: center,
      radius: 12,
      color: const Color(0xFFEF4444),
      points: 25,
    ));

    // Circle of White and Black pieces
    const count = 8;
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi;
      final offset = Offset(cos(angle) * 32, sin(angle) * 32);
      final isWhite = i % 2 == 0;
      _pieces.add(CarromPiece(
        position: center + offset,
        radius: 11,
        color: isWhite ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
        points: isWhite ? 10 : 5,
      ));
    }

    _resetStriker();
  }

  void _resetStriker() {
    final y = _boardSize - 50.0;
    final x = 40.0 + _strikerX * (_boardSize - 80.0);
    _striker = CarromPiece(
      position: Offset(x, y),
      radius: 16,
      color: const Color(0xFF38BDF8),
      points: 0,
      isStriker: true,
    );
  }

  void _updatePhysics() {
    bool stillMoving = false;
    const friction = 0.965;
    final pockets = [
      const Offset(22, 22),
      Offset(_boardSize - 22, 22),
      Offset(22, _boardSize - 22),
      Offset(_boardSize - 22, _boardSize - 22),
    ];

    final all = [..._pieces, _striker];

    for (final p in all) {
      if (p.isPocketed) continue;

      if (p.velocity.distance > 0.15) {
        stillMoving = true;
        p.position += p.velocity;
        p.velocity *= friction;

        // Bounce against board walls
        if (p.position.dx - p.radius < 18) {
          p.position = Offset(18 + p.radius, p.position.dy);
          p.velocity = Offset(-p.velocity.dx * 0.75, p.velocity.dy);
        } else if (p.position.dx + p.radius > _boardSize - 18) {
          p.position = Offset(_boardSize - 18 - p.radius, p.position.dy);
          p.velocity = Offset(-p.velocity.dx * 0.75, p.velocity.dy);
        }

        if (p.position.dy - p.radius < 18) {
          p.position = Offset(p.position.dx, 18 + p.radius);
          p.velocity = Offset(p.velocity.dx, -p.velocity.dy * 0.75);
        } else if (p.position.dy + p.radius > _boardSize - 18) {
          p.position = Offset(p.position.dx, _boardSize - 18 - p.radius);
          p.velocity = Offset(p.velocity.dx, -p.velocity.dy * 0.75);
        }

        // Check pockets
        for (final pocket in pockets) {
          if ((p.position - pocket).distance < 24) {
            p.isPocketed = true;
            p.velocity = Offset.zero;
            if (!p.isStriker) {
              setState(() => _score += p.points);
            }
            break;
          }
        }
      } else {
        p.velocity = Offset.zero;
      }
    }

    // Check collisions between pieces
    for (int i = 0; i < all.length; i++) {
      for (int j = i + 1; j < all.length; j++) {
        final a = all[i];
        final b = all[j];
        if (a.isPocketed || b.isPocketed) continue;

        final delta = b.position - a.position;
        final dist = delta.distance;
        final minDist = a.radius + b.radius;

        if (dist < minDist && dist > 0) {
          final normal = delta / dist;
          final overlap = minDist - dist;
          a.position -= normal * (overlap / 2);
          b.position += normal * (overlap / 2);

          // Elastic collision momentum exchange
          final k = normal;
          final p = 2 * (a.velocity.dx * k.dx + a.velocity.dy * k.dy - b.velocity.dx * k.dx - b.velocity.dy * k.dy) / 2;
          a.velocity -= k * p * 0.85;
          b.velocity += k * p * 0.85;
          stillMoving = true;
        }
      }
    }

    setState(() {});

    if (!stillMoving && _isMoving) {
      _isMoving = false;
      _animController.stop();
      _resetStriker();

      // Check if match finished
      if (_shotsRemaining <= 0 || _pieces.every((p) => p.isPocketed)) {
        _onMatchComplete();
      }
    }
  }

  void _fireStriker(Offset impulse) {
    if (_isMoving || _shotsRemaining <= 0) return;

    setState(() {
      _shotsRemaining--;
      _isMoving = true;
      _striker.velocity = impulse;
    });

    _animController.repeat();
  }

  void _onMatchComplete() {
    final won = _score >= 25;
    final unlockedTitle = AuthService().recordMatchResult(
      gameId: 'carrom',
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
            Icon(won ? Icons.emoji_events_rounded : Icons.sports_score_rounded, color: AppColors.coinAmber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                won ? 'Match Won!' : 'Match Ended',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Final Score: $_score Points in 8 Shots!',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              won ? 'Outstanding striking skills! Target achieved.' : 'Good try! Score 25+ points to claim victory.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(Icons.bolt_rounded, won ? '+100 XP' : '+30 XP', AppColors.primaryBlueLight),
                  _statItem(Icons.monetization_on_rounded, won ? '+50 Coins' : '+15 Coins', AppColors.coinAmber),
                  _statItem(Icons.star_rounded, 'Score: $_score', AppColors.onlineGreen),
                ],
              ),
            ),
            if (unlockedTitle != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primaryPurple, AppColors.accentCyan]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_open_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🎉 NEW GAME UNLOCKED: $unlockedTitle!',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
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
            child: const Text('Exit to Arcade', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetBoard();
            },
            child: const Text('Play Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String text, Color color) {
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
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Carrom Clash Arena', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Reset Board',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetBoard,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _badge('Score', '$_score pts', AppColors.coinAmber),
                  _badge('Shots Left', '$_shotsRemaining', AppColors.primaryBlueLight),
                  _badge('Target', '25 pts', AppColors.onlineGreen),
                ],
              ),
            ),

            // Carrom Board
            Expanded(
              child: Center(
                child: GestureDetector(
                  onPanStart: (details) {
                    if (_isMoving) return;
                    _dragStart = details.localPosition;
                    _dragCurrent = details.localPosition;
                    setState(() {});
                  },
                  onPanUpdate: (details) {
                    if (_isMoving) return;
                    setState(() => _dragCurrent = details.localPosition);
                  },
                  onPanEnd: (details) {
                    if (_isMoving || _dragStart == null || _dragCurrent == null) return;
                    final delta = _dragStart! - _dragCurrent!;
                    final power = (delta.distance / 8).clamp(2.0, 18.0);
                    if (delta.distance > 10) {
                      final dir = delta / delta.distance;
                      _fireStriker(dir * power);
                    }
                    _dragStart = null;
                    _dragCurrent = null;
                    setState(() {});
                  },
                  child: Container(
                    width: _boardSize,
                    height: _boardSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A373), // Warm wood finish
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF582F0E), width: 14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 18,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      size: Size(_boardSize, _boardSize),
                      painter: _CarromPainter(
                        pieces: _pieces,
                        striker: _striker,
                        dragStart: _dragStart,
                        dragCurrent: _dragCurrent,
                        boardSize: _boardSize,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Striker Position Slider & Instructions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      const Text('Position Striker:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: _strikerX,
                          activeColor: AppColors.primaryBlueLight,
                          inactiveColor: AppColors.cardBg,
                          onChanged: _isMoving
                              ? null
                              : (val) {
                                  setState(() {
                                    _strikerX = val;
                                    _resetStriker();
                                  });
                                },
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Drag back on the board to aim and set power, then release to strike!',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }
}

class _CarromPainter extends CustomPainter {
  final List<CarromPiece> pieces;
  final CarromPiece striker;
  final Offset? dragStart;
  final Offset? dragCurrent;
  final double boardSize;

  _CarromPainter({
    required this.pieces,
    required this.striker,
    this.dragStart,
    this.dragCurrent,
    required this.boardSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pocketPaint = Paint()..color = const Color(0xFF1E293B);
    const pocketRadius = 18.0;

    // 4 Corner Pockets
    canvas.drawCircle(const Offset(14, 14), pocketRadius, pocketPaint);
    canvas.drawCircle(Offset(size.width - 14, 14), pocketRadius, pocketPaint);
    canvas.drawCircle(Offset(14, size.height - 14), pocketRadius, pocketPaint);
    canvas.drawCircle(Offset(size.width - 14, size.height - 14), pocketRadius, pocketPaint);

    // Board line markings
    final linePaint = Paint()
      ..color = const Color(0xFF6B4226)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Center circle
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 40, linePaint);
    canvas.drawCircle(center, 14, linePaint);

    // Baseline marking
    canvas.drawLine(
      Offset(40, size.height - 50),
      Offset(size.width - 40, size.height - 50),
      linePaint,
    );

    // Draw Pieces
    for (final p in pieces) {
      if (p.isPocketed) continue;
      final paint = Paint()..color = p.color;
      canvas.drawCircle(p.position, p.radius, paint);
      // Border ring
      canvas.drawCircle(
        p.position,
        p.radius,
        Paint()
          ..color = Colors.black38
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // Draw Striker
    if (!striker.isPocketed) {
      final sPaint = Paint()..color = striker.color;
      canvas.drawCircle(striker.position, striker.radius, sPaint);
      canvas.drawCircle(
        striker.position,
        striker.radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Draw Aiming Guide Line
    if (dragStart != null && dragCurrent != null) {
      final delta = dragStart! - dragCurrent!;
      if (delta.distance > 8) {
        final aimDir = delta / delta.distance;
        final aimTarget = striker.position + aimDir * (delta.distance * 1.5).clamp(20, 140);

        final guidePaint = Paint()
          ..color = AppColors.accentCyan
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;

        canvas.drawLine(striker.position, aimTarget, guidePaint);
        canvas.drawCircle(aimTarget, 4, Paint()..color = AppColors.accentCyan);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CarromPainter oldDelegate) => true;
}
