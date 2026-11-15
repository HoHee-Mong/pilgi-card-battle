import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/room.dart';

final roomRepositoryProvider = Provider<RoomRepository>(
  (ref) => RoomRepository(FirebaseFirestore.instance),
);

/// 방 관련 실패. [message]는 화면에 그대로 보여 줄 수 있는 문구.
class RoomException implements Exception {
  const RoomException(this.message);
  final String message;

  @override
  String toString() => 'RoomException: $message';
}

/// `rooms/{roomId}` 생성·입장·조회.
class RoomRepository {
  RoomRepository(this._db, {Random? random})
    : _random = random ?? Random.secure();

  final FirebaseFirestore _db;
  final Random _random;

  static const codeLength = 6;

  /// 헷갈리는 글자(0/O, 1/I/L) 뺀 초대 코드 문자
  static const _codeChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const _maxCodeTries = 5;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');

  String _randomCode() => List.generate(
    codeLength,
    (_) => _codeChars[_random.nextInt(_codeChars.length)],
  ).join();

  /// 입력한 코드를 비교용으로 정리 (공백 제거, 대문자)
  static String normalizeCode(String input) =>
      input.replaceAll(RegExp(r'\s'), '').toUpperCase();

  Future<String> _uniqueCode() async {
    for (var i = 0; i < _maxCodeTries; i++) {
      final code = _randomCode();
      final hit = await _rooms.where('code', isEqualTo: code).limit(1).get();
      if (hit.docs.isEmpty) return code;
    }
    throw const RoomException('초대 코드를 만들지 못했어요. 다시 시도해 주세요.');
  }

  /// 방을 만들고 만든 방을 돌려준다. 만든 사람이 방장이자 첫 참가자.
  Future<Room> createRoom({
    required String uid,
    required String nickname,
    required String subjectId,
    required String name,
  }) async {
    final code = await _uniqueCode();
    final doc = _rooms.doc();
    final room = Room(
      id: doc.id,
      code: code,
      hostId: uid,
      subjectId: subjectId,
      name: name.trim(),
      players: {uid: RoomPlayer(nickname: nickname)},
      memberIds: [uid],
      createdAt: DateTime.now(),
    );
    final data = room.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    await doc.set(data);
    return room;
  }

  /// 초대 코드로 방을 찾는다. 없으면 null.
  Future<Room?> findByCode(String input) async {
    final code = normalizeCode(input);
    if (code.length != codeLength) return null;
    final snap = await _rooms.where('code', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return Room.fromMap(doc.id, doc.data());
  }

  /// 초대 코드로 입장. 이미 멤버면 닉네임만 갱신하고 그대로 돌려준다.
  Future<Room> joinByCode({
    required String code,
    required String uid,
    required String nickname,
  }) async {
    final room = await findByCode(code);
    if (room == null) {
      throw const RoomException('코드에 맞는 방이 없어요. 6자리 코드를 다시 확인해 주세요.');
    }
    final existing = room.players[uid];
    final player = (existing ?? const RoomPlayer(nickname: '')).copyWith(
      nickname: nickname,
    );
    await _rooms.doc(room.id).update({
      'players.$uid': player.toMap(),
      'memberIds': FieldValue.arrayUnion([uid]),
    });
    return Room(
      id: room.id,
      code: room.code,
      hostId: room.hostId,
      subjectId: room.subjectId,
      name: room.name,
      weeks: room.weeks,
      questionCount: room.questionCount,
      status: room.status,
      players: {...room.players, uid: player},
      memberIds: room.isMember(uid) ? room.memberIds : [...room.memberIds, uid],
      cardIds: room.cardIds,
      round: room.round,
      roundStartedAt: room.roundStartedAt,
      createdAt: room.createdAt,
    );
  }

  /// 방 하나 실시간 구독. 문서가 없어지면 null.
  Stream<Room?> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : Room.fromMap(doc.id, data);
    });
  }

  /// 내가 들어간 방 목록 (최근 만든 방 먼저).
  Stream<List<Room>> watchMyRooms(String uid) {
    return _rooms.where('memberIds', arrayContains: uid).snapshots().map((
      snap,
    ) {
      final rooms = [
        for (final doc in snap.docs) Room.fromMap(doc.id, doc.data()),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return rooms;
    });
  }
}
