// ignore_for_file: avoid_print
// Pure Dart test runner to verify Tic-Tac-Toe logic without any external dependencies

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
  int passed = 0;
  int failed = 0;

  void expectEqual(dynamic actual, dynamic expected, String description) {
    if (actual == expected) {
      print('  PASS: $description');
      passed++;
    } else {
      print('  FAIL: $description (Expected $expected, got $actual)');
      failed++;
    }
  }

  print('--- Running Tic-Tac-Toe Engine Verification ---');

  // Test 1: Empty board
  final empty = List<String?>.filled(9, null);
  expectEqual(evaluateWinner(empty), null, 'Empty board has no winner');
  expectEqual(isBoardFull(empty), false, 'Empty board is not full');

  // Test 2: Row win
  final rowWin = <String?>[
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
  expectEqual(evaluateWinner(rowWin), 'X', 'Detects row 1 win for X');

  // Test 3: Column win
  final colWin = <String?>[
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
  expectEqual(evaluateWinner(colWin), 'O', 'Detects column 2 win for O');

  // Test 4: Diagonal win
  final diagWin = <String?>[
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
  expectEqual(evaluateWinner(diagWin), 'X', 'Detects diagonal win for X');

  // Test 5: Anti-diagonal win
  final antiDiagWin = <String?>[
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
  expectEqual(
      evaluateWinner(antiDiagWin), 'O', 'Detects anti-diagonal win for O');

  // Test 6: Draw condition
  final drawBoard = <String?>[
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
  expectEqual(evaluateWinner(drawBoard), null, 'Draw board has no winner');
  expectEqual(isBoardFull(drawBoard), true, 'Draw board is full');

  print('\nSummary: $passed passed, $failed failed');
  if (failed > 0) {
    throw Exception('Logic tests failed!');
  }
}
