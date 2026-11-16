import '../../core/models/card.dart';

/// 배틀 시간·점수 규칙 (`docs/DATA.md` 점수 규칙).
abstract final class BattleRules {
  /// 문제 전 3-2-1
  static const countdown = Duration(seconds: 3);

  /// 문제 푸는 시간
  static const answerTime = Duration(seconds: 15);

  /// 정답 공개 후 다음 문제까지
  static const reveal = Duration(milliseconds: 2500);

  static const baseScore = 500;
  static const speedScore = 500;
  static const comboBonus = 100;

  /// 콤보 보너스가 붙기 시작하는 연속 정답 수
  static const comboFrom = 2;

  /// 정답: 500 + 남은시간비율 × 500 (최대 1000), 오답 0.
  static int answerScore({required bool correct, required int elapsedMs}) {
    if (!correct) return 0;
    final total = answerTime.inMilliseconds;
    final left = (total - elapsedMs).clamp(0, total);
    return baseScore + (speedScore * left / total).round();
  }

  /// 이번 답을 반영한 (점수 증가량, 새 콤보).
  /// 콤보: 연속 정답 2회부터 문제당 +100. 오답이면 콤보 0.
  static (int gained, int combo) apply({
    required bool correct,
    required int elapsedMs,
    required int prevCombo,
  }) {
    if (!correct) return (0, 0);
    final combo = prevCombo + 1;
    final bonus = combo >= comboFrom ? comboBonus : 0;
    return (answerScore(correct: true, elapsedMs: elapsedMs) + bonus, combo);
  }

  /// 답이 맞는지. 객관식·OX는 그대로 비교, 단답형은 공백·대소문자 무시.
  static bool isCorrect(QuizCard card, String choice) {
    if (choice.isEmpty) return false;
    return switch (card.type) {
      CardType.short => _norm(choice) == _norm(card.answer),
      CardType.ox =>
        choice.trim().toUpperCase() == card.answer.trim().toUpperCase(),
      CardType.mcq => choice.trim() == card.answer.trim(),
    };
  }

  static String _norm(String s) =>
      s.replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

/// 라운드 안에서 지금 어느 단계인지
enum RoundPhase { countdown, question, reveal }

/// 라운드 시작 후 [elapsed]가 지났을 때의 단계.
/// [everyoneAnswered]면 15초를 다 기다리지 않고 바로 정답 공개.
RoundPhase phaseAt(Duration elapsed, {required bool everyoneAnswered}) {
  if (elapsed < BattleRules.countdown) return RoundPhase.countdown;
  if (everyoneAnswered) return RoundPhase.reveal;
  if (elapsed < BattleRules.countdown + BattleRules.answerTime) {
    return RoundPhase.question;
  }
  return RoundPhase.reveal;
}
