import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/card.dart';
import 'package:pilgi_card_battle/core/models/room.dart';

void main() {
  test('Room toMap → fromMap 왕복', () {
    final room = Room.sample();
    final back = Room.fromMap(room.id, room.toMap());
    expect(back.toMap(), room.toMap());
    expect(back.players['sample-user']?.ready, isTrue);
    expect(back.nicknameOf('sample-user-2'), '선우');
    expect(back.isMember('sample-user-2'), isTrue);
    expect(back.isHost('sample-user'), isTrue);
  });

  test('Room 빈 문서는 기본값', () {
    final room = Room.fromMap('r', {});
    expect(room.status, RoomStatus.waiting);
    expect(room.questionCount, 5);
    expect(room.players, isEmpty);
    expect(room.roundStartedAt, isNull);
  });

  test('BankEntry 왕복, 문서 ID로 cardId 보정, QuizCard.sample과 id 일치', () {
    for (var i = 0; i < 3; i++) {
      final e = BankEntry.sample(i);
      expect(BankEntry.fromMap(e.cardId, e.toMap()).toMap(), e.toMap());
      expect(e.cardId, QuizCard.sample(i).id);
      expect(e.voteCount, e.voters.length);
    }
    expect(BankEntry.fromMap('c9', {}).cardId, 'c9');
    expect(BankEntry.sample(0).votedBy('u3'), isTrue);
  });
}
