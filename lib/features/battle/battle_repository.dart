import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/room.dart';
import '../../core/models/card.dart';
import '../bank/bank_repository.dart';
import 'battle_rules.dart';

final battleRepositoryProvider = Provider<BattleRepository>(
  (ref) => BattleRepository(FirebaseFirestore.instance),
);

/// 배틀 문항 수 선택지 (DATA.md: 5 | 10)
const kBattleQuestionCounts = [5, 10];

/// 배틀 최소 인원
const kBattleMinPlayers = 2;

/// `rooms/{roomId}/answers/{round_uid}` — 한 사람의 한 라운드 답.
class BattleAnswer {
  const BattleAnswer({
    required this.uid,
    required this.round,
    required this.choice,
    required this.correct,
    required this.elapsedMs,
  });

  final String uid;
  final int round;

  /// 고른 답. 시간 초과면 빈 문자열.
  final String choice;
  final bool correct;
  final int elapsedMs;

  factory BattleAnswer.fromMap(Map<String, dynamic> map) => BattleAnswer(
    uid: map['uid'] as String? ?? '',
    round: (map['round'] as num?)?.toInt() ?? 0,
    choice: map['choice'] as String? ?? '',
    correct: map['correct'] as bool? ?? false,
    elapsedMs: (map['elapsedMs'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'round': round,
    'choice': choice,
    'correct': correct,
    'elapsedMs': elapsedMs,
  };
}

/// 배틀 관련 실패. [message]는 화면에 그대로 보여 줄 수 있는 문구.
class BattleException implements Exception {
  const BattleException(this.message);
  final String message;

  @override
  String toString() => 'BattleException: $message';
}

/// 방장이 지금 시작할 수 있는지. 시작할 수 있으면 null, 아니면 이유 문구.
///
/// [bankCount]는 지금 범위에서 뽑을 수 있는 문제 수.
String? startBlocker(Room room, String uid, {required int bankCount}) {
  if (!room.isHost(uid)) return '방장만 시작할 수 있어요';
  if (room.status != RoomStatus.waiting) return '이미 배틀 중이에요';
  if (room.players.length < kBattleMinPlayers) return '친구가 들어오면 시작할 수 있어요';
  final notReady = [
    for (final e in room.players.entries)
      if (e.key != room.hostId && !e.value.ready) e.value.nickname,
  ];
  if (notReady.isNotEmpty) return '${notReady.join(', ')} 님이 아직 준비 중이에요';
  if (bankCount == 0) return '이 범위에 문제은행 문제가 없어요';
  return null;
}

/// 대기실·배틀 진행 (`rooms/{roomId}`의 status·players·cardIds·round).
///
/// `players`는 지금 대기실·배틀에 있는 사람, `memberIds`는 들어온 적 있는 사람이다.
class BattleRepository {
  BattleRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _room(String roomId) =>
      _db.collection('rooms').doc(roomId);

  /// 대기실 입장: 나를 players에 넣는다 (준비 안 됨, 점수 0).
  /// 이미 배틀 중이면 점수를 지우지 않고 닉네임만 갱신한다.
  Future<void> enter({
    required String roomId,
    required String uid,
    required String nickname,
  }) {
    final room = _room(roomId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(room);
      final data = snap.data();
      if (data == null) throw const BattleException('방이 없어졌어요.');
      final current = Room.fromMap(snap.id, data);
      final me = current.players[uid];
      if (current.status == RoomStatus.playing && me != null) {
        tx.update(room, {'players.$uid.nickname': nickname});
        return;
      }
      tx.update(room, {
        'players.$uid': RoomPlayer(nickname: nickname).toMap(),
        'memberIds': FieldValue.arrayUnion([uid]),
      });
    });
  }

  /// 대기실에서 나가기: players에서 뺀다. 방장이 나가면 남은 사람에게 방장을 넘긴다.
  Future<void> leave({required String roomId, required String uid}) {
    final room = _room(roomId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(room);
      final data = snap.data();
      if (data == null) return;
      final current = Room.fromMap(snap.id, data);
      final update = <String, Object?>{'players.$uid': FieldValue.delete()};
      if (current.isHost(uid)) {
        final next = current.players.keys.where((k) => k != uid).firstOrNull;
        if (next != null) update['hostId'] = next;
      }
      tx.update(room, update);
    });
  }

  Future<void> setReady({
    required String roomId,
    required String uid,
    required bool ready,
  }) {
    return _room(roomId).update({'players.$uid.ready': ready});
  }

  /// 방장: 문항 수·범위(주차) 바꾸기. [weeks]가 비면 전체.
  Future<void> setSettings({
    required String roomId,
    int? questionCount,
    List<int>? weeks,
  }) {
    return _room(roomId).update({
      'questionCount': ?questionCount,
      if (weeks != null) 'weeks': ([...weeks]..sort()),
    });
  }

