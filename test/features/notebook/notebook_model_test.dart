import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/notebook/notebook_model.dart';

void main() {
  group('filterByStatus', () {
    final cards = [
      QuizCard.sample(0), // verified
      QuizCard.sample(1).copyWith(status: CardStatus.draft),
      QuizCard.sample(2),
    ];

    test('전체 / 검수 완료 / 초안', () {
      expect(filterByStatus(cards, NotebookStatus.all), hasLength(3));
      expect(filterByStatus(cards, NotebookStatus.verified), hasLength(2));
      expect(filterByStatus(cards, NotebookStatus.draft), hasLength(1));
    });
  });

  group('groupByWeek', () {
    test('주차 오름차순, 같은 주차는 입력 순서', () {
      final cards = [
        QuizCard.sample().copyWith(id: 'a', week: 4),
        QuizCard.sample().copyWith(id: 'b', week: 2),
        QuizCard.sample().copyWith(id: 'c', week: 4),
      ];
      final g = groupByWeek(cards, (c) => c.week);
      expect(g.keys.toList(), [2, 4]);
      expect(g[4]!.map((c) => c.id), ['a', 'c']);
    });

    test('비어 있으면 빈 맵', () {
      expect(groupByWeek(<QuizCard>[], (c) => c.week), isEmpty);
    });
  });

  group('pickBestEntries', () {
    final room1 = Room(
      id: 'r1',
      code: '111111',
      hostId: 'h',
      subjectId: 's',
      name: '방1',
      createdAt: DateTime(2026, 11, 1),
    );
    final room2 = Room(
      id: 'r2',
      code: '222222',
      hostId: 'h',
      subjectId: 's',
      name: '방2',
      createdAt: DateTime(2026, 11, 1),
    );

    BankEntry entry(String cardId, int votes) => BankEntry(
      cardId: cardId,
      addedBy: 'u',
      addedByNickname: '승호',
      week: 3,
      voteCount: votes,
      addedAt: DateTime(2026, 11, 2),
    );

    test('같은 카드는 투표 많은 방의 항목만 남긴다', () {
      final best = pickBestEntries([
        (entry: entry('c1', 2), room: room1),
        (entry: entry('c1', 5), room: room2),
        (entry: entry('c2', 0), room: room1),
      ]);
      expect(best.keys, containsAll(['c1', 'c2']));
      expect(best['c1']!.room.id, 'r2');
      expect(best['c1']!.entry.voteCount, 5);
    });
  });
}
