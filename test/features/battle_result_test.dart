import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/features/battle/battle_repository.dart';
import 'package:pilgi_card_battle/features/battle/battle_result.dart';

BattleAnswer _a(int round, bool correct) => BattleAnswer(
  uid: 'me',
  round: round,
  choice: correct ? 'O' : 'X',
  correct: correct,
  elapsedMs: 1000,
);

void main() {
  test('맞힌 수·정답률·최고 콤보', () {
    final s = BattleSummary.of([
      _a(0, true),
      _a(1, true),
      _a(2, false),
      _a(3, true),
      _a(4, true),
    ], 5);
    expect(s.correct, 4);
    expect(s.percent, 80);
    expect(s.bestCombo, 2);
  });

  test('안 낸 라운드는 틀린 것으로 센다', () {
    final s = BattleSummary.of([_a(0, true), _a(2, true)], 3);
    expect(s.correct, 2);
    expect(s.bestCombo, 1);
  });

  test('문제가 없으면 정답률 0', () {
    expect(BattleSummary.of(const [], 0).percent, 0);
  });
}
