import 'dart:math';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/game_sound_service.dart';
import '../theme/app_theme.dart';

enum GameMode {
  passAndPlay,
  vsAI,
}

enum TicTacToeDifficulty { easy, medium, hard }

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  // Board state: null for empty, 'X' or 'O'
  List<String?> _board = List.filled(9, null);
  bool _isXTurn = true;
  String? _winner;
  bool _isDraw = false;
  List<int> _winningIndices = [];

  // Game Mode
  GameMode _mode = GameMode.passAndPlay;
  TicTacToeDifficulty _difficulty = TicTacToeDifficulty.medium;

  // Scoreboard
  int _xWins = 0;
  int _oWins = 0;
  int _draws = 0;

  // AI Thinking state
  bool _isAiThinking = false;

  @override
  void initState() {
    super.initState();
    _resetBoard();
  }

  void _resetBoard() {
    setState(() {
      _board = List.filled(9, null);
      _isXTurn = true;
      _winner = null;
      _isDraw = false;
      _winningIndices = [];
      _isAiThinking = false;
    });
  }

  void _resetScores() {
    setState(() {
      _xWins = 0;
      _oWins = 0;
      _draws = 0;
      _resetBoard();
    });
  }

  void _handleCellTap(int index) {
    if (_board[index] != null || _winner != null || _isDraw || _isAiThinking) {
      return;
    }

    GameSoundService.ticTacToeCellTap();
    _makeMove(index, _isXTurn ? 'X' : 'O');

    // If game is still ongoing and playing against AI, trigger AI move
    if (_winner == null && !_isDraw && _mode == GameMode.vsAI && !_isXTurn) {
      _triggerAiMove();
    }
  }

  void _makeMove(int index, String symbol) {
    setState(() {
      _board[index] = symbol;
      _checkGameState();
      if (_winner == null && !_isDraw) {
        _isXTurn = !_isXTurn;
      }
    });
  }

  void _triggerAiMove() {
    setState(() {
      _isAiThinking = true;
    });

    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted || _winner != null || _isDraw) return;

      final aiMove = _calculateAiMove();
      if (aiMove != null) {
        GameSoundService.ticTacToeCellTap();
        _makeMove(aiMove, 'O');
      }

      if (!mounted) return;
      setState(() {
        _isAiThinking = false;
      });
    });
  }

  int? _calculateAiMove() {
    final available = <int>[];
    for (int i = 0; i < 9; i++) {
      if (_board[i] == null) available.add(i);
    }
    if (available.isEmpty) return null;

    if (_difficulty == TicTacToeDifficulty.easy) {
      available.shuffle(Random());
      return available.first;
    } else if (_difficulty == TicTacToeDifficulty.medium) {
      // 50% chance smart, 50% chance random
      if (Random().nextBool()) {
        return _calculateBestAiMove();
      } else {
        available.shuffle(Random());
        return available.first;
      }
    } else {
      // Hard mode: minimax / optimal
      return _calculateBestAiMove();
    }
  }

  int? _calculateBestAiMove() {
    // 1. Check if AI can win on next move
    for (int i = 0; i < 9; i++) {
      if (_board[i] == null) {
        _board[i] = 'O';
        if (_evaluateWinner(_board) == 'O') {
          _board[i] = null;
          return i;
        }
        _board[i] = null;
      }
    }

    // 2. Block player X if they can win
    for (int i = 0; i < 9; i++) {
      if (_board[i] == null) {
        _board[i] = 'X';
        if (_evaluateWinner(_board) == 'X') {
          _board[i] = null;
          return i;
        }
        _board[i] = null;
      }
    }

    // 3. Take center if available
    if (_board[4] == null) return 4;

    // 4. Take corners if available
    final corners = [0, 2, 6, 8]..shuffle();
    for (final c in corners) {
      if (_board[c] == null) return c;
    }

    // 5. Take any remaining empty cell
    final available = <int>[];
    for (int i = 0; i < 9; i++) {
      if (_board[i] == null) available.add(i);
    }

    if (available.isNotEmpty) {
      available.shuffle(Random());
      return available.first;
    }

    return null;
  }

  String? _evaluateWinner(List<String?> board) {
    const winningPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // Cols
      [0, 4, 8], [2, 4, 6], // Diagonals
    ];

    for (final pattern in winningPatterns) {
      final a = board[pattern[0]];
      final b = board[pattern[1]];
      final c = board[pattern[2]];

      if (a != null && a == b && b == c) {
        return a;
      }
    }
    return null;
  }

  void _checkGameState() {
    const winningPatterns = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // Cols
      [0, 4, 8], [2, 4, 6], // Diagonals
    ];

    for (final pattern in winningPatterns) {
      final a = _board[pattern[0]];
      final b = _board[pattern[1]];
      final c = _board[pattern[2]];

      if (a != null && a == b && b == c) {
        _winner = a;
        _winningIndices = pattern;
        if (a == 'X') {
          _xWins++;
        } else {
          _oWins++;
        }
        _showGameOverModal();
        return;
      }
    }

    if (!_board.contains(null)) {
      _isDraw = true;
      _draws++;
      _showGameOverModal();
    }
  }

  void _showGameOverModal() {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      final isWon = _winner == 'X';
      final unlockedTitle = AuthService().recordMatchResult(
        gameId: 'tic_tac_toe',
        won: isWon,
      );
      final user = AuthService().currentUser;

      String message;
      Color accent;
      IconData icon;

      if (_isDraw) {
        GameSoundService.ticTacToeDraw();
        message = "Well played! It's a draw.";
        accent = AppColors.trophyGold;
        icon = Icons.handshake_rounded;
      } else if (isWon) {
        GameSoundService.ticTacToeWin();
        message = _mode == GameMode.vsAI
            ? "Victory! You defeated the AI bot!"
            : "Player X wins the match!";
        accent = AppColors.primaryBlueLight;
        icon = Icons.emoji_events_rounded;
      } else {
        GameSoundService.gameOver();
        message = _mode == GameMode.vsAI
            ? "AI Bot won this round! Rematch?"
            : "Player O wins the match!";
        accent = AppColors.primaryPurpleLight;
        icon = Icons.smart_toy_rounded;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.5),
          ),
          title: Row(
            children: [
              Icon(icon, color: accent, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isDraw ? 'Game Tied' : 'Round Over',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primaryPurple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _rewardItem(
                        Icons.bolt_rounded,
                        isWon ? '+100 XP' : '+25 XP',
                        AppColors.primaryBlueLight),
                    _rewardItem(Icons.monetization_on_rounded,
                        isWon ? '+50 Coins' : '+10 Coins', AppColors.coinAmber),
                    _rewardItem(Icons.military_tech_rounded,
                        'Level ${user?.level ?? 1}', AppColors.onlineGreen),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Wins: ${user?.totalWins ?? 0}/20 towards Ludo Friends (Level 5)',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              if (unlockedTitle != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      AppColors.primaryPurple,
                      AppColors.accentCyan
                    ]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_open_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🎉 NEW GAME UNLOCKED: $unlockedTitle!',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
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
              },
              child: const Text('Review Board'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _resetBoard();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'Play Again',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _rewardItem(IconData icon, String text, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tic-Tac-Toe Arena'),
        actions: [
          PopupMenuButton<TicTacToeDifficulty>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'AI Difficulty: ${_difficulty.name.toUpperCase()}',
            initialValue: _difficulty,
            onSelected: (mode) {
              setState(() {
                _difficulty = mode;
                _resetBoard();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Bot difficulty set to ${mode.name.toUpperCase()}'),
                  duration: const Duration(milliseconds: 900),
                ),
              );
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: TicTacToeDifficulty.easy,
                child: Row(
                  children: [
                    const Icon(Icons.sentiment_satisfied_alt_rounded,
                        color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                        'Easy Bot ${_difficulty == TicTacToeDifficulty.easy ? "✓" : ""}'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: TicTacToeDifficulty.medium,
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy_rounded, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                        'Medium Bot ${_difficulty == TicTacToeDifficulty.medium ? "✓" : ""}'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: TicTacToeDifficulty.hard,
                child: Row(
                  children: [
                    const Icon(Icons.psychology_rounded,
                        color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Text(
                        'Hard Bot (Master) ${_difficulty == TicTacToeDifficulty.hard ? "✓" : ""}'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Restart Board',
            onPressed: _resetBoard,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // Mode Selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_mode != GameMode.passAndPlay) {
                            setState(() {
                              _mode = GameMode.passAndPlay;
                              _resetBoard();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _mode == GameMode.passAndPlay
                                ? AppColors.primaryPurple
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Pass & Play',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _mode == GameMode.passAndPlay
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_mode != GameMode.vsAI) {
                            setState(() {
                              _mode = GameMode.vsAI;
                              _resetBoard();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _mode == GameMode.vsAI
                                ? AppColors.primaryBlue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.smart_toy_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Vs AI (${_difficulty.name[0].toUpperCase()}${_difficulty.name.substring(1)})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _mode == GameMode.vsAI
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Scoreboard Card
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildScoreItem(
                      label: _mode == GameMode.vsAI ? 'You (X)' : 'Player X',
                      score: _xWins,
                      color: AppColors.primaryBlueLight,
                      isActive: _isXTurn && _winner == null && !_isDraw,
                    ),
                    Container(
                        width: 1, height: 36, color: AppColors.cardBorder),
                    _buildScoreItem(
                      label: 'Ties',
                      score: _draws,
                      color: AppColors.textSecondary,
                      isActive: false,
                    ),
                    Container(
                        width: 1, height: 36, color: AppColors.cardBorder),
                    _buildScoreItem(
                      label: _mode == GameMode.vsAI ? 'AI Bot (O)' : 'Player O',
                      score: _oWins,
                      color: AppColors.primaryPurpleLight,
                      isActive: !_isXTurn && _winner == null && !_isDraw,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Status indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _winner != null
                      ? AppColors.trophyGold.withValues(alpha: 0.15)
                      : (_isAiThinking
                          ? AppColors.primaryPurple.withValues(alpha: 0.15)
                          : AppColors.surfaceLight),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _winner != null
                        ? AppColors.trophyGold
                        : (_isXTurn
                            ? AppColors.primaryBlueLight
                            : AppColors.primaryPurpleLight),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isAiThinking) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryPurpleLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AI Bot is calculating move...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryPurpleLight,
                        ),
                      ),
                    ] else if (_winner != null) ...[
                      const Icon(Icons.emoji_events_rounded,
                          size: 16, color: AppColors.trophyGold),
                      const SizedBox(width: 6),
                      Text(
                        'Winner: $_winner',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.trophyGold,
                        ),
                      ),
                    ] else if (_isDraw) ...[
                      const Text(
                        'Game Draw!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ] else ...[
                      Text(
                        _isXTurn
                            ? (_mode == GameMode.vsAI
                                ? "Your Turn (X)"
                                : "Player X's Turn")
                            : (_mode == GameMode.vsAI
                                ? "AI's Turn (O)"
                                : "Player O's Turn"),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isXTurn
                              ? AppColors.primaryBlueLight
                              : AppColors.primaryPurpleLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3x3 Game Board Grid
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppColors.primaryPurple.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 9,
                    itemBuilder: (context, index) {
                      final value = _board[index];
                      final isWinningCell = _winningIndices.contains(index);

                      return GestureDetector(
                        onTap: () => _handleCellTap(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(
                            color: isWinningCell
                                ? AppColors.trophyGold.withValues(alpha: 0.25)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isWinningCell
                                  ? AppColors.trophyGold
                                  : (value != null
                                      ? (value == 'X'
                                          ? AppColors.primaryBlue
                                              .withValues(alpha: 0.5)
                                          : AppColors.primaryPurple
                                              .withValues(alpha: 0.5))
                                      : AppColors.cardBorder),
                              width: isWinningCell ? 2.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: value == null
                                ? const SizedBox.shrink()
                                : AnimatedScale(
                                    scale: 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Text(
                                      value,
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w900,
                                        color: value == 'X'
                                            ? AppColors.primaryBlueLight
                                            : AppColors.primaryPurpleLight,
                                        shadows: [
                                          Shadow(
                                            color: value == 'X'
                                                ? AppColors.primaryBlue
                                                    .withValues(alpha: 0.8)
                                                : AppColors.primaryPurple
                                                    .withValues(alpha: 0.8),
                                            blurRadius: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('New Round'),
                      onPressed: _resetBoard,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Reset Score'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceLight,
                        foregroundColor: AppColors.textSecondary,
                      ),
                      onPressed: _resetScores,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreItem({
    required String label,
    required int score,
    required Color color,
    required bool isActive,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
