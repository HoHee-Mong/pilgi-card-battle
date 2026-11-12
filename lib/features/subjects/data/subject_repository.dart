import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/subject.dart';

/// `subjects` 컬렉션 읽기·쓰기 (A 소유).
class SubjectRepository {
  SubjectRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('subjects');

  /// 내 과목 목록. 최근 만든 순.
  /// (where + orderBy 복합 인덱스를 피하려고 정렬은 클라이언트에서 한다)
  Stream<List<Subject>> watchMine(String uid) {
    return _col.where('ownerId', isEqualTo: uid).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Subject.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<Subject?> watch(String id) {
    return _col.doc(id).snapshots().map(
      (d) => d.exists ? Subject.fromMap(d.id, d.data()!) : null,
    );
  }

  Future<Subject> create({
    required String uid,
    required String name,
    DateTime? examDate,
  }) async {
    final doc = _col.doc();
    final subject = Subject(
      id: doc.id,
      ownerId: uid,
      name: name.trim(),
      examDate: examDate,
      createdAt: DateTime.now(),
    );
    await doc.set(subject.toMap());
    return subject;
  }

  Future<void> update(Subject subject) {
    return _col.doc(subject.id).update({
      'name': subject.name.trim(),
      'examDate': subject.examDate == null
          ? null
          : Timestamp.fromDate(subject.examDate!),
    });
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
