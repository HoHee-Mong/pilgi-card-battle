import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/progress.dart';
import 'progress_rules.dart';

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(FirebaseFirestore.instance),
);

/// 내 진행 (실시간). 로그인 전이면 빈 값.
final myProgressProvider = StreamProvider<Progress>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const Progress());
  return ref.watch(progressRepositoryProvider).watch(uid);
});

/// `users/{uid}/progress/main` 읽기·쓰기.
///
/// A도 쓴다: 카드 만들 때 `record(uid, XpEvent.cardCreated)`,
/// 모의고사 제출 때 `record(uid, XpEvent.mock)`.
class ProgressRepository {
  ProgressRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid).collection('progress').doc('main');

  Stream<Progress> watch(String uid) => _doc(uid).snapshots().map(
    (d) => d.data() == null ? const Progress() : Progress.fromMap(d.data()!),
  );

  /// 앱을 열었을 때 (로비) 연속 출석 갱신
  Future<void> checkIn(String uid) =>
      _update(uid, (p) => (applyCheckIn(p, DateTime.now()), 0));

  /// 행동 기록 → 받은 XP. 실패해도 앱 흐름은 막지 않는다 (0 반환).
  Future<int> record(String uid, XpEvent event, {int bonusXp = 0}) async {
    try {
      return await _update(
        uid,
        (p) => applyEvent(p, event, DateTime.now(), bonusXp: bonusXp),
      );
    } catch (e) {
      debugPrint('XP 기록 실패: $e');
      return 0;
    }
  }

  Future<int> _update(String uid, (Progress, int) Function(Progress) change) {
    final ref = _doc(uid);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final before = snap.data() == null
          ? const Progress()
          : Progress.fromMap(snap.data()!);
      final (after, gained) = change(before);
      tx.set(ref, after.toMap());
      return gained;
    });
  }
}
