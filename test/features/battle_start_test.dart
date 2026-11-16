import 'package:flutter_test/flutter_test.dart';
import 'package:pilgi_card_battle/core/models/room.dart';
import 'package:pilgi_card_battle/features/battle/battle_repository.dart';

Room _room({
  Map<String, RoomPlayer> players = const {},
  RoomStatus status = RoomStatus.waiting,
}) => Room(
  id: 'r',
  code: 'ABC234',
  hostId: 'host',
  subjectId: 's',
  name: '방',
  status: status,
  players: players,
  createdAt: DateTime(2026),
);

const _host = RoomPlayer(nickname: '선우');
const _readyFriend = RoomPlayer(nickname: '승호', ready: true);
const _notReady = RoomPlayer(nickname: '민지');

void main() {
  test('방장 + 준비한 친구 + 문제 있음 → 시작 가능', () {
    final room = _room(players: {'host': _host, 'a': _readyFriend});
    expect(startBlocker(room, 'host', bankCount: 5), isNull);
  });

  test('방장이 아니면 시작 못 함', () {
    final room = _room(players: {'host': _host, 'a': _readyFriend});
    expect(startBlocker(room, 'a', bankCount: 5), isNotNull);
  });

  test('혼자면 시작 못 함', () {
    final room = _room(players: {'host': _host});
    expect(startBlocker(room, 'host', bankCount: 5), contains('친구'));
  });

  test('준비 단계 없음: 대기실에 들어온 친구가 있으면 바로 시작 가능', () {
    final room = _room(players: {'host': _host, 'b': _notReady});
    expect(startBlocker(room, 'host', bankCount: 5), isNull);
  });

  test('문제은행이 비면 시작 못 함', () {
    final room = _room(players: {'host': _host, 'a': _readyFriend});
    expect(startBlocker(room, 'host', bankCount: 0), contains('문제'));
  });

  test('이미 배틀 중이면 시작 못 함', () {
    final room = _room(
      players: {'host': _host, 'a': _readyFriend},
      status: RoomStatus.playing,
    );
    expect(startBlocker(room, 'host', bankCount: 5), isNotNull);
  });

  group('다시 들어올 때 점수 유지', () {
    final scored = {
      'host': _host,
      'a': const RoomPlayer(nickname: '승호', score: 900),
    };

    test('배틀 중에 있던 사람 → 유지', () {
      final room = _room(players: scored, status: RoomStatus.playing);
      expect(keepsPlayerOnEnter(room, 'a'), isTrue);
    });

    test('끝난 판(결과 화면)에 있던 사람 → 유지', () {
      final room = _room(players: scored, status: RoomStatus.finished);
      expect(keepsPlayerOnEnter(room, 'a'), isTrue);
    });

    test('대기실이거나 처음 온 사람 → 새로 넣음', () {
      expect(keepsPlayerOnEnter(_room(players: scored), 'a'), isFalse);
      final playing = _room(players: scored, status: RoomStatus.playing);
      expect(keepsPlayerOnEnter(playing, 'new'), isFalse);
    });
  });
}
