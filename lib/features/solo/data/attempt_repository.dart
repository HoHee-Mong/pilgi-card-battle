import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/attempt.dart';
import '../../../core/models/card_meta.dart';

/// `users/{uid}/attempts` 풀이 기록과 `users/{uid}/cardMeta` 카드 상태 (A 소유).
/// B의 배틀 결과도 attempts에 `mode: battle`로 들어오므로 오답 노트에 자동 반영된다.
class AttemptRepository {
  AttemptRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _attempts(String uid) =>
      _db.collection('users').doc(uid).collection('attempts');

  CollectionReference<Map<String, dynamic>> _meta(String uid) =>
      _db.collection('users').doc(uid).collection('cardMeta');

  String newId(String uid) => _attempts(uid).doc().id;

  /// 풀이 기록을 한 번에 저장하고, 틀린 카드는 오답 노트에 넣는다
  /// (`inWrongNote: true`, `reviewedDone: false`). 맞힌 카드는 건드리지 않는다.
  Future<void> saveAttempts(String uid, List<Attempt> attempts) async {
    const chunk = 200; // attempt 1 + meta 1 = 쓰기 2개씩, 배치 한도 500
    for (var i = 0; i < attempts.length; i += chunk) {
      final batch = _db.batch();
      for (final a in attempts.skip(i).take(chunk)) {
        batch.set(_attempts(uid).doc(a.id), a.toMap());
        if (!a.correct) {
          batch.set(_meta(uid).doc(a.cardId), {
            'inWrongNote': true,
            'reviewedDone': false,
          }, SetOptions(merge: true));
        }
      }
      await batch.commit();
    }
  }

  /// 오답 노트에서 다시 맞혔을 때.
  Future<void> markReviewed(String uid, String cardId) {
    return _meta(uid)
        .doc(cardId)
        .set({'reviewedDone': true}, SetOptions(merge: true));
  }

  Future<void> setFavorite(String uid, String cardId, bool favorite) {
    return _meta(uid)
        .doc(cardId)
        .set({'favorite': favorite}, SetOptions(merge: true));
  }

  /// 내 카드 상태 전체 (오답 노트·즐겨찾기용). cardId → meta.
  Stream<Map<String, CardMeta>> watchMeta(String uid) {
    return _meta(uid).snapshots().map(
      (snap) => {
        for (final d in snap.docs) d.id: CardMeta.fromMap(d.id, d.data()),
      },
    );
  }

  /// 과목의 풀이 기록. 최신순.
  Stream<List<Attempt>> watchBySubject({
    required String uid,
    required String subjectId,
  }) {
    return _attempts(
      uid,
    ).where('subjectId', isEqualTo: subjectId).snapshots().map((snap) {
      final list = [for (final d in snap.docs) Attempt.fromMap(d.id, d.data())];
      list.sort((a, b) => b.at.compareTo(a.at));
      return list;
    });
  }
}
