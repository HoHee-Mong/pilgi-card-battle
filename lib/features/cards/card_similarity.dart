import '../../core/models/card.dart';

/// 비슷한 질문 안내 (P1: 단순 문자열 유사도).
///
/// 글자 2개씩 묶은 조각(bigram)을 비교하는 Dice 계수를 쓴다.
/// 한국어는 띄어쓰기가 들쭉날쭉해도 글자 단위라서 잘 잡히고,
/// 어순이 조금 달라도 같은 조각이 많으면 비슷하다고 본다.
abstract final class CardSimilarity {
  /// 이 값 이상이면 "비슷한 문제"로 안내한다.
  static const threshold = 0.55;

  /// 안내에 보여 줄 최대 장수.
  static const maxResults = 3;

  /// 공백·문장부호를 빼고 소문자로 만든다. 비교 전에 양쪽 모두 거친다.
  static String normalize(String s) {
    return s.toLowerCase().replaceAll(
      RegExp(r'[\s\p{P}\p{S}]', unicode: true),
      '',
    );
  }

  static Map<String, int> _bigrams(String s) {
    final map = <String, int>{};
    for (var i = 0; i + 1 < s.length; i++) {
      final g = s.substring(i, i + 2);
      map[g] = (map[g] ?? 0) + 1;
    }
    return map;
  }

  /// 0(전혀 다름) ~ 1(같음).
  static double score(String a, String b) {
    final na = normalize(a);
    final nb = normalize(b);
    if (na.isEmpty || nb.isEmpty) return 0;
    if (na == nb) return 1;
    if (na.length < 2 || nb.length < 2) return 0;
    final ga = _bigrams(na);
    final gb = _bigrams(nb);
    var shared = 0;
    for (final e in ga.entries) {
      final other = gb[e.key];
      if (other != null) shared += e.value < other ? e.value : other;
    }
    return 2 * shared / ((na.length - 1) + (nb.length - 1));
  }

  /// [question]과 비슷한 카드를 점수 높은 순으로 돌려준다.
  /// [excludeId]는 지금 수정 중인 카드 자신.
  static List<SimilarCard> find(
    String question,
    Iterable<QuizCard> candidates, {
    String? excludeId,
    double threshold = threshold,
    int limit = maxResults,
  }) {
    if (normalize(question).length < 2) return const [];
    final hits = <SimilarCard>[];
    for (final c in candidates) {
      if (c.id == excludeId) continue;
      final s = score(question, c.question);
      if (s >= threshold) hits.add((card: c, score: s));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }

  /// 목록 안에서 서로 비슷한 카드를 찾아 `카드 ID → 비슷한 장수`로 돌려준다.
  /// 검수 목록에서 "비슷한 문제 있음" 표시에 쓴다.
  static Map<String, int> countWithin(
    Iterable<QuizCard> targets,
    Iterable<QuizCard> pool, {
    double threshold = threshold,
  }) {
    final result = <String, int>{};
    for (final t in targets) {
      final n = find(
        t.question,
        pool,
        excludeId: t.id,
        threshold: threshold,
        limit: pool.length,
      ).length;
      if (n > 0) result[t.id] = n;
    }
    return result;
  }
}

typedef SimilarCard = ({QuizCard card, double score});
