import '../../core/models/card.dart';
import 'battle_rules.dart';

/// 혼자 하는 배틀 연습 한 판 (화면 없이 테스트할 수 있는 규칙만).
///
/// 점수·콤보는 배틀과 같은 [BattleRules]를 쓴다. 기기 안에서만 진행하고
/// 아무것도 저장하지 않는다 (배틀 기록·승패·XP·오답 노트에 안 들어감).
class PracticeGame {
  PracticeGame(this.cards);

  final List<QuizCard> cards;

  int round = 0;
  int score = 0;
  int combo = 0;
  int bestCombo = 0;
  int correctCount = 0;

  /// 이번 문제에 낸 답 (null = 아직, '' = 시간 초과)
  String? choice;

  /// 문제별 맞았는지 (끝난 문제만)
  final List<bool> results = [];

  QuizCard get card => cards[round];
  bool get answered => choice != null;
  bool get finished => round >= cards.length;
  int get total => cards.length;
  int get percent => total == 0 ? 0 : (correctCount * 100 / total).round();

  /// 답 내기. 이미 냈으면 무시. 반환: 맞았는지.
  bool answer(String picked, {required int elapsedMs}) {
    if (finished || answered) return results.isNotEmpty && results.last;
    choice = picked;
    final correct = BattleRules.isCorrect(card, picked);
    final (gained, nextCombo) = BattleRules.apply(
      correct: correct,
      elapsedMs: elapsedMs,
      prevCombo: combo,
    );
    score += gained;
    combo = nextCombo;
    if (combo > bestCombo) bestCombo = combo;
    if (correct) correctCount++;
    results.add(correct);
    return correct;
  }

  /// 시간 초과 = 오답 (콤보 끊김)
  void timeout() =>
      answer('', elapsedMs: BattleRules.answerTime.inMilliseconds);

  /// 다음 문제로 (답을 낸 뒤에만)
  void next() {
    if (!answered || finished) return;
    round++;
    choice = null;
  }
}
