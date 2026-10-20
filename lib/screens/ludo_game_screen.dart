import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LudoToken {
  final int id;
  final String player; // 'Red' or 'Green'
  int step; // -1 = Yard, 0..27 = Track, 28..31 = Home Path, 32 = Home!
  LudoToken({required this.id, required this.player, this.step = -1});

  bool get inYard => step == -1;
  bool get isHome => step >= 32;
}

class LudoGameScreen extends StatefulWidget {
  const LudoGameScreen({super.key});

  @override
  State<LudoGameScreen> createState() => _LudoGameScreenState();
}

class _LudoGameScreenState extends State<LudoGameScreen> with SingleTickerProviderStateMixin {
  late List<LudoToken> _tokens;
  String _currentTurn = 'Red'; // 'Red' (You) or 'Green' (Opponent / AI)
  int _diceValue = 1;
  bool _isRolling = false;
  bool _hasRolled = false;
  bool _vsAi = true;
  String? _winner;
  late AnimationController _diceAnimController;

  @override
  void initState() {
    super.initState();
    _diceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _resetGame();
  }

  @override
  void dispose() {
    _diceAnimController.dispose();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _tokens = [
        LudoToken(id: 1, player: 'Red', step: -1),
        LudoToken(id: 2, player: 'Red', step: -1),
        LudoToken(id: 3, player: 'Green', step: -1),
        LudoToken(id: 4, player: 'Green', step: -1),
      ];
      _currentTurn = 'Red';
      _diceValue = 6;
      _isRolling = false;
      _hasRolled = false;
      _winner = null;
    });
  }

  Future<void> _rollDice() async {
    if (_isRolling || _hasRolled || _winner != null) return;

    setState(() => _isRolling = true);
    _diceAnimController.forward(from: 0.0);

    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      setState(() => _diceValue = 1 + Random().nextInt(6));
    }

    setState(() {
      _isRolling = false;
      _hasRolled = true;
    });

    // Check if player has any valid moves
    final movable = _getMovableTokens(_currentTurn, _diceValue);
    if (movable.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _switchTurn();
    } else if (movable.length == 1 && (_currentTurn == 'Green' || _tokens.where((t) => t.player == _currentTurn && !t.inYard && !t.isHome).isEmpty)) {
      // Auto move single option
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _moveToken(movable.first);
    }
  }

  List<LudoToken> _getMovableTokens(String player, int dice) {
    final list = _tokens.where((t) => t.player == player && !t.isHome).toList();
    final valid = <LudoToken>[];
    for (final t in list) {
      if (t.inYard) {
        if (dice == 6) valid.add(t);
      } else if (t.step + dice <= 32) {
        valid.add(t);
      }
    }
    return valid;
  }

  void _moveToken(LudoToken token) {
    if (!_hasRolled || token.player != _currentTurn || _winner != null) return;

    setState(() {
      if (token.inYard) {
        if (_diceValue == 6) {
          token.step = 0;
        }
      } else {
        token.step += _diceValue;
      }

      // Check captures
      if (token.step > 0 && token.step < 28) {
        final opponent = _tokens.firstWhere(
          (t) => t.player != token.player && t.step == token.step && !t.isHome,
          orElse: () => LudoToken(id: -1, player: ''),
        );
        if (opponent.id != -1) {
          opponent.step = -1; // Sent back to yard!
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('💥 ${token.player} captured ${opponent.player} token!'),
              duration: const Duration(seconds: 1),
              backgroundColor: AppColors.primaryPurple,
            ),
          );
        }
      }

      // Check win condition (all 2 tokens home)
      final homeTokens = _tokens.where((t) => t.player == token.player && t.isHome).length;
      if (homeTokens >= 2) {
        _winner = token.player;
        _onGameWon(token.player == 'Red');
        return;
      }

      _switchTurn();
    });
  }

  void _switchTurn() {
    _hasRolled = false;
    _currentTurn = _currentTurn == 'Red' ? 'Green' : 'Red';

    if (_currentTurn == 'Green' && _vsAi && _winner == null) {
      Timer(const Duration(milliseconds: 800), () {
        if (mounted && _currentTurn == 'Green') {
          _aiTurn();
        }
      });
    }
  }

  Future<void> _aiTurn() async {
    if (_winner != null) return;
    await _rollDice();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _winner != null) return;

    final movable = _getMovableTokens('Green', _diceValue);
    if (movable.isNotEmpty) {
      // Pick best token: favor home move, then capture, then entry, then advance
      movable.sort((a, b) => b.step.compareTo(a.step));
      _moveToken(movable.first);
    }
  }

  void _onGameWon(bool isPlayerWinner) {
    final unlockedTitle = AuthService().recordMatchResult(
      gameId: 'ludo',
      won: isPlayerWinner,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isPlayerWinner ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
              color: isPlayerWinner ? AppColors.coinAmber : AppColors.textSecondary,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isPlayerWinner ? 'Victory! You Won!' : 'Match Finished',
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
              isPlayerWinner
                  ? 'Congratulations! You beat the opponent in Ludo Friends.'
                  : 'Green Player won this match. Better luck next game!',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _rewardBadge(Icons.bolt_rounded, isPlayerWinner ? '+100 XP' : '+30 XP', AppColors.primaryBlueLight),
                  _rewardBadge(Icons.monetization_on_rounded, isPlayerWinner ? '+50 Coins' : '+15 Coins', AppColors.coinAmber),
                  _rewardBadge(Icons.military_tech_rounded, isPlayerWinner ? '+1 Win' : '0 Win', AppColors.onlineGreen),
                ],
              ),
            ),
            if (unlockedTitle != null) ...[
              const SizedBox(height: 14),
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
              _resetGame();
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
    final isMyTurn = _currentTurn == 'Red';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Ludo Friends Duel', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: _vsAi ? 'Mode: vs Smart AI' : 'Mode: Pass & Play',
            icon: Icon(_vsAi ? Icons.smart_toy_rounded : Icons.people_rounded, color: AppColors.accentCyan),
            onPressed: () {
              setState(() {
                _vsAi = !_vsAi;
                _resetGame();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_vsAi ? 'Switched to Single Player vs AI Bot' : 'Switched to 2-Player Pass & Play'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Restart Game',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetGame,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Turn Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMyTurn ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isMyTurn ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isMyTurn ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isMyTurn ? "Red's Turn (You)" : "Green's Turn (${_vsAi ? 'AI Bot' : 'Player 2'})",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  Text(
                    _hasRolled ? 'Tap token to move' : 'Roll the dice',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Ludo Board Arena
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Red Yard (Bottom-Left)
                        Positioned(
                          left: 12,
                          bottom: 12,
                          width: 130,
                          height: 130,
                          child: _buildYard('Red', const Color(0xFFEF4444)),
                        ),

                        // Green Yard (Top-Right)
                        Positioned(
                          right: 12,
                          top: 12,
                          width: 130,
                          height: 130,
                          child: _buildYard('Green', const Color(0xFF10B981)),
                        ),

                        // Center Home Goal Triangle
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF1E293B)],
                              ),
                              border: Border.all(color: Colors.amber, width: 2),
                            ),
                            child: const Center(
                              child: Icon(Icons.star_rounded, color: Colors.amber, size: 36),
                            ),
                          ),
                        ),

                        // Active Tokens on Board Track
                        ..._buildTrackTokens(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Dice & Control Action Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tokens at Home summary
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _homeScoreBadge('Red (You)', const Color(0xFFEF4444)),
                      const SizedBox(height: 6),
                      _homeScoreBadge('Green', const Color(0xFF10B981)),
                    ],
                  ),

                  // Interactive 3D Dice
                  GestureDetector(
                    onTap: (!_hasRolled && !_isRolling && (isMyTurn || !_vsAi)) ? _rollDice : null,
                    child: AnimatedBuilder(
                      animation: _diceAnimController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _isRolling ? _diceAnimController.value * 2 * pi : 0,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isMyTurn
                                    ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                                    : [const Color(0xFF10B981), const Color(0xFF047857)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: (isMyTurn ? Colors.red : Colors.green).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isRolling
                                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                                  : Text(
                                      '$_diceValue',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Roll Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMyTurn ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: (!_hasRolled && !_isRolling && (isMyTurn || !_vsAi)) ? _rollDice : null,
                    child: Text(
                      _isRolling ? 'Rolling...' : (_hasRolled ? 'Move' : 'Roll'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _homeScoreBadge(String label, Color color) {
    final count = _tokens.where((t) => t.player.startsWith(label[0]) && t.isHome).length;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        Text('$count/2 Home', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildYard(String player, Color color) {
    final yardTokens = _tokens.where((t) => t.player == player && t.inYard).toList();
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: yardTokens.map((token) {
            return GestureDetector(
              onTap: () => _moveToken(token),
              child: _buildTokenWidget(token, color, inYard: true),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Widget> _buildTrackTokens() {
    final trackTokens = _tokens.where((t) => !t.inYard && !t.isHome).toList();
    return trackTokens.map((token) {
      // Calculate circular track position
      const totalSteps = 32;
      final angle = (token.step / totalSteps) * 2 * pi;
      const radius = 105.0;

      return Align(
        alignment: Alignment(
          (cos(angle) * radius) / 140,
          (sin(angle) * radius) / 140,
        ),
        child: GestureDetector(
          onTap: () => _moveToken(token),
          child: _buildTokenWidget(
            token,
            token.player == 'Red' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTokenWidget(LudoToken token, Color color, {bool inYard = false}) {
    final isSelectable = _hasRolled && token.player == _currentTurn && (_diceValue == 6 || !inYard);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: inYard ? 38 : 34,
      height: inYard ? 38 : 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: isSelectable ? Colors.white : Colors.black45,
          width: isSelectable ? 2.5 : 1.5,
        ),
        boxShadow: [
          if (isSelectable)
            BoxShadow(
              color: color.withValues(alpha: 0.8),
              blurRadius: 10,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Center(
        child: Text(
          inYard ? 'Yard' : '${token.step}',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
