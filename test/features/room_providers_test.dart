import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/room/room_providers.dart';

Room _room(String id) => Room(
  id: id,
  code: 'ABC234',
  hostId: 'h',
  subjectId: 's',
  name: id,
  createdAt: DateTime(2026),
);

void main() {
  final rooms = [_room('최근'), _room('예전')];

  test('고른 방이 없으면 가장 최근 방', () {
    expect(pickCurrentRoom(rooms, null)?.id, '최근');
  });

  test('고른 방이 목록에 있으면 그 방', () {
    expect(pickCurrentRoom(rooms, '예전')?.id, '예전');
  });

  test('고른 방이 목록에서 사라졌으면 가장 최근 방', () {
    expect(pickCurrentRoom(rooms, '없는방')?.id, '최근');
  });

  test('방이 없으면 null', () {
    expect(pickCurrentRoom(const [], '예전'), isNull);
  });
}
