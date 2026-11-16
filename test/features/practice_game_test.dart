import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/features/battle/battle_rules.dart';
import 'package:pilgi_card_battle/features/battle/practice_game.dart';

QuizCard _ox(String id, String answer) => QuizCard.sample().copyWith(
  id: id,
  type: CardType.ox,
  answer: answer,
  choices: const [],
);

void main() {
  PracticeGame game() =>
      PracticeGame([_ox('a', 'O'), _ox('b', 'X'), _ox('c', 'O')]);

  test('정답: 배틀과 같은 점수 (빠를수록 높음)', () {
    final g = game();
    expect(g.answer('O', elapsedMs: 0), isTrue);
    expect(g.score, BattleRules.answerScore(correct: true, elapsedMs: 0));
    expect(g.combo, 1);
  });

  test('연속 정답이면 콤보 보너스, 오답·시간 초과면 콤보 끊김', () {
    final g = game();
    g.answer('O', elapsedMs: 15000);
    g.next();
    g.answer('X', elapsedMs: 15000);
    expect(g.combo, 2);
    expect(g.score, 500 + 500 + BattleRules.comboBonus);
    g.next();
    g.timeout();
    expect(g.combo, 0);
    expect(g.bestCombo, 2);
    expect(g.results, [true, true, false]);
  });

  test('한 문제에 두 번 내도 처음 답만', () {
    final g = game();
    g.answer('X', elapsedMs: 1000);
    g.answer('O', elapsedMs: 1000);
    expect(g.correctCount, 0);
    expect(g.choice, 'X');
  });

  test('답을 안 내면 다음으로 못 감, 끝나면 finished와 정답률', () {
    final g = game();
    g.next();
    expect(g.round, 0);
    for (var i = 0; i < 3; i++) {
      g.answer('O', elapsedMs: 0);
      g.next();
    }
    expect(g.finished, isTrue);
    expect(g.correctCount, 2);
    expect(g.percent, 67);
  });
}
