import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/room/room_repository.dart';

Room _room({
  String host = 'h',
  List<String> members = const ['h', 'a', 'b'],
  Map<String, RoomPlayer> players = const {},
}) => Room(
  id: 'r',
  code: 'ABC234',
  hostId: host,
  subjectId: 's',
  name: '방',
  memberIds: members,
  players: players,
  createdAt: DateTime(2026),
);

void main() {
  test('멤버가 나가면 방장은 그대로', () {
    expect(RoomRepository.nextHostAfter(_room(), 'a'), 'h');
  });

  test('방장이 나가면 대기실에 있는 사람에게 먼저 넘긴다', () {
    final room = _room(players: {'b': const RoomPlayer(nickname: '민지')});
    expect(RoomRepository.nextHostAfter(room, 'h'), 'b');
  });

  test('대기실에 아무도 없으면 먼저 들어온 멤버에게', () {
    expect(RoomRepository.nextHostAfter(_room(), 'h'), 'a');
  });

  test('마지막 한 명이 나가면 null (방을 지운다)', () {
    expect(RoomRepository.nextHostAfter(_room(members: ['h']), 'h'), isNull);
  });
}
