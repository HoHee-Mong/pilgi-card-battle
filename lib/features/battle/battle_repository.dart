import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/room.dart';
import '../../core/models/attempt.dart';
import '../../core/models/card.dart';
import '../bank/bank_repository.dart';
import 'battle_record.dart';
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
    this.saved = false,
  });

  final String uid;
  final int round;

  /// 고른 답. 시간 초과면 빈 문자열.
  final String choice;
  final bool correct;
  final int elapsedMs;

  /// 오답 노트(attempts)에 이미 저장했는지. 끝난 방에 다시 들어와도 두 번 저장하지 않게.
  final bool saved;

  factory BattleAnswer.fromMap(Map<String, dynamic> map) => BattleAnswer(
    uid: map['uid'] as String? ?? '',
    round: (map['round'] as num?)?.toInt() ?? 0,
    choice: map['choice'] as String? ?? '',
    correct: map['correct'] as bool? ?? false,
    elapsedMs: (map['elapsedMs'] as num?)?.toInt() ?? 0,
    saved: map['saved'] as bool? ?? false,
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
/// 대기실에 들어온 사람은 바로 참가한다 (따로 "준비" 단계 없음).
///
/// [bankCount]는 지금 범위에서 뽑을 수 있는 문제 수.
String? startBlocker(Room room, String uid, {required int bankCount}) {
  if (!room.isHost(uid)) return '방장만 시작할 수 있어요';
  if (room.status != RoomStatus.waiting) return '이미 배틀 중이에요';
  if (room.players.length < kBattleMinPlayers) {
    return '친구가 이 화면에 들어오면 시작할 수 있어요';
  }
  if (bankCount == 0) return '이 범위에 문제은행 문제가 없어요';
  return null;
}

/// 다시 들어올 때 점수를 그대로 둘지. 배틀 중이거나 끝난 뒤(결과 화면)에 이미 있던
/// 사람은 점수·콤보를 지우지 않는다 (지우면 다른 사람 화면의 순위까지 바뀐다).
bool keepsPlayerOnEnter(Room room, String uid) =>
    room.status != RoomStatus.waiting && room.players.containsKey(uid);

/// 재대결을 시작할 수 있는지: 끝난 판이고, 대기실(결과 화면)에 2명 이상 있고, 모두 "다시 대결하기"를 눌렀다.
bool rematchReady(Room room) =>
    room.status == RoomStatus.finished &&
    room.players.length >= kBattleMinPlayers &&
    room.players.keys.every(room.rematchVotes.contains);

/// 재대결 화면 상태 (결과 화면 아래 영역)
enum RematchState {
  /// 아무도 안 누름
  none,

  /// 내가 눌렀고 상대를 기다림
  waiting,

  /// 상대가 눌렀고 내 대답을 기다림
  invited,

  /// 모두 눌러서 곧 시작
  starting,

  /// 상대가 나가서 할 수 없음
  alone,
}

RematchState rematchStateFor(Room room, String uid) {
  if (room.players.length < kBattleMinPlayers) return RematchState.alone;
  if (rematchReady(room)) return RematchState.starting;
  final mine = room.rematchVotes.contains(uid);
  final others = room.rematchVotes.any(
    (v) => v != uid && room.players.containsKey(v),
  );
  if (mine) return RematchState.waiting;
  return others ? RematchState.invited : RematchState.none;
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
  /// 이미 배틀 중이거나 끝난 판에 있던 사람이면 점수를 지우지 않고 닉네임만 갱신한다.
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
      if (keepsPlayerOnEnter(current, uid)) {
        tx.update(room, {
          'players.$uid.nickname': nickname,
          'memberNames.$uid': nickname,
        });
        return;
      }
      tx.update(room, {
        'players.$uid': RoomPlayer(nickname: nickname).toMap(),
        'memberIds': FieldValue.arrayUnion([uid]),
        'memberNames.$uid': nickname,
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
  }) => _begin(roomId: roomId, uid: uid, bank: bank, rematch: false);

  /// 재대결 시작: 모두 "다시 대결하기"를 눌렀을 때 방장 기기가 부른다.
  /// 같은 설정(문항 수·범위)으로 새 판. 이미 시작됐으면 아무것도 안 한다.
  Future<void> startRematch({
    required String roomId,
    required String uid,
    required BankRepository bank,
  }) => _begin(roomId: roomId, uid: uid, bank: bank, rematch: true);

  /// 끝난 판에서 "다시 대결하기" (여러 번 눌러도 한 번)
  Future<void> requestRematch({required String roomId, required String uid}) {
    return _room(roomId).update({
      'rematchVotes': FieldValue.arrayUnion([uid]),
    });
  }

  /// 재대결 요청 취소
  Future<void> cancelRematch({required String roomId, required String uid}) {
    return _room(roomId).update({
      'rematchVotes': FieldValue.arrayRemove([uid]),
    });
  }

  static String? _rematchBlocker(Room room, String uid, int bankCount) {
    if (room.status != RoomStatus.finished) return '이미 새 판이 시작됐어요';
    if (!room.isHost(uid)) return '방장 기기가 시작해요';
    if (!rematchReady(room)) return '아직 모두 수락하지 않았어요';
    if (bankCount == 0) return '이 범위에 문제은행 문제가 없어요';
    return null;
  }

  Future<void> _begin({
    required String roomId,
    required String uid,
    required BankRepository bank,
    required bool rematch,
  }) async {
    final roomRef = _room(roomId);
    final before = await roomRef.get();
    final data = before.data();
    if (data == null) throw const BattleException('방이 없어졌어요.');
    final room = Room.fromMap(before.id, data);
    String? check(Room r, int count) => rematch
        ? _rematchBlocker(r, uid, count)
        : startBlocker(r, uid, bankCount: count);
    if (rematch && room.status != RoomStatus.finished) return; // 이미 시작됨
    final picked = await bank.topVoted(
      roomId,
      weeks: room.weeks,
      limit: room.questionCount,
    );
    final blocker = check(room, picked.length);
    if (blocker != null) throw BattleException(blocker);
    // 지난 판 답이 남아 있으면 같은 문서 id(round_uid)라 새 답이 막힌다 → 먼저 비운다.
    await _clearAnswers(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(roomRef);
      final now = Room.fromMap(snap.id, snap.data() ?? const {});
      // 가져온 사이에 누가 나가거나 준비를 풀었으면 다시 확인한다.
      final again = check(now, picked.length);
      if (again != null) throw BattleException(again);
      tx.update(roomRef, {
        'status': RoomStatus.playing.name,
        'cardIds': [for (final e in picked) e.cardId],
        'round': 0,
        'roundStartedAt': FieldValue.serverTimestamp(),
        // 판마다 새 ID (배틀 기록은 이 ID로 한 번만 저장된다)
        'battleId': roomRef.collection('answers').doc().id,
        'rematchVotes': <String>[],
        for (final p in now.players.keys) 'players.$p.ready': false,
        for (final p in now.players.keys) ...{
          'players.$p.score': 0,
          'players.$p.combo': 0,
        },
      });
    });
  }

  CollectionReference<Map<String, dynamic>> _answers(String roomId) =>
      _room(roomId).collection('answers');

  Future<void> _clearAnswers(String roomId) async {
    final old = await _answers(roomId).get();
    // 배치 한 번에 최대 500개
    for (var i = 0; i < old.docs.length; i += 450) {
      final batch = _db.batch();
      for (final d in old.docs.skip(i).take(450)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  /// 이번 판에서 내가 낸 답 전부 (결과 화면용)
  Stream<List<BattleAnswer>> watchMyAnswers(String roomId, String uid) {
    return _answers(roomId)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map(
          (snap) =>
              [for (final d in snap.docs) BattleAnswer.fromMap(d.data())]
                ..sort((a, b) => a.round.compareTo(b.round)),
        );
  }

  /// 배틀 결과를 `users/{uid}/attempts`에 `mode: battle`로 저장 → A의 오답 노트에 반영.
  /// 시간 초과(빈 답)도 틀린 것으로 저장한다.
  /// 이미 저장한 답은 건너뛰고, 저장한 답에는 `saved: true`를 남긴다 (같은 배치라 함께 성공·실패).
  /// 반환값: 이번에 새로 저장한 게 있는지 (없으면 XP도 다시 주지 않는다).
  ///
  /// [record]가 있으면 같은 배치로 `users/{uid}/battles/{battleId}`에 배틀 기록도 남긴다
  /// (battleId가 같으면 같은 문서라 두 번 저장돼도 한 개).
  Future<bool> saveAttempts({
    required String roomId,
    required String uid,
    required List<QuizCard> cards,
    required List<BattleAnswer> answers,
    required List<String> cardIds,
    BattleRecord? record,
  }) async {
    final byId = {for (final c in cards) c.id: c};
    final batch = _db.batch();
    final col = _db.collection('users').doc(uid).collection('attempts');
    final now = DateTime.now();
    var any = false;
    for (final a in answers) {
      if (a.saved || a.round >= cardIds.length) continue;
      final card = byId[cardIds[a.round]];
      if (card == null) continue;
      batch.set(
        col.doc(),
        Attempt(
          id: '',
          cardId: card.id,
          subjectId: card.subjectId,
          concept: card.concept,
          correct: a.correct,
          mode: AttemptMode.battle,
          at: now,
        ).toMap(),
      );
      batch.update(_answers(roomId).doc('${a.round}_$uid'), {'saved': true});
      any = true;
    }
    if (!any) return false;
    if (record != null) {
      batch.set(_records(uid).doc(_recordId(record)), record.toMap());
    }
    await batch.commit();
    return true;
  }

  CollectionReference<Map<String, dynamic>> _records(String uid) =>
      _db.collection('users').doc(uid).collection('battles');

  /// 예전 방(battleId 없음)은 방 ID + 시각으로 만든다
  static String _recordId(BattleRecord r) =>
      r.id.isNotEmpty ? r.id : '${r.roomId}_${r.at.millisecondsSinceEpoch}';

  /// 배틀 기록에 받은 XP 채우기
  Future<void> setRecordXp(String uid, BattleRecord record, int xp) {
    return _records(uid).doc(_recordId(record)).update({'xp': xp});
  }

  /// 내 배틀 기록 (최근 순, [limit]개). 읽기만 한다.
  Stream<List<BattleRecord>> watchRecords(String uid, {int limit = 50}) {
    return _records(uid)
        .orderBy('at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => [
            for (final d in snap.docs) BattleRecord.fromMap(d.id, d.data()),
          ],
        );
  }

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
        'rematchVotes': <String>[],
        for (final p in room.players.keys) 'players.$p.ready': false,
      });
    });
  }
}
