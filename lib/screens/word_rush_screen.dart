import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/game_sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/music_player_sheet.dart';

enum WordDifficulty { easy, medium, hard }

class WordRushScreen extends StatefulWidget {
  const WordRushScreen({super.key});

  @override
  State<WordRushScreen> createState() => _WordRushScreenState();
}

class _WordRushScreenState extends State<WordRushScreen> {
  final List<String> _targetWords = [
    'FRIEND',
    'GAMING',
    'ARCADE',
    'CLASH',
    'VICTORY',
    'STRIKER',
    'WINNER',
    'CHAMPION',
    'MASTER',
    'LEGEND',
  ];

  late String _currentWord;
  late List<String> _scrambledLetters;
  String _currentInput = "";
  int _playerScore = 0;
  int _aiScore = 0;
  int _timeLeft = 45;
  bool _isPlaying = true;

  WordDifficulty _difficulty = WordDifficulty.medium;
  Timer? _gameTimer;
  Timer? _aiTimer;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _aiTimer?.cancel();
    super.dispose();
  }

  void _startRound() {
    _gameTimer?.cancel();
    _aiTimer?.cancel();

    final rng = Random();
    _currentWord = _targetWords[rng.nextInt(_targetWords.length)];
    _scrambledLetters = _currentWord.split('')..shuffle(rng);
    _currentInput = "";
    _playerScore = 0;
    _aiScore = 0;
    _timeLeft = 45;
    _isPlaying = true;

    // Countdown Timer
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _onGameEnd();
        }
      });
    });

    // AI Bot scoring periodically
    final aiInterval = _difficulty == WordDifficulty.easy
        ? const Duration(seconds: 12)
        : (_difficulty == WordDifficulty.medium
            ? const Duration(seconds: 7)
            : const Duration(seconds: 4));

    _aiTimer = Timer.periodic(aiInterval, (_) {
      if (!_isPlaying || !mounted) return;
      setState(() {
        _aiScore += 20;
      });
    });
  }

  void _onLetterTap(String letter) {
    if (!_isPlaying) return;
    GameSoundService.ticTacToeCellTap();
    setState(() {
      _currentInput += letter;
    });

    // Check match
    if (_currentInput == _currentWord) {
      GameSoundService.spaceDodgeStar();
      setState(() {
        _playerScore += 50 + (_timeLeft * 2);
        _currentInput = "";
        // Pick new word
        final rng = Random();
        _currentWord = _targetWords[rng.nextInt(_targetWords.length)];
        _scrambledLetters = _currentWord.split('')..shuffle(rng);
      });
    }
  }

  void _clearInput() {
    GameSoundService.buttonTap();
    setState(() => _currentInput = "");
  }

  void _onGameEnd() {
    _isPlaying = false;
    _gameTimer?.cancel();
    _aiTimer?.cancel();

    final won = _playerScore > _aiScore;
    if (won) {
      GameSoundService.ludoWin();
    } else {
      GameSoundService.gameOver();
    }

    final unlocked =
        AuthService().recordMatchResult(gameId: 'word_rush', won: won);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(won ? Icons.emoji_events_rounded : Icons.sports_score_rounded,
                color: won ? AppColors.trophyGold : AppColors.textSecondary,
                size: 28),
            const SizedBox(width: 10),
            Text(won ? 'Word Rush Won!' : 'Time Up!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Score: $_playerScore pts • AI Score: $_aiScore pts'),
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
                  _statItem(Icons.bolt_rounded, won ? '+120 XP' : '+30 XP',
                      AppColors.primaryBlueLight),
                  _statItem(Icons.monetization_on_rounded,
                      won ? '+60 Coins' : '+15 Coins', AppColors.coinAmber),
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
            child: const Text('Exit to Arcade'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startRound();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String text, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Word Sprint Rush',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.music_note_rounded),
            tooltip: 'Music Store',
            onPressed: () => MusicPlayerSheet.show(context),
          ),
          PopupMenuButton<WordDifficulty>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Difficulty: ${_difficulty.name.toUpperCase()}',
            initialValue: _difficulty,
            onSelected: (mode) {
              setState(() => _difficulty = mode);
              _startRound();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: WordDifficulty.easy,
                  child: Text(
                      'Easy ${_difficulty == WordDifficulty.easy ? "✓" : ""}')),
              PopupMenuItem(
                  value: WordDifficulty.medium,
                  child: Text(
                      'Medium ${_difficulty == WordDifficulty.medium ? "✓" : ""}')),
              PopupMenuItem(
                  value: WordDifficulty.hard,
                  child: Text(
                      'Hard ${_difficulty == WordDifficulty.hard ? "✓" : ""}')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _startRound,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Score & Time Row
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _hudBadge(
                        'You', '$_playerScore pts', AppColors.primaryBlueLight),
                    _hudBadge(
                        'Timer',
                        '${_timeLeft}s',
                        _timeLeft < 10
                            ? Colors.redAccent
                            : AppColors.coinAmber),
                    _hudBadge('AI Bot', '$_aiScore pts', AppColors.dangerRose),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text('Unscramble the Gaming Word:',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),

              // Current Input Container
              Container(
                height: 60,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.6),
                      width: 2),
                ),
                child: Text(
                  _currentInput.isEmpty ? 'TAP LETTERS BELOW' : _currentInput,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: _currentInput.isEmpty
                        ? Colors.white24
                        : AppColors.accentCyan,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Letter Tiles
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _scrambledLetters.map((char) {
                  return InkWell(
                    onTap: () => _onLetterTap(char),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryPurple, Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primaryPurple
                                  .withValues(alpha: 0.4),
                              blurRadius: 8),
                        ],
                      ),
                      child: Text(
                        char,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(),

              // Clear Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.backspace_rounded, size: 18),
                  label: const Text('Clear Letters',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.dangerRose),
                    foregroundColor: AppColors.dangerRose,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _clearInput,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hudBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
