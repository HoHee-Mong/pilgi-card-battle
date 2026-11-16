import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/room/lobby_screen.dart';

void main() {
  final base = {
    'code': 'ABC234',
    'hostId': 'h',
    'players': {
      'h': {'nickname': '선우'},
    },
    'memberIds': ['h', 'a'],
  };

  test('대기실을 나간 사람도 memberNames로 이름을 찾는다', () {
    final room = Room.fromMap('r', {
      ...base,
      'memberNames': {'h': '선우', 'a': '승호'},
    });
    expect(room.nicknameOf('h'), '선우');
    expect(room.nicknameOf('a'), '승호');
    expect(room.nicknameOf('없음'), '');
  });

  test('memberNames가 없는 예전 방도 그대로 읽힌다', () {
    final room = Room.fromMap('r', base);
    expect(room.memberNames, isEmpty);
    expect(room.nicknameOf('h'), '선우');
    expect(room.nicknameOf('a'), '');
  });

  test('toMap → fromMap 왕복', () {
    final room = Room.sample();
    final again = Room.fromMap(room.id, room.toMap());
    expect(again.memberNames, room.memberNames);
  });

  test('로비 친구 목록: 대기실 밖 멤버도 나오고, 이름 모르면 "친구"', () {
    final room = Room.fromMap('r', {
      ...base,
      'memberIds': ['h', 'a', 'b'],
      'memberNames': {'a': '승호'},
    });
    expect(memberNamesOf(room), ['선우', '승호', '친구']);
  });
}