  /// 방장: 배틀 시작. 문제은행에서 투표 많은 순으로 [Room.questionCount]개를 뽑아
  /// `cardIds`에 넣고 status를 playing, round 0으로 바꾼다. 점수·콤보는 0으로.
  Future<void> start({
    required String roomId,
    required String uid,
    required BankRepository bank,
  }) async {
    final roomRef = _room(roomId);
    final before = await roomRef.get();
    final data = before.data();
    if (data == null) throw const BattleException('방이 없어졌어요.');
    final room = Room.fromMap(before.id, data);
    final picked = await bank.topVoted(
      roomId,
      weeks: room.weeks,
      limit: room.questionCount,
    );
    final blocker = startBlocker(room, uid, bankCount: picked.length);
    if (blocker != null) throw BattleException(blocker);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(roomRef);
      final now = Room.fromMap(snap.id, snap.data() ?? const {});
      // 가져온 사이에 누가 나가거나 준비를 풀었으면 다시 확인한다.
      final again = startBlocker(now, uid, bankCount: picked.length);
      if (again != null) throw BattleException(again);
      tx.update(roomRef, {
        'status': RoomStatus.playing.name,
        'cardIds': [for (final e in picked) e.cardId],
        'round': 0,
        'roundStartedAt': FieldValue.serverTimestamp(),
        for (final p in now.players.keys) ...{
          'players.$p.score': 0,
          'players.$p.combo': 0,
        },
      });
    });
  }

  CollectionReference<Map<String, dynamic>> _answers(String roomId) =>
      _room(roomId).collection('answers');

  /// 이번 라운드에 들어온 답들 (실시간)
  Stream<List<BattleAnswer>> watchAnswers(String roomId, int round) {
    return _answers(roomId)
        .where('round', isEqualTo: round)
        .snapshots()
        .map(
          (snap) => [for (final d in snap.docs) BattleAnswer.fromMap(d.data())],
        );
  }

  /// 내 답 제출 + 점수·콤보 반영. 같은 라운드에 두 번 내면 처음 것만 남는다.
  /// 반환값: 맞았는지.
  Future<bool> submit({
    required String roomId,
    required String uid,
    required int round,
    required QuizCard card,
    required String choice,
    required int elapsedMs,
  }) {
    final roomRef = _room(roomId);
    final answerRef = _answers(roomId).doc('${round}_$uid');
    final correct = BattleRules.isCorrect(card, choice);
    return _db.runTransaction((tx) async {
      final existing = await tx.get(answerRef);
      if (existing.exists) {
        return BattleAnswer.fromMap(existing.data()!).correct;
      }
      final snap = await tx.get(roomRef);
      final room = Room.fromMap(snap.id, snap.data() ?? const {});
      if (room.round != round) return false; // 이미 다음 문제로 넘어감
      final me = room.players[uid];
      final (gained, combo) = BattleRules.apply(
        correct: correct,
        elapsedMs: elapsedMs,
        prevCombo: me?.combo ?? 0,
      );
      tx.set(
        answerRef,
        BattleAnswer(
          uid: uid,
          round: round,
          choice: choice,
          correct: correct,
          elapsedMs: elapsedMs,
        ).toMap(),
      );
      if (me != null) {
        tx.update(roomRef, {
          'players.$uid.score': me.score + gained,
          'players.$uid.combo': combo,
        });
      }
      return correct;
    });
  }

  /// 방장: 다음 문제로. 마지막 문제였으면 끝(finished).
  /// [fromRound]가 지금 라운드와 다르면(이미 넘어갔으면) 아무것도 안 한다.
  Future<void> advance({required String roomId, required int fromRound}) {
    final roomRef = _room(roomId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(roomRef);
      final data = snap.data();
      if (data == null) return;
      final room = Room.fromMap(snap.id, data);
      if (room.status != RoomStatus.playing || room.round != fromRound) return;
      if (fromRound + 1 >= room.cardIds.length) {
        tx.update(roomRef, {'status': RoomStatus.finished.name});
      } else {
        tx.update(roomRef, {
          'round': fromRound + 1,
          'roundStartedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// 방장: 대기실로 되돌리기 (배틀 끝난 뒤 한 판 더, 또는 중단).
  /// 준비 상태를 모두 풀고 출제 목록을 비운다.
  Future<void> backToWaiting({required String roomId}) {
    final roomRef = _room(roomId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(roomRef);
      final data = snap.data();
      if (data == null) return;
      final room = Room.fromMap(snap.id, data);
      tx.update(roomRef, {
        'status': RoomStatus.waiting.name,
        'cardIds': <String>[],
        'round': 0,
        'roundStartedAt': null,
        for (final p in room.players.keys) 'players.$p.ready': false,
      });
    });
  }
}
