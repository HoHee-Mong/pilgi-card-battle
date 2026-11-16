import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/battle/battle_repository.dart';

Room _room({
  RoomStatus status = RoomStatus.finished,
  List<String> players = const ['h', 'a'],
  List<String> votes = const [],
}) => Room(
  id: 'r',
  code: 'ABC234',
  hostId: 'h',
  subjectId: 's',
  name: '방',
  status: status,
  players: {for (final p in players) p: RoomPlayer(nickname: p)},
  rematchVotes: votes,
  createdAt: DateTime(2026),
);

void main() {
  test('아무도 안 누름 → none', () {
    expect(rematchStateFor(_room(), 'h'), RematchState.none);
    expect(rematchReady(_room()), isFalse);
  });

  test('한 명만 요청: 요청한 쪽은 기다림, 상대는 초대받음', () {
    final room = _room(votes: ['h']);
    expect(rematchStateFor(room, 'h'), RematchState.waiting);
    expect(rematchStateFor(room, 'a'), RematchState.invited);
    expect(rematchReady(room), isFalse);
  });

  test('둘 다 요청(동시에 눌러도) → 시작', () {
    final room = _room(votes: ['a', 'h']);
    expect(rematchReady(room), isTrue);
    expect(rematchStateFor(room, 'a'), RematchState.starting);
  });

  test('상대가 나가면 → alone, 시작 안 함 (남은 표가 있어도)', () {
    final room = _room(players: ['h'], votes: ['h', 'a']);
    expect(rematchStateFor(room, 'h'), RematchState.alone);
    expect(rematchReady(room), isFalse);
  });

  test('나간 사람의 표만 있으면 초대로 보지 않음', () {
    final room = _room(votes: ['gone']);
    expect(rematchStateFor(room, 'h'), RematchState.none);
  });

  test('끝난 판이 아니면 시작 안 함 (이미 새 판)', () {
    final room = _room(status: RoomStatus.playing, votes: ['a', 'h']);
    expect(rematchReady(room), isFalse);
  });
}
