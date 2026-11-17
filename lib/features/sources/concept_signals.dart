import '../../core/models/card.dart';
import '../../core/models/source.dart';

/// 개념 하나에 모인 근거 세 가지. 화면에서 서로 섞지 않고 따로 보여 준다.
/// - [cardCount]: AI가 이 개념으로 만든 카드 수 (AI 추정 중요 개념)
/// - [quotes]: 교수님이 실제로 강조한 발언 (녹음)
/// - [votes]: 친구들이 "나올 것 같아요"를 누른 수 (방 문제은행)
class ConceptSignal {
  const ConceptSignal({
    required this.concept,
    required this.cardCount,
    required this.quotes,
    required this.votes,
  });

  final String concept;
  final int cardCount;
  final List<EmphasisLine> quotes;
  final int votes;

  bool get professorSaid => quotes.isNotEmpty;
}

String _norm(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

/// 두 개념 태그가 같은 개념인지 (공백·대소문자 무시, 한쪽이 다른 쪽을 포함해도 같다고 본다).
bool sameConcept(String a, String b) {
  final x = _norm(a);
  final y = _norm(b);
  if (x.isEmpty || y.isEmpty) return false;
  return x == y || x.contains(y) || y.contains(x);
}

/// 자료 하나의 카드·강조 발언·투표 수를 개념별로 묶는다.
///
/// 정렬: 교수님 발언 있는 개념 → 투표 많은 순 → 카드 많은 순.
/// 카드와 이어지지 않은 강조 발언은 [concept]를 그 발언의 태그(없으면 "기타")로 따로 둔다.
List<ConceptSignal> buildConceptSignals({
  required List<QuizCard> cards,
  required List<EmphasisLine> emphasis,
  Map<String, int> votesByCardId = const {},
}) {
  final order = <String>[];
  final cardCount = <String, int>{};
  final votes = <String, int>{};
  for (final c in cards) {
    final concept = c.concept.trim();
    if (concept.isEmpty) continue;
    final key = order.firstWhere(
      (k) => _norm(k) == _norm(concept),
      orElse: () {
        order.add(concept);
        return concept;
      },
    );
    cardCount[key] = (cardCount[key] ?? 0) + 1;
    votes[key] = (votes[key] ?? 0) + (votesByCardId[c.id] ?? 0);
  }

  final quotes = <String, List<EmphasisLine>>{};
  for (final e in emphasis) {
    final match = order.where((k) => sameConcept(k, e.concept));
    final key = match.isNotEmpty
        ? match.first
        : (e.concept.trim().isEmpty ? '기타' : e.concept.trim());
    if (!order.contains(key)) order.add(key);
    quotes.putIfAbsent(key, () => []).add(e);
  }

  final list = [
    for (final k in order)
      ConceptSignal(
        concept: k,
        cardCount: cardCount[k] ?? 0,
        quotes: quotes[k] ?? const [],
        votes: votes[k] ?? 0,
      ),
  ];
  list.sort((a, b) {
    if (a.professorSaid != b.professorSaid) return a.professorSaid ? -1 : 1;
    if (a.votes != b.votes) return b.votes.compareTo(a.votes);
    return b.cardCount.compareTo(a.cardCount);
  });
  return list;
}
