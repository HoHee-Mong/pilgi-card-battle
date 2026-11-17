import 'dart:math';

import '../../core/models/attempt.dart';
import '../../core/models/card.dart';

/// 혼자 풀기 문항 수 선택지. 0은 "전부".
const soloCounts = [5, 10, 20, 0];

/// 범위·유형·문항 수로 문제집을 만든다.
/// [weeks]가 비어 있으면 전체 주차, [count]가 0이면 전부.
///
/// 같은 범위를 다시 풀어도 같은 문제가 되풀이되지 않게:
/// - [lastSolved](cardId → 마지막으로 푼 때)에 없는 **안 푼 카드**를 먼저,
///   그다음 **오래전에 푼 카드**부터 뽑는다.
/// - 뽑은 문제의 순서와 객관식 보기 순서도 매번 섞는다.
List<QuizCard> buildQuizSet(
  List<QuizCard> pool, {
  required Set<int> weeks,
  required Set<CardType> types,
  required int count,
  Map<String, DateTime> lastSolved = const {},
  Random? random,
}) {
  final rng = random ?? Random();
  final matched = pool
      .where((c) => weeks.isEmpty || weeks.contains(c.week))
      .where((c) => types.contains(c.type))
      .toList();
  final fresh = matched.where((c) => !lastSolved.containsKey(c.id)).toList()
    ..shuffle(rng);
  final solved = matched.where((c) => lastSolved.containsKey(c.id)).toList()
    ..shuffle(rng) // 같은 때 푼 카드끼리는 무작위
    ..sort((a, b) => lastSolved[a.id]!.compareTo(lastSolved[b.id]!));
  final ordered = [...fresh, ...solved];
  final picked = count <= 0 || ordered.length <= count
      ? ordered
      : ordered.sublist(0, count);
  return (picked.map((c) => shuffleChoices(c, rng)).toList()..shuffle(rng));
}

/// 객관식 보기 순서를 섞은 카드. 정답은 보기 글자로 맞히므로 그대로 맞다.
QuizCard shuffleChoices(QuizCard card, Random rng) {
  if (card.type != CardType.mcq || card.choices.length < 2) return card;
  return card.copyWith(choices: [...card.choices]..shuffle(rng));
}

/// 카드마다 마지막으로 푼 때 (혼자 풀기·배틀·모의고사 모두).
Map<String, DateTime> lastSolvedAt(Iterable<Attempt> attempts) {
  final map = <String, DateTime>{};
  for (final a in attempts) {
    final prev = map[a.cardId];
    if (prev == null || a.at.isAfter(prev)) map[a.cardId] = a.at;
  }
  return map;
}

/// 조건에 맞는 카드 중 아직 안 푼 카드 수.
int countUnsolved(
  List<QuizCard> pool, {
  required Set<int> weeks,
  required Set<CardType> types,
  required Map<String, DateTime> lastSolved,
}) {
  return pool
      .where((c) => weeks.isEmpty || weeks.contains(c.week))
      .where((c) => types.contains(c.type))
      .where((c) => !lastSolved.containsKey(c.id))
      .length;
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
