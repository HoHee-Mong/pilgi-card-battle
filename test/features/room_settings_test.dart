import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/room/room_repository.dart';
import 'package:pilgi_card_battle/features/room/room_sheets.dart';

void main() {
  test('방 이름: 빈칸·20글자 초과는 안 됨', () {
    expect(RoomRepository.nameProblem('  '), isNotNull);
    expect(RoomRepository.nameProblem('가' * 21), isNotNull);
    expect(RoomRepository.nameProblem(' 네트워크 스터디 '), isNull);
  });

  test('멤버 목록: 방장 먼저, 이름 모르면 친구, 나 표시', () {
    final room = Room(
      id: 'r',
      code: 'ABC234',
      hostId: 'h',
      subjectId: 's',
      name: '방',
      memberIds: const ['a', 'h', 'b'],
      memberNames: const {'a': '승호', 'h': '선우'},
      createdAt: DateTime(2026),
    );
    final members = roomMembers(room, 'a');
    expect([for (final m in members) m.name], ['선우', '승호', '친구']);
    expect(members.first.isHost, isTrue);
    expect(members[1].isMe, isTrue);
  });
}
