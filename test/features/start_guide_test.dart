import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/bank/upload_cards_sheet.dart';
import 'package:pilgi_card_battle/features/room/lobby_screen.dart';

Room _room(List<String> members) => Room(
  id: 'r',
  code: 'ABC234',
  hostId: 'h',
  subjectId: 's',
  name: '방',
  memberIds: members,
  createdAt: DateTime(2026),
);

void main() {
  group('로비 시작 안내', () {
    test('방이 없으면 3단계 다 남음', () {
      final steps = startSteps(room: null, bankCount: 0);
      expect(steps.where((s) => !s.done).length, 3);
    });

    test('방·문제는 있고 친구만 없으면 3번만 남음', () {
      final steps = startSteps(room: _room(['h']), bankCount: 4);
      expect([for (final s in steps) s.done], [true, true, false]);
    });

    test('다 했으면 안내가 사라짐', () {
      expect(startSteps(room: _room(['h', 'a']), bankCount: 4), isEmpty);
    });
  });

  test('한꺼번에 올리기: 검수 완료 + 아직 안 올린 카드만', () {
    final verified = QuizCard.sample().copyWith(status: CardStatus.verified);
    final draft = QuizCard.sample(1).copyWith(status: CardStatus.draft);
    final shared = QuizCard.sample(2).copyWith(status: CardStatus.verified);
    final picked = cardsToUpload([verified, draft, shared], {shared.id});
    expect([for (final c in picked) c.id], [verified.id]);
  });
}
