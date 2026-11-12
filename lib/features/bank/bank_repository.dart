import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/card.dart';
import '../../core/models/room.dart';

final bankRepositoryProvider = Provider<BankRepository>(
  (ref) => BankRepository(FirebaseFirestore.instance),
);

/// 공동 문제은행 정렬
enum BankSort {
  /// 투표 많은 순 (같으면 최신순)
  votes,

  /// 최신순
  latest,

  /// 주차 오름차순 (같은 주차 안에서는 투표 많은 순)
  week,
}

class BankException implements Exception {
  const BankException(this.message);
  final String message;

  @override
  String toString() => 'BankException: $message';
}

/// `rooms/{roomId}/bank` — 공동 문제은행과 "나올 것 같아요" 투표.
///
/// A가 쓰는 계약 (`docs/DATA.md`):
/// - [addCard]: 카드 화면의 "방에 공유"
/// - [topVoted]: 모의고사 문항 뽑기
/// - [cardsByIds]: bank 항목의 카드 본문 읽기
class BankRepository {
  BankRepository(this._db);

  final FirebaseFirestore _db;

  /// Firestore `whereIn` 한 번에 넣을 수 있는 최대 개수
  static const _whereInLimit = 30;

  CollectionReference<Map<String, dynamic>> _bank(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('bank');

  CollectionReference<Map<String, dynamic>> get _cards =>
      _db.collection('cards');

  /// 내 카드를 방 문제은행에 공유한다. `verified` 카드만 가능.
  ///
  /// 이미 공유된 카드면 투표를 건드리지 않고 그대로 둔다.
  /// 카드 문서의 `visibility`를 room으로, `roomIds`에 방을 추가한다.
  Future<void> addCard({
    required String roomId,
    required QuizCard card,
    required String uid,
    required String nickname,
  }) async {
    if (!card.isVerified) {
      throw const BankException('검수 완료한 카드만 방에 공유할 수 있어요.');
    }
    final entryRef = _bank(roomId).doc(card.id);
    final cardRef = _cards.doc(card.id);

    await _db.runTransaction((tx) async {
      final existing = await tx.get(entryRef);
      if (!existing.exists) {
        final entry = BankEntry(
          cardId: card.id,
          addedBy: uid,
          addedByNickname: nickname,
          week: card.week,
          addedAt: DateTime.now(),
        );
        tx.set(
          entryRef,
          entry.toMap()..['addedAt'] = FieldValue.serverTimestamp(),
        );
      }
      tx.update(cardRef, {
        'visibility': CardVisibility.room.name,
        'roomIds': FieldValue.arrayUnion([roomId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 문제은행 실시간 목록. 문항 수가 적어 정렬은 앱에서 한다 (복합 색인 불필요).
  Stream<List<BankEntry>> watchBank(
    String roomId, {
    BankSort sort = BankSort.votes,
  }) {
    return _bank(roomId).snapshots().map(
      (snap) => sortEntries([
        for (final doc in snap.docs) BankEntry.fromMap(doc.id, doc.data()),
      ], sort),
    );
  }

  /// 항목 하나 실시간 구독 (`VoteButton`용). 없으면 null.
  Stream<BankEntry?> watchEntry(String roomId, String cardId) {
    return _bank(roomId).doc(cardId).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : BankEntry.fromMap(doc.id, data);
    });
  }

  /// "나올 것 같아요" 투표/취소. 한 사람당 1표, 다시 누르면 취소.
  /// 반환값: 이번 호출 후 내가 투표한 상태인지.
  Future<bool> toggleVote({
    required String roomId,
    required String cardId,
    required String uid,
  }) {
    final ref = _bank(roomId).doc(cardId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) {
        throw const BankException('문제은행에서 사라진 카드예요.');
      }
      final entry = BankEntry.fromMap(snap.id, data);
      final voted = entry.votedBy(uid);
      final voters = voted
          ? entry.voters.where((v) => v != uid).toList()
          : [...entry.voters, uid];
      // voteCount는 voters 길이로 맞춰서 어긋나지 않게 한다.
      tx.update(ref, {'voters': voters, 'voteCount': voters.length});
      return !voted;
    });
  }

  /// 투표 많은 순으로 [limit]개. [weeks]가 비어 있으면 전체 주차.
  /// 모의고사·배틀 출제에 쓴다.
  Future<List<BankEntry>> topVoted(
    String roomId, {
    List<int> weeks = const [],
    required int limit,
  }) async {
    final snap = await _bank(roomId).get();
    final entries = [
      for (final doc in snap.docs) BankEntry.fromMap(doc.id, doc.data()),
    ];
    return pickTopVoted(entries, weeks: weeks, limit: limit);
  }

  /// cardId 목록으로 카드 본문을 읽는다. 결과는 [cardIds] 순서를 따르고,
  /// 지워졌거나 읽을 수 없는 카드는 빠진다.
  Future<List<QuizCard>> cardsByIds(List<String> cardIds) async {
    if (cardIds.isEmpty) return const [];
    final byId = <String, QuizCard>{};
    for (var i = 0; i < cardIds.length; i += _whereInLimit) {
      final chunk = cardIds.sublist(
        i,
        (i + _whereInLimit).clamp(0, cardIds.length),
      );
      final snap = await _cards
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        byId[doc.id] = QuizCard.fromMap(doc.id, doc.data());
      }
    }
    return [
      for (final id in cardIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  // ---- 순수 함수 (Firestore 없이 테스트 가능) ----

  static List<BankEntry> sortEntries(List<BankEntry> entries, BankSort sort) {
    int byVotes(BankEntry a, BankEntry b) {
      final v = b.voteCount.compareTo(a.voteCount);
      return v != 0 ? v : b.addedAt.compareTo(a.addedAt);
    }

    final list = [...entries];
    switch (sort) {
      case BankSort.votes:
        list.sort(byVotes);
      case BankSort.latest:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case BankSort.week:
        list.sort((a, b) {
          final w = a.week.compareTo(b.week);
          return w != 0 ? w : byVotes(a, b);
        });
    }
    return list;
  }

  static List<BankEntry> pickTopVoted(
    List<BankEntry> entries, {
    List<int> weeks = const [],
    required int limit,
  }) {
    final inRange = weeks.isEmpty
        ? entries
        : entries.where((e) => weeks.contains(e.week)).toList();
    return sortEntries(inRange, BankSort.votes).take(limit).toList();
  }
}
