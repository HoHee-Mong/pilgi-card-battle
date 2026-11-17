import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/mock_exam.dart';
import '../../core/models/room.dart';
import '../bank/bank_repository.dart';

final mockExamRepositoryProvider = Provider<MockExamRepository>(
  (ref) => MockExamRepository(FirebaseFirestore.instance),
);

/// 방 문제은행 (주차·문항 수 고르기용)
final mockBankProvider = StreamProvider.autoDispose
    .family<List<BankEntry>, String>(
      (ref, roomId) => ref.watch(bankRepositoryProvider).watchBank(roomId),
    );

/// 이 방에서 내가 본 모의고사 (최신순)
final myMockExamsProvider = StreamProvider.autoDispose
    .family<List<MockExam>, String>((ref, roomId) {
      final uid = ref.watch(uidProvider);
      if (uid == null) return Stream.value(const []);
      return ref.watch(mockExamRepositoryProvider).watchMine(roomId, uid);
    });

/// `rooms/{roomId}/mockExams` (A 소유). 제출할 때 한 번만 쓴다.
/// (중간에 그만둔 시험은 남기지 않는다 → B의 점수 비교에 미완료 기록이 섞이지 않음)
class MockExamRepository {
  MockExamRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _exams(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('mockExams');

  Future<String> save(String roomId, MockExam exam) async {
    final ref = _exams(roomId).doc();
    await ref.set(exam.toMap());
    return ref.id;
  }

  Stream<List<MockExam>> watchMine(String roomId, String uid) {
    return _exams(roomId).where('uid', isEqualTo: uid).snapshots().map((snap) {
      final list = [
        for (final d in snap.docs) MockExam.fromMap(d.id, d.data()),
      ];
      list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return list;
    });
  }
}
