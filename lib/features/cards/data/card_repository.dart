import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/card.dart';

/// `cards` 컬렉션 (A 소유). B는 읽기 + visibility/roomIds 갱신만 한다.
class CardRepository {
  CardRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('cards');

  /// 새 문서 ID를 미리 받는다 (카드 여러 장을 한 번에 만들 때).
  String newId() => _col.doc().id;

  /// 카드 여러 장을 한 번에 저장한다. 500개 단위로 배치를 나눈다.
  Future<void> createAll(List<QuizCard> cards) async {
    const chunk = 450;
    for (var i = 0; i < cards.length; i += chunk) {
      final batch = _db.batch();
      for (final c in cards.skip(i).take(chunk)) {
        batch.set(_col.doc(c.id), c.toMap());
      }
      await batch.commit();
    }
  }

  Future<void> create(QuizCard card) => _col.doc(card.id).set(card.toMap());

  /// 검수·수정 저장. `updatedAt`은 서버 시간.
  Future<void> update(QuizCard card) {
    return _col
        .doc(card.id)
        .update(card.toMap()..['updatedAt'] = FieldValue.serverTimestamp());
  }

  Future<void> setStatus(String cardId, CardStatus status) {
    return _col.doc(cardId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String cardId) => _col.doc(cardId).delete();

  Stream<QuizCard?> watch(String cardId) {
    return _col
        .doc(cardId)
        .snapshots()
        .map((d) => d.exists ? QuizCard.fromMap(d.id, d.data()!) : null);
  }

  /// 자료 하나로 만든 카드. 오래된 순(생성 순서).
  Stream<List<QuizCard>> watchBySource({
    required String uid,
    required String sourceId,
  }) {
    return _col
        .where('ownerId', isEqualTo: uid)
        .where('sourceId', isEqualTo: sourceId)
        .snapshots()
        .map((snap) => _sorted(snap, newestFirst: false));
  }

  /// 과목(선택: 주차)의 내 카드. 최신순.
  /// (등호 조건만 쓰고 정렬은 앱에서 해서 복합 색인을 피한다)
  Stream<List<QuizCard>> watchMine({
    required String uid,
    required String subjectId,
    int? week,
  }) {
    var q = _col
        .where('ownerId', isEqualTo: uid)
        .where('subjectId', isEqualTo: subjectId);
    if (week != null) q = q.where('week', isEqualTo: week);
    return q.snapshots().map((snap) => _sorted(snap, newestFirst: true));
  }

  static List<QuizCard> _sorted(
    QuerySnapshot<Map<String, dynamic>> snap, {
    required bool newestFirst,
  }) {
    final list = [for (final d in snap.docs) QuizCard.fromMap(d.id, d.data())];
    list.sort(
      (a, b) => newestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    return list;
  }
}
