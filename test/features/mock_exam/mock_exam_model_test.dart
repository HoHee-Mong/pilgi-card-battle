import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/mock_exam/mock_exam_model.dart';

BankEntry entry(String id, int week) => BankEntry(
  cardId: id,
  addedBy: 'u',
  addedByNickname: '친구',
  week: week,
  addedAt: DateTime(2026, 11, 1),
);

void main() {
  final mcq = QuizCard.sample(0); // 정답 SYN+ACK
  final short = QuizCard.sample(0).copyWith(
    id: 'short',
    type: CardType.short,
    choices: const [],
    answer: 'Three Way',
  );
  final ox = QuizCard.sample(0)
      .copyWith(id: 'ox', type: CardType.ox, choices: const [], answer: 'O');

  group('gradeMock', () {
    test('맞힌 답, 틀린 답, 안 푼 문제를 채점한다', () {
      final marks = gradeMock(
        [mcq, short, ox],
        {mcq.id: 'SYN+ACK', short.id: 'three  way', ox.id: '   '},
      );
      expect([for (final m in marks) m.correct], [true, true, false]);
      expect(marks[2].answer, isNull); // 빈 답 = 안 풂
    });

    test('답이 없으면 전부 오답', () {
      final marks = gradeMock([mcq, ox], const {});
      expect(marks.where((m) => m.correct), isEmpty);
      expect(marks.map((m) => m.card.id), [mcq.id, ox.id]);
    });

    test('객관식 오답', () {
      expect(gradeMock([mcq], {mcq.id: 'ACK'}).single.correct, isFalse);
    });
  });

  test('남은 보스 체력 = 안 푼 문제 수 (공백 답은 안 푼 것)', () {
    expect(unansweredCount([mcq, short, ox], {mcq.id: 'ACK', ox.id: ' '}), 2);
  });

  test('주차 목록과 범위 안 문제 수', () {
    final list = [entry('a', 3), entry('b', 1), entry('c', 3)];
    expect(bankWeeks(list), [1, 3]);
    expect(countInWeeks(list, {}), 3);
    expect(countInWeeks(list, {3}), 2);
    expect(countInWeeks(list, {2}), 0);
  });

  test('제한 시간은 문항당 1분', () {
    expect(mockTimeLimitSec(20), 1200);
  });

  test('formatClock', () {
    expect(formatClock(1122), '18:42');
    expect(formatClock(5), '00:05');
    expect(formatClock(-3), '00:00');
    expect(formatClock(3900), '1:05:00');
  });

  test('결과 제목', () {
    expect(mockResultTitle(10, 10), '완벽 격파!');
    expect(mockResultTitle(5, 10), '보스 격파!');
    expect(mockResultTitle(4, 10), '보스가 버텼어요');
    expect(mockResultTitle(0, 0), '보스가 버텼어요');
  });

  test('채점 연출 한 칸 시간은 150~450ms', () {
    expect(gradingStep(10).inMilliseconds, 400);
    expect(gradingStep(5).inMilliseconds, 450);
    expect(gradingStep(30).inMilliseconds, 150);
    expect(gradingStep(0), Duration.zero);
  });

  test('shortLabel', () {
    expect(shortLabel('벼락치기방', 10), '벼락치기방');
    expect(shortLabel('영상처리영상처리 벼락치기방', 10), '영상처리영상처리 벼…');
  });
}
