import '../../core/models/attempt.dart';
import '../../core/models/card.dart';
import '../sources/concept_signals.dart';

/// 개념 하나의 풀이 성적.
class ConceptScore {
  const ConceptScore({
    required this.concept,
    required this.tries,
    required this.correct,
  });

  final String concept;
  final int tries;
  final int correct;

  double get rate => tries == 0 ? 0 : correct / tries;

  /// 정답률 0~100 (반올림)
  int get percent => (rate * 100).round();
}

/// 개념 태그별 정답률을 모아 약한 개념을 고른다 (혼자 풀기·배틀·모의고사 기록 모두).
///
/// - [minTries]번 이상 푼 개념만 본다 (한 번 틀린 걸로 약하다고 하지 않게).
/// - 다 맞힌 개념(100%)은 빼고, 정답률 낮은 순 → 많이 푼 순으로 [top]개.
/// - 태그는 공백·대소문자를 무시하고 같은 개념으로 합친다.
List<ConceptScore> weakConcepts(
  Iterable<Attempt> attempts, {
  int minTries = 2,
  int top = 3,
}) {
  final names = <String, String>{}; // 정규화 키 → 처음 본 표기
  final tries = <String, int>{};
  final correct = <String, int>{};
  for (final a in attempts) {
    final concept = a.concept.trim();
    if (concept.isEmpty) continue;
    final key = concept.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    names.putIfAbsent(key, () => concept);
    tries[key] = (tries[key] ?? 0) + 1;
    if (a.correct) correct[key] = (correct[key] ?? 0) + 1;
  }
  final scores = [
    for (final key in names.keys)
      if (tries[key]! >= minTries && (correct[key] ?? 0) < tries[key]!)
        ConceptScore(
          concept: names[key]!,
          tries: tries[key]!,
          correct: correct[key] ?? 0,
        ),
  ];
  scores.sort((a, b) {
    final byRate = a.rate.compareTo(b.rate);
    return byRate != 0 ? byRate : b.tries.compareTo(a.tries);
  });
  return scores.take(top).toList();
}

/// 약한 개념의 카드만 골라 약한 순서대로 돌려준다 (추천 카드).
List<QuizCard> recommendCards(List<QuizCard> cards, List<ConceptScore> weak) {
  return {
    for (final w in weak)
      ...cards.where((c) => sameConcept(c.concept, w.concept)),
  }.toList();
}
