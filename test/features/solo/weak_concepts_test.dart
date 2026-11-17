import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/attempt.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/features/notebook/notebook_model.dart';
import 'package:pilgi_card_battle/features/solo/weak_concepts.dart';

Attempt _a(String concept, bool correct, [int i = 0]) => Attempt(
  id: '$concept-$i-$correct',
  cardId: 'c-$concept',
  subjectId: 's',
  concept: concept,
  correct: correct,
  mode: AttemptMode.solo,
  at: DateTime(2026, 11, 17),
);

void main() {
  test('정답률 낮은 개념부터 3개, 1번만 푼 개념·다 맞힌 개념은 뺀다', () {
    final attempts = [
      _a('TCP', false, 1), _a('TCP', false, 2), _a('TCP', true, 3), // 33%
      _a('UDP', true, 1), _a('UDP', false, 2), // 50%
      _a('A R P', false, 1), _a('arp', false, 2), // 0%, 같은 개념으로 합침
      _a('IP', true, 1), _a('IP', true, 2), // 100% → 제외
      _a('DNS', false, 1), // 1번 → 제외
      _a('', false, 1), _a('', false, 2), // 태그 없음 → 제외
      _a('HTTP', false, 1), _a('HTTP', true, 2), // 50%
    ];
    final weak = weakConcepts(attempts);
    expect(weak.map((w) => w.concept), ['A R P', 'TCP', 'UDP']);
    expect(weak.first.percent, 0);
    expect(weak[1].tries, 3);
  });

  test('추천 카드는 약한 개념 순서대로, 중복 없이', () {
    final base = QuizCard.sample();
    final cards = [
      base.copyWith(id: '1', concept: 'UDP 특징'),
      base.copyWith(id: '2', concept: 'TCP'),
      base.copyWith(id: '3', concept: 'IP'),
    ];
    final weak = [
      const ConceptScore(concept: 'TCP', tries: 2, correct: 0),
      const ConceptScore(concept: 'UDP', tries: 2, correct: 1),
    ];
    expect(recommendCards(cards, weak).map((c) => c.id), ['2', '1']);
  });

  test('족보 노트 즐겨찾기 필터', () {
    final base = QuizCard.sample();
    final cards = [base.copyWith(id: 'a'), base.copyWith(id: 'b')];
    expect(
      filterByStatus(
        cards,
        NotebookStatus.favorite,
        favorites: {'b'},
      ).map((c) => c.id),
      ['b'],
    );
    expect(filterByStatus(cards, NotebookStatus.favorite), isEmpty);
  });
}
