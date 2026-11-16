import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/mock_exam.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/room/room_stats.dart';

BankEntry _e(String by, String name, int votes) => BankEntry(
  cardId: '$by-$votes',
  addedBy: by,
  addedByNickname: name,
  week: 1,
  voteCount: votes,
  addedAt: DateTime(2026),
);

MockExam _m(String uid, int score, int total, {bool submitted = true}) =>
    MockExam(
      id: '$uid-$score',
      uid: uid,
      nickname: uid,
      cardIds: const [],
      weeks: const [],
      timeLimitSec: 600,
      score: score,
      total: total,
      startedAt: DateTime(2026),
      submittedAt: submitted ? DateTime(2026) : null,
    );

void main() {
  test('예상 적중왕: 받은 표 합계 많은 순', () {
    final list = rankContributors([
      _e('a', '선우', 3),
      _e('b', '승호', 5),
      _e('a', '선우', 4),
    ]);
    expect(list.first.nickname, '선우');
    expect(list.first.votes, 7);
    expect(list.first.cards, 2);
    expect(list[1].votes, 5);
  });

  test('모의고사: 제출한 것만, 사람별 최고 비율', () {
    final list = rankMockExams([
      _m('a', 6, 10),
      _m('a', 18, 20),
      _m('b', 8, 10),
      _m('c', 10, 10, submitted: false),
    ]);
    expect(list.map((m) => m.uid), ['a', 'b']);
    expect(list.first.percent, 90);
    expect(list.first.tries, 2);
  });
}
