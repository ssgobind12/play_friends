import 'package:flutter_test/flutter_test.dart';

// Standalone game logic evaluator matching the Tic-Tac-Toe rules
String? evaluateWinner(List<String?> board) {
  const winningPatterns = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // Columns
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

bool isBoardFull(List<String?> board) {
  return !board.contains(null);
}

void main() {
  group('Tic-Tac-Toe Game Logic Tests', () {
    test('Empty board has no winner and is not full', () {
      final board = List<String?>.filled(9, null);
      expect(evaluateWinner(board), isNull);
      expect(isBoardFull(board), isFalse);
    });

    test('Detects row 1 win for X', () {
      final board = <String?>[
        'X',
        'X',
        'X',
        null,
        'O',
        null,
        'O',
        null,
        null,
      ];
      expect(evaluateWinner(board), equals('X'));
    });

    test('Detects column 2 win for O', () {
      final board = <String?>[
        'X',
        'O',
        null,
        'X',
        'O',
        null,
        null,
        'O',
        'X',
      ];
      expect(evaluateWinner(board), equals('O'));
    });

    test('Detects diagonal win for X', () {
      final board = <String?>[
        'X',
        'O',
        null,
        'O',
        'X',
        null,
        null,
        'O',
        'X',
      ];
      expect(evaluateWinner(board), equals('X'));
    });

    test('Detects anti-diagonal win for O', () {
      final board = <String?>[
        'X',
        'X',
        'O',
        'X',
        'O',
        null,
        'O',
        null,
        null,
      ];
      expect(evaluateWinner(board), equals('O'));
    });

    test('Detects draw when board is full without a winner', () {
      final board = <String?>[
        'X',
        'O',
        'X',
        'X',
        'O',
        'O',
        'O',
        'X',
        'X',
      ];
      expect(evaluateWinner(board), isNull);
      expect(isBoardFull(board), isTrue);
    });
  });
}
