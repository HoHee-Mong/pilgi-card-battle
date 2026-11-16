import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/progress.dart';
import 'package:pilgi_card_battle/features/room/progress_rules.dart';

void main() {
  final day1 = DateTime(2026, 11, 16, 9);
  final day2 = DateTime(2026, 11, 17, 9);
  final day4 = DateTime(2026, 11, 19, 9);

  group('레벨', () {
    test('0 XP는 Lv.1, 100 XP 모으면 Lv.2', () {
      expect(levelOf(0), (1, 0, 100));
      expect(levelOf(100), (2, 0, 150));
      expect(levelOf(130), (2, 30, 150));
    });

    test('칭호와 다음 칭호', () {
      expect(titleOf(1), '예상 새내기');
      expect(titleOf(7), '예상 탐정');
      expect(nextTitle(7), (10, '예상왕'));
      expect(nextTitle(20), isNull);
    });
  });

  group('연속 출석', () {
    test('어제 왔으면 +1, 하루 건너뛰면 1부터, 같은 날은 그대로', () {
      var p = applyCheckIn(const Progress(), day1);
      expect(p.streak, 1);
      p = applyCheckIn(p, day2);
      expect(p.streak, 2);
      expect(applyCheckIn(p, day2).streak, 2);
      expect(applyCheckIn(p, day4).streak, 1);
    });
  });

  group('XP와 퀘스트', () {
    test('투표 5번이면 퀘스트 보상 30 XP 자동 지급', () {
      var p = const Progress();
      var total = 0;
      for (var i = 0; i < 5; i++) {
        final (next, gained) = applyEvent(p, XpEvent.vote, day1);
        p = next;
        total += gained;
      }
      expect(p.votes, 5);
      expect(p.claimed, contains('vote5'));
      expect(total, 5 * XpEvent.vote.xp + 30);
      expect(p.xp, total);
    });

    test('투표 XP는 하루 20번까지만', () {
      var p = const Progress(
        day: '2026-11-16',
        lastActive: '2026-11-16',
        votes: 20,
        claimed: ['vote5'],
      );
      final (next, gained) = applyEvent(p, XpEvent.vote, day1);
      expect(gained, 0);
      expect(next.votes, 21);
    });

    test('날짜가 바뀌면 하루 카운터와 퀘스트가 새로', () {
      final p = const Progress(
        day: '2026-11-16',
        lastActive: '2026-11-16',
        votes: 7,
        claimed: ['vote5'],
      );
      final (next, _) = applyEvent(p, XpEvent.battle, day2, bonusXp: 12);
      expect(next.votes, 0);
      expect(next.battles, 1);
      expect(next.claimed, ['battle1']);
      expect(next.xp, XpEvent.battle.xp + 12 + 40);
    });
  });

  test('결과 랭크 S/A/B/C', () {
    expect(resultRank(95), 'S');
    expect(resultRank(70), 'A');
    expect(resultRank(50), 'B');
    expect(resultRank(10), 'C');
  });
}
