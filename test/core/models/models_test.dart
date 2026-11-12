import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/attempt.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/core/models/mock_exam.dart';
import 'package:pilgi_card_battle/core/models/subject.dart';

void main() {
  test('QuizCard toMap → fromMap 왕복', () {
    for (var i = 0; i < 3; i++) {
      final card = QuizCard.sample(i);
      final back = QuizCard.fromMap(card.id, card.toMap());
      expect(back.toMap(), card.toMap());
    }
    expect(QuizCard.sample(1).type, CardType.ox);
    expect(QuizCard.sample(2).type, CardType.short);
  });

  test('QuizCard 빈 문서는 draft·private 기본값', () {
    final card = QuizCard.fromMap('x', {});
    expect(card.status, CardStatus.draft);
    expect(card.visibility, CardVisibility.private);
    expect(card.choices, isEmpty);
  });

  test('Subject / Attempt / MockExam 왕복', () {
    final t = DateTime(2026, 11, 12, 10);
    final s = Subject(id: 's', ownerId: 'u', name: '네트워크', createdAt: t);
    expect(Subject.fromMap('s', s.toMap()).toMap(), s.toMap());

    final a = Attempt(
      id: 'a',
      cardId: 'c',
      subjectId: 's',
      concept: 'ARP',
      correct: true,
      mode: AttemptMode.battle,
      at: t,
    );
    final a2 = Attempt.fromMap('a', a.toMap());
    expect(a2.mode, AttemptMode.battle);
    expect(a2.toMap(), a.toMap());

    final m = MockExam(
      id: 'm',
      uid: 'u',
      nickname: '승호',
      cardIds: ['c1', 'c2'],
      weeks: [3, 4],
      timeLimitSec: 600,
      total: 2,
      startedAt: t,
    );
    final m2 = MockExam.fromMap('m', m.toMap());
    expect(m2.isSubmitted, isFalse);
    expect(m2.toMap(), m.toMap());
  });
}
