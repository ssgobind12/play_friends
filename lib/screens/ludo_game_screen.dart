import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/game_sound_service.dart';
import '../theme/app_theme.dart';

/// Ludo AI difficulty level
enum LudoDifficulty { easy, medium, hard }

/// Represents a single Ludo token
class LudoToken {
  final int id;
  final String player; // 'Red', 'Green', 'Yellow', 'Blue'
  final int pocketIndex; // 0, 1, 2, 3 in Yard
  int step; // -1 = Yard, 0..50 = Track, 51..55 = Home Path, 56 = Home Goal!

  LudoToken({
    required this.id,
    required this.player,
    required this.pocketIndex,
    this.step = -1,
  });

  bool get inYard => step == -1;
  bool get isHome => step >= 56;
  bool get inHomeLane => step >= 51 && step < 56;
}

class LudoGameScreen extends StatefulWidget {
  const LudoGameScreen({super.key});

  @override
  State<LudoGameScreen> createState() => _LudoGameScreenState();
}

class _LudoGameScreenState extends State<LudoGameScreen>
    with TickerProviderStateMixin {
  // Game Setup
  int _playerCount = 2; // 2 or 4 players
  bool _vsAi = true; // Play vs Computer Bot
  int _tokensPerPlayer = 4; // 2 or 4 tokens per player
  LudoDifficulty _difficulty = LudoDifficulty.medium;

  // Active Players in Turn Order
  List<String> get _activePlayers =>
      _playerCount == 2 ? ['Red', 'Yellow'] : ['Red', 'Green', 'Yellow', 'Blue'];

  int _currentTurnIndex = 0;
  String get _currentTurn => _activePlayers[_currentTurnIndex];

  // Game state
  late List<LudoToken> _tokens;
  int _diceValue = 6;
  bool _isRolling = false;
  bool _hasRolled = false;
  String? _statusBanner;
  String? _winner;
  int _consecutiveSixes = 0;

  // Animations
  late AnimationController _diceAnimController;
  late AnimationController _tokenPulseController;

  @override
  void initState() {
    super.initState();
    _diceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _tokenPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _resetGame();
  }

  @override
  void dispose() {
    _diceAnimController.dispose();
    _tokenPulseController.dispose();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _tokens = [];
      for (final player in ['Red', 'Green', 'Yellow', 'Blue']) {
        for (int i = 0; i < _tokensPerPlayer; i++) {
          _tokens.add(
            LudoToken(
              id: _tokens.length,
              player: player,
              pocketIndex: i,
              step: -1,
            ),
          );
        }
      }
      _currentTurnIndex = 0;
      _diceValue = 6;
      _isRolling = false;
      _hasRolled = false;
      _consecutiveSixes = 0;
      _winner = null;
      _statusBanner = "Roll the dice to start!";
    });
  }

  // --------------------------------------------------------------------------
  // DICE ROLLING & TURN CONTROL
  // --------------------------------------------------------------------------

  Future<void> _rollDice() async {
    if (_isRolling || _hasRolled || _winner != null) return;

    setState(() {
      _isRolling = true;
      _statusBanner = null;
    });

    _diceAnimController.forward(from: 0.0);
    GameSoundService.ludoDiceRoll();

    final rng = Random();
    for (int i = 0; i < 7; i++) {
      await Future.delayed(const Duration(milliseconds: 55));
      if (!mounted) return;
      setState(() => _diceValue = 1 + rng.nextInt(6));
    }

    setState(() {
      _isRolling = false;
      _hasRolled = true;
    });

    // Handle 3 consecutive 6s rule
    if (_diceValue == 6) {
      _consecutiveSixes++;
      if (_consecutiveSixes >= 3) {
        setState(() {
          _statusBanner = "Three 6s in a row! Turn forfeited.";
          _consecutiveSixes = 0;
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) _switchTurn();
        return;
      }
    } else {
      _consecutiveSixes = 0;
    }

    // Check movable tokens
    final movable = _getMovableTokens(_currentTurn, _diceValue);

    if (movable.isEmpty) {
      // Like Ludo King, cleanly switch turn without showing "No moves available" banner
      await Future.delayed(const Duration(milliseconds: 550));
      if (mounted) _switchTurn();
    } else if (movable.length == 1) {
      // Auto move single option
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _moveToken(movable.first);
    } else {
      setState(() {
        _statusBanner = "Tap a pulsing token to move";
      });
      // If AI turn, pick smartly
      if (_isCurrentPlayerAi()) {
        await Future.delayed(const Duration(milliseconds: 550));
        if (mounted) _aiChooseMove(movable);
      }
    }
  }

  bool _isCurrentPlayerAi() {
    if (!_vsAi) return false;
    // Human is always Red
    return _currentTurn != 'Red';
  }

  List<LudoToken> _getMovableTokens(String player, int dice) {
    final list = _tokens.where((t) => t.player == player && !t.isHome).toList();
    final valid = <LudoToken>[];

    for (final t in list) {
      if (t.inYard) {
        if (dice == 6) valid.add(t);
      } else {
        final newStep = t.step + dice;
        if (newStep <= 56) {
          // FIX: Allow stacking own tokens on a safe spot — never blocked.
          // Only block if destination (non-safe perimeter) has 2+ own tokens already (stacking limit).
          if (newStep < 51) {
            final targetGlobal = _getGlobalPerimeterIndex(player, newStep);
            final ownOnTarget = _tokens.where(
              (o) => o.player == player && !o.inYard && !o.isHome && !o.inHomeLane && _getGlobalPerimeterIndex(o.player, o.step) == targetGlobal,
            ).length;
            // Allow stacking on safe spots freely; elsewhere limit to 2 own tokens per cell
            if (_isSafeSpot(targetGlobal) || ownOnTarget < 2) {
              valid.add(t);
            }
          } else {
            valid.add(t); // home lane or home goal — always allowed
          }
        }
      }
    }
    return valid;
  }

  void _aiChooseMove(List<LudoToken> movable) {
    if (_winner != null || !mounted) return;

    final rng = Random();

    // EASY: Just pick random movable token
    if (_difficulty == LudoDifficulty.easy) {
      final shuffled = List<LudoToken>.from(movable)..shuffle(rng);
      _moveToken(shuffled.first);
      return;
    }

    // MEDIUM: 50% chance to play smart, 50% random
    if (_difficulty == LudoDifficulty.medium && rng.nextDouble() < 0.5) {
      final shuffled = List<LudoToken>.from(movable)..shuffle(rng);
      _moveToken(shuffled.first);
      return;
    }

    // HARD (or medium smart branch): Full priority AI
    // 1. Move token into Home Goal (step == 56)
    // 2. Capture an opponent token
    // 3. Bring out token from yard on 6
    // 4. Advance closest token to home
    LudoToken? best;

    for (final t in movable) {
      if (t.step + _diceValue == 56) {
        best = t;
        break;
      }
    }

    if (best == null) {
      for (final t in movable) {
        if (!t.inYard && t.step + _diceValue < 51) {
          final targetIndex = _getGlobalPerimeterIndex(t.player, t.step + _diceValue);
          if (!_isSafeSpot(targetIndex)) {
            final hasOpponent = _tokens.any(
              (o) =>
                  o.player != t.player &&
                  !o.inYard &&
                  !o.isHome &&
                  !o.inHomeLane &&
                  _getGlobalPerimeterIndex(o.player, o.step) == targetIndex,
            );
            if (hasOpponent) {
              best = t;
              break;
            }
          }
        }
      }
    }

    if (best == null && _diceValue == 6) {
      final yardToken = movable.firstWhere((t) => t.inYard, orElse: () => movable.first);
      if (yardToken.inYard) best = yardToken;
    }

    best ??= movable.reduce((a, b) => a.step > b.step ? a : b);
    _moveToken(best);
  }

  void _moveToken(LudoToken token) {
    if (!_hasRolled || token.player != _currentTurn || _winner != null) return;

    bool earnedBonusRoll = false;
    String bonusReason = "";

    setState(() {
      if (token.inYard) {
        if (_diceValue == 6) {
          token.step = 0; // Exit yard to start tile!
          GameSoundService.ludoTokenMove();
          earnedBonusRoll = true;
          bonusReason = "🎲 Rolled 6! Extra roll!";
        }
      } else {
        token.step += _diceValue;
        GameSoundService.ludoTokenMove();

        if (token.step == 56) {
          GameSoundService.ludoTokenHome();
          earnedBonusRoll = true;
          bonusReason = "🏆 Reached Home! Extra roll!";
        } else if (token.step < 51) {
          // Check for captures on perimeter
          final globalPos = _getGlobalPerimeterIndex(token.player, token.step);

          if (!_isSafeSpot(globalPos)) {
            final captured = _tokens.where(
              (o) =>
                  o.player != token.player &&
                  !o.inYard &&
                  !o.isHome &&
                  !o.inHomeLane &&
                  _getGlobalPerimeterIndex(o.player, o.step) == globalPos,
            ).toList();

            if (captured.isNotEmpty) {
              for (final victim in captured) {
                victim.step = -1; // Send back to yard!
              }
              GameSoundService.ludoTokenCaptured();
              earnedBonusRoll = true;
              bonusReason = "💥 CUT opponent token! Extra roll!";
            }
          }
        }
      }

      // Check win condition
      final homeCount = _tokens.where((t) => t.player == token.player && t.isHome).length;
      if (homeCount >= _tokensPerPlayer) {
        _winner = token.player;
        _onGameWon(token.player == 'Red');
        return;
      }

      // Bonus roll if rolled 6
      if (_diceValue == 6 && !earnedBonusRoll) {
        earnedBonusRoll = true;
        bonusReason = "🎲 Rolled 6! Extra roll!";
      }

      if (earnedBonusRoll) {
        _hasRolled = false;
        _statusBanner = bonusReason;

        // If AI, trigger bonus roll
        if (_isCurrentPlayerAi()) {
          Timer(const Duration(milliseconds: 700), () {
            if (mounted && _isCurrentPlayerAi() && _winner == null) {
              _rollDice();
            }
          });
        }
      } else {
        _switchTurn();
      }
    });
  }

  void _switchTurn() {
    _hasRolled = false;
    _consecutiveSixes = 0;
    _currentTurnIndex = (_currentTurnIndex + 1) % _activePlayers.length;

    final nextPlayer = _currentTurn;
    _statusBanner = nextPlayer == 'Red'
        ? "Your turn! Roll the dice."
        : "$nextPlayer's turn (${_isCurrentPlayerAi() ? 'Computer' : 'Player 2'})";

    if (_isCurrentPlayerAi() && _winner == null) {
      Timer(const Duration(milliseconds: 700), () {
        if (mounted && _isCurrentPlayerAi() && _winner == null) {
          _rollDice();
        }
      });
    }
  }

  // --------------------------------------------------------------------------
  // LUDO 15x15 BOARD COORDINATE ENGINE
  // --------------------------------------------------------------------------

  static const List<Point<int>> _perimeter = [
    // Red Start & Left Arm Top Row (0..4)
    Point(6, 1), // 0: Red Start (SAFE)
    Point(6, 2), // 1
    Point(6, 3), // 2
    Point(6, 4), // 3
    Point(6, 5), // 4
    // Top Arm Left Col (5..10)
    Point(5, 6), // 5
    Point(4, 6), // 6
    Point(3, 6), // 7
    Point(2, 6), // 8: Green Safe Star (SAFE)
    Point(1, 6), // 9
    Point(0, 6), // 10
    // Top Arm Top Cross (11)
    Point(0, 7), // 11
    // Top Arm Right Col (12..17)
    Point(0, 8), // 12
    Point(1, 8), // 13: Green Start (SAFE)
    Point(2, 8), // 14
    Point(3, 8), // 15
    Point(4, 8), // 16
    Point(5, 8), // 17
    // Right Arm Top Row (18..23)
    Point(6, 9),  // 18
    Point(6, 10), // 19
    Point(6, 11), // 20
    Point(6, 12), // 21: Yellow Safe Star (SAFE)
    Point(6, 13), // 22
    Point(6, 14), // 23
    // Right Arm Right Cross (24..25)
    Point(7, 14), // 24
    Point(8, 14), // 25
    // Right Arm Bottom Row (26..30)
    Point(8, 13), // 26: Yellow Start (SAFE)
    Point(8, 12), // 27
    Point(8, 11), // 28
    Point(8, 10), // 29
    Point(8, 9),  // 30
    // Bottom Arm Right Col (31..36)
    Point(9, 8),  // 31
    Point(10, 8), // 32
    Point(11, 8), // 33
    Point(12, 8), // 34: Blue Safe Star (SAFE)
    Point(13, 8), // 35
    Point(14, 8), // 36
    // Bottom Arm Bottom Cross (37)
    Point(14, 7), // 37
    // Bottom Arm Left Col (38..43)
    Point(14, 6), // 38
    Point(13, 6), // 39: Blue Start (SAFE)
    Point(12, 6), // 40
    Point(11, 6), // 41
    Point(10, 6), // 42
    Point(9, 6),  // 43
    // Left Arm Bottom Row (44..49)
    Point(8, 5), // 44
    Point(8, 4), // 45
    Point(8, 3), // 46
    Point(8, 2), // 47: Red Safe Star (SAFE)
    Point(8, 1), // 48
    Point(8, 0), // 49
    // Left Arm Left Cross (50..51)
    Point(7, 0), // 50
    Point(6, 0), // 51
  ];

  static int _getPlayerStartOffset(String player) {
    switch (player) {
      case 'Red':
        return 0;
      case 'Green':
        return 13;
      case 'Yellow':
        return 26;
      case 'Blue':
        return 39;
      default:
        return 0;
    }
  }

  static int _getGlobalPerimeterIndex(String player, int step) {
    final start = _getPlayerStartOffset(player);
    return (start + step) % 52;
  }

  static bool _isSafeSpot(int perimeterIndex) {
    const safeSpots = [0, 8, 13, 21, 26, 34, 39, 47];
    return safeSpots.contains(perimeterIndex);
  }

  Point<double> _getTokenCoordinates(LudoToken token) {
    if (token.inYard) {
      // 4 pocket locations inside each 6x6 yard
      final offsets = [
        const Point(1.6, 1.6),
        const Point(1.6, 3.8),
        const Point(3.8, 1.6),
        const Point(3.8, 3.8),
      ];
      final off = offsets[token.pocketIndex % 4];

      switch (token.player) {
        case 'Red':
          return Point(off.x, off.y);
        case 'Green':
          return Point(off.x, 9.0 + off.y);
        case 'Yellow':
          return Point(9.0 + off.x, 9.0 + off.y);
        case 'Blue':
          return Point(9.0 + off.x, off.y);
        default:
          return const Point(2.0, 2.0);
      }
    }

    if (token.isHome) {
      // Center goal
      switch (token.player) {
        case 'Red':
          return const Point(7.0, 6.4);
        case 'Green':
          return const Point(6.4, 7.0);
        case 'Yellow':
          return const Point(7.0, 7.6);
        case 'Blue':
          return const Point(7.6, 7.0);
        default:
          return const Point(7.0, 7.0);
      }
    }

    if (token.inHomeLane) {
      final homeStep = token.step - 50; // 1..5
      switch (token.player) {
        case 'Red':
          return Point(7.0, 0.0 + homeStep);
        case 'Green':
          return Point(0.0 + homeStep, 7.0);
        case 'Yellow':
          return Point(7.0, 14.0 - homeStep);
        case 'Blue':
          return Point(14.0 - homeStep, 7.0);
        default:
          return const Point(7.0, 7.0);
      }
    }

    // On perimeter track
    final globalIndex = _getGlobalPerimeterIndex(token.player, token.step);
    final p = _perimeter[globalIndex];
    return Point(p.x.toDouble(), p.y.toDouble());
  }

  Color _getPlayerColor(String player) {
    switch (player) {
      case 'Red':
        return const Color(0xFFE53935);
      case 'Green':
        return const Color(0xFF43A047);
      case 'Yellow':
        return const Color(0xFFFBC02D);
      case 'Blue':
        return const Color(0xFF1E88E5);
      default:
        return Colors.white;
    }
  }

  void _onGameWon(bool isPlayerWinner) {
    GameSoundService.ludoWin();
    final unlockedTitle = AuthService().recordMatchResult(
      gameId: 'ludo',
      won: isPlayerWinner,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              isPlayerWinner ? Icons.emoji_events_rounded : Icons.military_tech_rounded,
              color: isPlayerWinner ? AppColors.coinAmber : AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isPlayerWinner ? 'VICTORY! You Won!' : 'Match Completed',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                  ? 'Congratulations! You brought all your tokens home in Ludo Friends!'
                  : '$_winner player finished first. Better luck next match!',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _rewardBadge(Icons.bolt_rounded, isPlayerWinner ? '+120 XP' : '+30 XP', AppColors.primaryBlueLight),
                  _rewardBadge(Icons.monetization_on_rounded, isPlayerWinner ? '+60 Coins' : '+15 Coins', AppColors.coinAmber),
                  _rewardBadge(Icons.emoji_events_rounded, isPlayerWinner ? '+1 Win' : '0 Win', AppColors.onlineGreen),
                ],
              ),
            ),
            if (unlockedTitle != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primaryPurple, AppColors.primaryBlue]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_open_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🎉 NEW GAME UNLOCKED: $unlockedTitle!',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
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
            child: const Text('Exit to Arcade'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  Widget _rewardBadge(IconData icon, String text, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // UI WIDGETS
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final movableTokens = _hasRolled ? _getMovableTokens(_currentTurn, _diceValue) : <LudoToken>[];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        title: const Text('Ludo King Duel', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF131A2E),
        actions: [
          // Player count toggle (2 or 4 players)
          PopupMenuButton<int>(
            tooltip: 'Players & Tokens',
            icon: const Icon(Icons.tune_rounded, color: AppColors.primaryBlueLight),
            onSelected: (val) {
              setState(() {
                if (val == 2 || val == 4) {
                  _playerCount = val;
                } else if (val == 20) {
                  _tokensPerPlayer = 2; // 2 Tokens Quick Match
                } else if (val == 40) {
                  _tokensPerPlayer = 4; // 4 Tokens Classic Match
                } else if (val == 10) {
                  _difficulty = LudoDifficulty.easy;
                } else if (val == 11) {
                  _difficulty = LudoDifficulty.medium;
                } else if (val == 12) {
                  _difficulty = LudoDifficulty.hard;
                }
                _resetGame();
              });
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 2,
                child: Row(
                  children: [
                    Icon(_playerCount == 2 ? Icons.check_circle_rounded : Icons.circle_outlined, size: 18),
                    const SizedBox(width: 8),
                    const Text('2 Players Duel (Red vs Yellow)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 4,
                child: Row(
                  children: [
                    Icon(_playerCount == 4 ? Icons.check_circle_rounded : Icons.circle_outlined, size: 18),
                    const SizedBox(width: 8),
                    const Text('4 Players Match (All Colors)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 20,
                child: Row(
                  children: [
                    Icon(_tokensPerPlayer == 2 ? Icons.check_circle_rounded : Icons.circle_outlined, size: 18),
                    const SizedBox(width: 8),
                    const Text('Quick Mode (2 Tokens)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 40,
                child: Row(
                  children: [
                    Icon(_tokensPerPlayer == 4 ? Icons.check_circle_rounded : Icons.circle_outlined, size: 18),
                    const SizedBox(width: 8),
                    const Text('Classic Mode (4 Tokens)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 10,
                child: Row(
                  children: [
                    Icon(_difficulty == LudoDifficulty.easy ? Icons.check_circle_rounded : Icons.circle_outlined, size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('🟢 Easy AI'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 11,
                child: Row(
                  children: [
                    Icon(_difficulty == LudoDifficulty.medium ? Icons.check_circle_rounded : Icons.circle_outlined, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text('🟡 Medium AI'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 12,
                child: Row(
                  children: [
                    Icon(_difficulty == LudoDifficulty.hard ? Icons.check_circle_rounded : Icons.circle_outlined, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text('🔴 Hard AI'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: _vsAi ? 'Single Player vs AI' : '2-Player Pass & Play',
            icon: Icon(_vsAi ? Icons.smart_toy_rounded : Icons.people_rounded, color: AppColors.primaryPurpleLight),
            onPressed: () {
              setState(() {
                _vsAi = !_vsAi;
                _resetGame();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_vsAi ? 'Switched to Single Player vs AI Bot' : 'Switched to Pass & Play with Friends'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: AppColors.surfaceLight,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Restart',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetGame,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Player cards & Active Turn
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildPlayerCard(
                      'Red',
                      'You',
                      Icons.person_rounded,
                      isLeft: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPlayerCard(
                      _playerCount == 2 ? 'Yellow' : 'Green',
                      _vsAi ? 'Computer' : 'Player 2',
                      _vsAi ? Icons.smart_toy_rounded : Icons.people_rounded,
                      isLeft: false,
                    ),
                  ),
                ],
              ),
            ),

            // Status notice
            if (_statusBanner != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _getPlayerColor(_currentTurn).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getPlayerColor(_currentTurn).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _getPlayerColor(_currentTurn)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _statusBanner!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getPlayerColor(_currentTurn),
                      ),
                    ),
                  ],
                ),
              ),

            // 15x15 Ludo King Board
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD4AF37), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 16,
                            spreadRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final boardSize = constraints.maxWidth;
                            final cellSize = boardSize / 15.0;

                            return Stack(
                              children: [
                                // Custom Painter for Ludo King Board Grid, Yards, Safe Stars, Triangles
                                CustomPaint(
                                  size: Size(boardSize, boardSize),
                                  painter: LudoBoardPainter(),
                                ),

                                // Tokens rendered dynamically
                                ..._tokens.map((token) {
                                  // Hide unused colors in 2 player mode
                                  if (_playerCount == 2 &&
                                      token.player != 'Red' &&
                                      token.player != 'Yellow') {
                                    return const SizedBox.shrink();
                                  }

                                  final coords = _getTokenCoordinates(token);
                                  final isMovable = movableTokens.contains(token);

                                  // Calculate multi-token stacking offset on safe/stop points
                                  final visibleTokens = _tokens.where((t) {
                                    if (_playerCount == 2 && t.player != 'Red' && t.player != 'Yellow') {
                                      return false;
                                    }
                                    return true;
                                  }).toList();

                                  final sameCellTokens = visibleTokens.where((t) {
                                    if (token.inYard) return t.id == token.id;
                                    if (t.inYard) return false;
                                    if (token.isHome) return t.isHome && t.player == token.player;
                                    if (t.isHome) return false;
                                    if (token.inHomeLane) {
                                      return t.inHomeLane && t.player == token.player && t.step == token.step;
                                    }
                                    if (t.inHomeLane) return false;
                                    return _getGlobalPerimeterIndex(t.player, t.step) ==
                                        _getGlobalPerimeterIndex(token.player, token.step);
                                  }).toList();

                                  final stackCount = sameCellTokens.length;
                                  final stackIndex = sameCellTokens.indexOf(token);

                                  final double tokenSize = stackCount > 1
                                      ? (stackCount == 2 ? cellSize * 0.62 : cellSize * 0.50)
                                      : cellSize * 0.85;

                                  final cellCenterX = (coords.y * cellSize) + (cellSize / 2);
                                  final cellCenterY = (coords.x * cellSize) + (cellSize / 2);

                                  double offX = 0;
                                  double offY = 0;
                                  if (stackCount == 2) {
                                    offX = stackIndex == 0 ? -cellSize * 0.17 : cellSize * 0.17;
                                    offY = stackIndex == 0 ? -cellSize * 0.17 : cellSize * 0.17;
                                  } else if (stackCount == 3) {
                                    if (stackIndex == 0) {
                                      offX = -cellSize * 0.18;
                                      offY = -cellSize * 0.16;
                                    } else if (stackIndex == 1) {
                                      offX = cellSize * 0.18;
                                      offY = -cellSize * 0.16;
                                    } else {
                                      offX = 0;
                                      offY = cellSize * 0.18;
                                    }
                                  } else if (stackCount >= 4) {
                                    if (stackIndex == 0) {
                                      offX = -cellSize * 0.18;
                                      offY = -cellSize * 0.18;
                                    } else if (stackIndex == 1) {
                                      offX = cellSize * 0.18;
                                      offY = -cellSize * 0.18;
                                    } else if (stackIndex == 2) {
                                      offX = -cellSize * 0.18;
                                      offY = cellSize * 0.18;
                                    } else {
                                      offX = cellSize * 0.18;
                                      offY = cellSize * 0.18;
                                    }
                                  }

                                  return Positioned(
                                    left: cellCenterX + offX - (tokenSize / 2),
                                    top: cellCenterY + offY - (tokenSize / 2),
                                    width: tokenSize,
                                    height: tokenSize,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: isMovable ? () => _moveToken(token) : null,
                                      child: Center(
                                        child: AnimatedBuilder(
                                          animation: _tokenPulseController,
                                          builder: (context, child) {
                                            final scale = isMovable
                                                ? 1.0 + (_tokenPulseController.value * 0.22)
                                                : 1.0;

                                            return Transform.scale(
                                              scale: scale,
                                              child: Container(
                                                width: tokenSize,
                                                height: tokenSize,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: RadialGradient(
                                                    colors: [
                                                      _getPlayerColor(token.player).withValues(alpha: 0.9),
                                                      _getPlayerColor(token.player),
                                                      const Color(0xFF1E293B),
                                                    ],
                                                    stops: const [0.3, 0.7, 1.0],
                                                  ),
                                                  border: Border.all(
                                                    color: isMovable
                                                        ? Colors.white
                                                        : const Color(0xFFD4AF37),
                                                    width: isMovable ? 2.5 : 1.5,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: isMovable
                                                          ? _getPlayerColor(token.player).withValues(alpha: 0.8)
                                                          : Colors.black.withValues(alpha: 0.4),
                                                      blurRadius: isMovable ? 8 : 4,
                                                      spreadRadius: isMovable ? 2 : 0,
                                                    ),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    token.isHome
                                                        ? Icons.star_rounded
                                                        : Icons.workspace_premium_rounded,
                                                    color: Colors.white,
                                                    size: tokenSize * 0.58,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Dice Control Console (Ludo King Style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF131A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Active Player Turn Indicator
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getPlayerColor(_currentTurn).withValues(alpha: 0.2),
                          border: Border.all(color: _getPlayerColor(_currentTurn), width: 2),
                        ),
                        child: Center(
                          child: Icon(
                            _isCurrentPlayerAi() ? Icons.smart_toy_rounded : Icons.person_rounded,
                            color: _getPlayerColor(_currentTurn),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$_currentTurn Player",
                            style: TextStyle(
                              color: _getPlayerColor(_currentTurn),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            _isRolling
                                ? 'Rolling dice...'
                                : (_hasRolled ? 'Pick token' : 'Tap dice to roll'),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Ludo King 3D Realistic Pip Dice
                  GestureDetector(
                    onTap: (!_hasRolled && !_isRolling && !_isCurrentPlayerAi()) ? _rollDice : null,
                    child: AnimatedBuilder(
                      animation: _diceAnimController,
                      builder: (context, child) {
                        final angle = _isRolling ? _diceAnimController.value * 2 * pi : 0.0;

                        return Transform.rotate(
                          angle: angle,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _getPlayerColor(_currentTurn),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _getPlayerColor(_currentTurn).withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _buildDicePips(_diceValue, _getPlayerColor(_currentTurn)),
                          ),
                        );
                      },
                    ),
                  ),

                  // Roll Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPlayerColor(_currentTurn),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: (!_hasRolled && !_isRolling && !_isCurrentPlayerAi()) ? _rollDice : null,
                    child: Text(
                      _isRolling ? 'Rolling' : (_hasRolled ? 'Move' : 'Roll 🎲'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildPlayerCard(String player, String label, IconData icon, {required bool isLeft}) {
    final isTurn = _currentTurn == player;
    final color = _getPlayerColor(player);
    final homeCount = _tokens.where((t) => t.player == player && t.isHome).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isTurn ? color.withValues(alpha: 0.18) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTurn ? color : AppColors.cardBorder,
          width: isTurn ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$player ($label)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isTurn ? color : Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Home: $homeCount/$_tokensPerPlayer",
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (isTurn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'TURN',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds standard Ludo dice dots (pips)
  Widget _buildDicePips(int value, Color dotColor) {
    switch (value) {
      case 1:
        return Center(child: _diceDot(dotColor, 12));
      case 2:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(alignment: Alignment.topRight, child: _diceDot(dotColor)),
              Align(alignment: Alignment.bottomLeft, child: _diceDot(dotColor)),
            ],
          ),
        );
      case 3:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(alignment: Alignment.topRight, child: _diceDot(dotColor)),
              Center(child: _diceDot(dotColor)),
              Align(alignment: Alignment.bottomLeft, child: _diceDot(dotColor)),
            ],
          ),
        );
      case 4:
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_diceDot(dotColor), _diceDot(dotColor)]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_diceDot(dotColor), _diceDot(dotColor)]),
            ],
          ),
        );
      case 5:
        return Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_diceDot(dotColor), _diceDot(dotColor)]),
              Center(child: _diceDot(dotColor)),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_diceDot(dotColor), _diceDot(dotColor)]),
            ],
          ),
        );
      case 6:
      default:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_diceDot(dotColor), _diceDot(dotColor), _diceDot(dotColor)]),
              Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_diceDot(dotColor), _diceDot(dotColor), _diceDot(dotColor)]),
            ],
          ),
        );
    }
  }

  Widget _diceDot(Color color, [double size = 9]) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ----------------------------------------------------------------------------
// LUDO BOARD CUSTOM PAINTER (Classic Ludo King 15x15 Grid)
// ----------------------------------------------------------------------------

class LudoBoardPainter extends CustomPainter {
  static const Color redColor = Color(0xFFE53935);
  static const Color greenColor = Color(0xFF43A047);
  static const Color yellowColor = Color(0xFFFBC02D);
  static const Color blueColor = Color(0xFF1E88E5);
  static const Color gridLineColor = Color(0xFF94A3B8);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15.0;

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 1. Draw 4 Corner Yards (6x6 cells each)
    _drawYard(canvas, 0, 0, cell, redColor); // Red (Top-Left)
    _drawYard(canvas, 0, 9 * cell, cell, greenColor); // Green (Top-Right)
    _drawYard(canvas, 9 * cell, 9 * cell, cell, yellowColor); // Yellow (Bottom-Right)
    _drawYard(canvas, 9 * cell, 0, cell, blueColor); // Blue (Bottom-Left)

    // 2. Draw Track Grid (15x15 lines)
    final gridPaint = Paint()
      ..color = gridLineColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 15; i++) {
      final pos = i * cell;
      // Horizontal
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), gridPaint);
      // Vertical
      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), gridPaint);
    }

    // 3. Draw Home Paths
    final redPaint = Paint()..color = redColor;
    final greenPaint = Paint()..color = greenColor;
    final yellowPaint = Paint()..color = yellowColor;
    final bluePaint = Paint()..color = blueColor;

    // Red Home Path: Row 7, Cols 1..5
    for (int col = 1; col <= 5; col++) {
      canvas.drawRect(Rect.fromLTWH(col * cell, 7 * cell, cell, cell), redPaint);
    }
    // Green Home Path: Col 7, Rows 1..5
    for (int row = 1; row <= 5; row++) {
      canvas.drawRect(Rect.fromLTWH(7 * cell, row * cell, cell, cell), greenPaint);
    }
    // Yellow Home Path: Row 7, Cols 9..13
    for (int col = 9; col <= 13; col++) {
      canvas.drawRect(Rect.fromLTWH(col * cell, 7 * cell, cell, cell), yellowPaint);
    }
    // Blue Home Path: Col 7, Rows 9..13
    for (int row = 9; row <= 13; row++) {
      canvas.drawRect(Rect.fromLTWH(7 * cell, row * cell, cell, cell), bluePaint);
    }

    // 4. Starting tiles (colored background)
    canvas.drawRect(Rect.fromLTWH(1 * cell, 6 * cell, cell, cell), redPaint); // Red Start (6, 1)
    canvas.drawRect(Rect.fromLTWH(8 * cell, 1 * cell, cell, cell), greenPaint); // Green Start (1, 8)
    canvas.drawRect(Rect.fromLTWH(13 * cell, 8 * cell, cell, cell), yellowPaint); // Yellow Start (8, 13)
    canvas.drawRect(Rect.fromLTWH(6 * cell, 13 * cell, cell, cell), bluePaint); // Blue Start (13, 6)

    // 5. Draw 8 Safe Stars (⭐)
    _drawSafeStar(canvas, 1 * cell + cell / 2, 6 * cell + cell / 2, cell * 0.4, Colors.white); // Red start
    _drawSafeStar(canvas, 2 * cell + cell / 2, 8 * cell + cell / 2, cell * 0.4, const Color(0xFFD4AF37)); // Red safe
    _drawSafeStar(canvas, 8 * cell + cell / 2, 1 * cell + cell / 2, cell * 0.4, Colors.white); // Green start
    _drawSafeStar(canvas, 6 * cell + cell / 2, 2 * cell + cell / 2, cell * 0.4, const Color(0xFFD4AF37)); // Green safe
    _drawSafeStar(canvas, 13 * cell + cell / 2, 8 * cell + cell / 2, cell * 0.4, Colors.white); // Yellow start
    _drawSafeStar(canvas, 12 * cell + cell / 2, 6 * cell + cell / 2, cell * 0.4, const Color(0xFFD4AF37)); // Yellow safe
    _drawSafeStar(canvas, 6 * cell + cell / 2, 13 * cell + cell / 2, cell * 0.4, Colors.white); // Blue start
    _drawSafeStar(canvas, 8 * cell + cell / 2, 12 * cell + cell / 2, cell * 0.4, const Color(0xFFD4AF37)); // Blue safe

    // 6. Draw Center 3x3 Home Triangle (Rows 6..8, Cols 6..8)
    final centerLeft = 6 * cell;
    final centerTop = 6 * cell;
    final centerRight = 9 * cell;
    final centerBottom = 9 * cell;
    final midX = 7.5 * cell;
    final midY = 7.5 * cell;

    // Red Triangle (Left)
    final redPath = Path()
      ..moveTo(centerLeft, centerTop)
      ..lineTo(midX, midY)
      ..lineTo(centerLeft, centerBottom)
      ..close();
    canvas.drawPath(redPath, redPaint);

    // Green Triangle (Top)
    final greenPath = Path()
      ..moveTo(centerLeft, centerTop)
      ..lineTo(midX, midY)
      ..lineTo(centerRight, centerTop)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow Triangle (Right)
    final yellowPath = Path()
      ..moveTo(centerRight, centerTop)
      ..lineTo(midX, midY)
      ..lineTo(centerRight, centerBottom)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Blue Triangle (Bottom)
    final bluePath = Path()
      ..moveTo(centerLeft, centerBottom)
      ..lineTo(midX, midY)
      ..lineTo(centerRight, centerBottom)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Center Gold Ring
    final ringPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(midX, midY), cell * 0.6, ringPaint);
  }

  void _drawYard(Canvas canvas, double top, double left, double cell, Color color) {
    final yardSize = 6 * cell;

    // Outer colored block
    final yardPaint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(left, top, yardSize, yardSize), yardPaint);

    // Inner rounded white box
    final innerPadding = cell * 0.8;
    final innerPaint = Paint()..color = Colors.white;
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        left + innerPadding,
        top + innerPadding,
        yardSize - (innerPadding * 2),
        yardSize - (innerPadding * 2),
      ),
      Radius.circular(cell * 0.8),
    );
    canvas.drawRRect(innerRect, innerPaint);

    // 4 Token Pocket Circles
    final pocketRadius = cell * 0.7;
    final pocketOffsets = [
      Offset(left + 2.1 * cell, top + 2.1 * cell),
      Offset(left + 4.3 * cell, top + 2.1 * cell),
      Offset(left + 2.1 * cell, top + 4.3 * cell),
      Offset(left + 4.3 * cell, top + 4.3 * cell),
    ];

    for (final offset in pocketOffsets) {
      final fillPaint = Paint()..color = color.withValues(alpha: 0.25);
      final borderPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(offset, pocketRadius, fillPaint);
      canvas.drawCircle(offset, pocketRadius, borderPaint);
    }
  }

  void _drawSafeStar(Canvas canvas, double cx, double cy, double radius, Color color) {
    final path = Path();
    const int points = 5;
    final double innerRadius = radius * 0.45;
    double rot = (pi / 2) * 3;
    const double step = pi / points;

    path.moveTo(cx, cy - radius);
    for (int i = 0; i < points; i++) {
      double x = cx + cos(rot) * radius;
      double y = cy + sin(rot) * radius;
      path.lineTo(x, y);
      rot += step;

      x = cx + cos(rot) * innerRadius;
      y = cy + sin(rot) * innerRadius;
      path.lineTo(x, y);
      rot += step;
    }
    path.close();

    final starPaint = Paint()..color = color;
    canvas.drawPath(path, starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
