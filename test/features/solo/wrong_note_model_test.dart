import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/attempt.dart';
import 'package:pilgi_card_battle/features/solo/wrong_note_model.dart';

Attempt _a(
  String card,
  bool correct,
  int day, [
  AttemptMode mode = AttemptMode.solo,
]) => Attempt(
  id: '$card-$day',
  cardId: card,
  subjectId: 's',
  concept: '',
  correct: correct,
  mode: mode,
  at: DateTime(2026, 11, day),
);

void main() {
  test('한 번도 안 틀린 카드는 노트에 없다', () {
    final note = buildWrongNote([_a('a', true, 1), _a('a', true, 2)]);
    expect(note, isEmpty);
  });

  test('마지막이 정답이면 복습 완료, 아니면 복습 필요', () {
    final note = buildWrongNote([
      _a('a', false, 1),
      _a('a', true, 3),
      _a('b', true, 1),
      _a('b', false, 2, AttemptMode.battle),
    ]);
    final a = note.firstWhere((e) => e.cardId == 'a');
    final b = note.firstWhere((e) => e.cardId == 'b');
    expect(a.reviewed, isTrue);
    expect(a.wrongCount, 1);
    expect(b.needsReview, isTrue);
    expect(b.lastMode, AttemptMode.battle);
  });

  test('복습 필요가 먼저, 그다음 최근 순', () {
    final note = buildWrongNote([
      _a('old', false, 1),
      _a('new', false, 5),
      _a('done', false, 2),
      _a('done', true, 9),
    ]);
    expect(note.map((e) => e.cardId), ['new', 'old', 'done']);
  });
}
