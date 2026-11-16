import 'dart:math';

import '../../core/models/card.dart';

/// 혼자 풀기 문항 수 선택지. 0은 "전부".
const soloCounts = [5, 10, 20, 0];

/// 범위·유형·문항 수로 문제집을 만든다. 카드는 섞는다.
/// [weeks]가 비어 있으면 전체 주차, [count]가 0이면 전부.
List<QuizCard> buildQuizSet(
  List<QuizCard> pool, {
  required Set<int> weeks,
  required Set<CardType> types,
  required int count,
  Random? random,
}) {
  final picked =
      pool
          .where((c) => weeks.isEmpty || weeks.contains(c.week))
          .where((c) => types.contains(c.type))
          .toList()
        ..shuffle(random ?? Random());
  return count <= 0 || picked.length <= count
      ? picked
      : picked.sublist(0, count);
}

/// 답을 채점한다. 단답형은 공백·대소문자를 무시한다.
bool isCorrectAnswer(QuizCard card, String answer) {
  switch (card.type) {
    case CardType.mcq:
    case CardType.ox:
      return answer == card.answer;
    case CardType.short:
      return normalizeAnswer(answer) == normalizeAnswer(card.answer);
  }
}

String normalizeAnswer(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// 문제 하나의 결과.
typedef QuizResult = ({QuizCard card, String answer, bool correct});

/// 결과 요약.
int countCorrect(List<QuizResult> results) =>
    results.where((r) => r.correct).length;
