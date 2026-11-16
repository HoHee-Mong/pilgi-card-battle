import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/features/battle/battle_rules.dart';

QuizCard _card(
  CardType type,
  String answer, [
  List<String> choices = const [],
]) => QuizCard(
  id: 'c',
  ownerId: 'o',
  ownerNickname: '',
  subjectId: 's',
  week: 1,
  sourceId: '',
  sourceLabel: '',
  type: type,
  question: 'q',
  choices: choices,
  answer: answer,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('점수', () {
    test('바로 맞히면 1000, 시간 다 써서 맞히면 500, 틀리면 0', () {
      expect(BattleRules.answerScore(correct: true, elapsedMs: 0), 1000);
      expect(BattleRules.answerScore(correct: true, elapsedMs: 15000), 500);
      expect(BattleRules.answerScore(correct: true, elapsedMs: 7500), 750);
      expect(BattleRules.answerScore(correct: false, elapsedMs: 0), 0);
    });

    test('콤보: 2연속부터 +100, 틀리면 0으로', () {
      expect(BattleRules.apply(correct: true, elapsedMs: 0, prevCombo: 0), (
        1000,
        1,
      ));
      expect(BattleRules.apply(correct: true, elapsedMs: 0, prevCombo: 1), (
        1100,
        2,
      ));
      expect(BattleRules.apply(correct: false, elapsedMs: 0, prevCombo: 5), (
        0,
        0,
      ));
    });
  });

  group('채점', () {
    test('객관식은 보기 그대로', () {
      final c = _card(CardType.mcq, '대비를 높인다', ['대비를 높인다', '크기를 줄인다']);
      expect(BattleRules.isCorrect(c, '대비를 높인다'), isTrue);
      expect(BattleRules.isCorrect(c, '크기를 줄인다'), isFalse);
    });

    test('OX는 대소문자 무시', () {
      expect(BattleRules.isCorrect(_card(CardType.ox, 'O'), 'o'), isTrue);
      expect(BattleRules.isCorrect(_card(CardType.ox, 'O'), 'X'), isFalse);
    });

    test('단답형은 띄어쓰기·대소문자 무시, 빈 답은 오답', () {
      final c = _card(CardType.short, 'Histogram Equalization');
      expect(BattleRules.isCorrect(c, 'histogramequalization'), isTrue);
      expect(BattleRules.isCorrect(c, ''), isFalse);
    });
  });

  group('라운드 단계', () {
    test('3초 카운트다운 → 15초 문제 → 정답 공개', () {
      expect(
        phaseAt(const Duration(seconds: 1), everyoneAnswered: false),
        RoundPhase.countdown,
      );
      expect(
        phaseAt(const Duration(seconds: 5), everyoneAnswered: false),
        RoundPhase.question,
      );
      expect(
        phaseAt(const Duration(seconds: 19), everyoneAnswered: false),
        RoundPhase.reveal,
      );
    });

    test('모두 답하면 바로 정답 공개 (카운트다운 중엔 아님)', () {
      expect(
        phaseAt(const Duration(seconds: 5), everyoneAnswered: true),
        RoundPhase.reveal,
      );
      expect(
        phaseAt(const Duration(seconds: 1), everyoneAnswered: true),
        RoundPhase.countdown,
      );
    });
  });
}
