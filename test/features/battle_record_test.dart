import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/battle/battle_record.dart';
import 'package:pilgi_card_battle/features/battle/battle_repository.dart';

Room _room(Map<String, int> scores) => Room(
  id: 'r',
  code: 'ABC234',
  hostId: 'me',
  subjectId: 's',
  name: '네트워크',
  status: RoomStatus.finished,
  players: {
    for (final e in scores.entries)
      e.key: RoomPlayer(nickname: e.key == 'me' ? '선우' : '승호', score: e.value),
  },
  cardIds: const ['c0', 'c1', 'c2'],
  battleId: 'b1',
  createdAt: DateTime(2026),
);

BattleAnswer _a(int round, bool correct) => BattleAnswer(
  uid: 'me',
  round: round,
  choice: 'x',
  correct: correct,
  elapsedMs: 1000,
);

void main() {
  final cards = [
    QuizCard.sample().copyWith(id: 'c0', question: '문제0', answer: '정답0'),
    QuizCard.sample().copyWith(id: 'c1', question: '문제1', answer: '정답1'),
  ];

  BattleRecord build(Map<String, int> scores) => buildBattleRecord(
    room: _room(scores),
    myUid: 'me',
    cards: cards,
    answers: [_a(0, true), _a(1, true), _a(2, false)],
    at: DateTime(2026, 11, 16, 15),
  );

  test('승·패·무와 등수', () {
    expect(build({'me': 1500, 'a': 900}).outcome, BattleOutcome.win);
    expect(build({'me': 900, 'a': 1500}).outcome, BattleOutcome.lose);
    expect(build({'me': 900, 'a': 1500}).rank, 2);
    expect(build({'me': 900, 'a': 900}).outcome, BattleOutcome.draw);
    expect(build({'me': 900}).outcome, BattleOutcome.win); // 상대가 나감
  });

  test('정답 수·정답률·최고 콤보·랭크, 문제 글 같이 저장', () {
    final r = build({'me': 1500, 'a': 900});
    expect(r.id, 'b1');
    expect(r.total, 3);
    expect(r.correct, 2);
    expect(r.percent, 67);
    expect(r.bestCombo, 2);
    expect(r.grade, isNotEmpty);
    expect(r.rounds.first.question, '문제0');
    expect(r.rounds.last.question, ''); // 못 불러온 카드는 빈 글
    expect(r.opponents.single.nickname, '승호');
  });

  test('저장 → 읽기 왕복, 필드가 없는 예전 기록도 열림', () {
    final r = build({'me': 1500, 'a': 900});
    final back = BattleRecord.fromMap('b1', r.toMap());
    expect(back.myScore, 1500);
    expect(back.outcome, BattleOutcome.win);
    expect(back.rounds.length, 3);
    expect(back.xp, isNull);

    final old = BattleRecord.fromMap('x', const {'myScore': 300});
    expect(old.total, 0);
    expect(old.percent, 0);
    expect(old.opponents, isEmpty);
    expect(old.outcome, BattleOutcome.draw);
  });
}
