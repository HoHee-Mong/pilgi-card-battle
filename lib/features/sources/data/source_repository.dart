import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/source.dart';

/// 기기에서 고른 파일 하나. 저장하지 않고 바로 Gemini로 보낸다.
class SourceFile {
  const SourceFile({
    required this.fileName,
    required this.bytes,
    required this.kind,
    required this.contentType,
  });

  final String fileName;
  final Uint8List bytes;
  final SourceKind kind;
  final String contentType;

  int get sizeBytes => bytes.length;

  /// 한 파일 최대 크기. Gemini inline 입력 한도(요청 전체 20MB)보다 작게 잡는다.
  /// 녹음(P2)도 같은 제한 안에서 바로 보낸다.
  static const maxSizeBytes = 15 * 1024 * 1024;

  /// 한 요청에 함께 보내는 파일(사진 여러 장) 합계 제한.
  static const maxBatchBytes = 18 * 1024 * 1024;
}

class SourceException implements Exception {
  const SourceException(this.message);
  final String message;

  @override
  String toString() => 'SourceException: $message';
}

/// `sources` 컬렉션 (A 소유). Storage는 쓰지 않는다 — 원본 파일은 저장하지 않는다.
class SourceRepository {
  SourceRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('sources');

  String newId() => _col.doc().id;

  /// 과목의 한 주차 자료. 최근 올린 순.
  /// (등호 조건만 쓰고 정렬은 앱에서 해서 복합 색인을 피한다)
  Stream<List<StudySource>> watchWeek({
    required String uid,
    required String subjectId,
    required int week,
  }) {
    return _col
        .where('ownerId', isEqualTo: uid)
        .where('subjectId', isEqualTo: subjectId)
        .where('week', isEqualTo: week)
        .snapshots()
        .map(_sorted);
  }

  /// 과목 전체 자료 (족보 노트용). 최근 올린 순.
  Stream<List<StudySource>> watchSubject({
    required String uid,
    required String subjectId,
  }) {
    return _col
        .where('ownerId', isEqualTo: uid)
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map(_sorted);
  }

  Stream<StudySource?> watch(String id) {
    return _col
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? StudySource.fromMap(d.id, d.data()!) : null);
  }

  /// 분석을 시작할 때 문서를 만든다 (status: processing). `createdAt`은 서버 시간.
  Future<void> create(StudySource source) {
    return _col
        .doc(source.id)
        .set(source.toMap()..['createdAt'] = FieldValue.serverTimestamp());
  }

  Future<void> updateStatus(String id, SourceStatus status, {String? summary}) {
    return _col.doc(id).update({'status': status.name, 'summary': ?summary});
  }

  /// 문서만 지운다. 카드는 그대로 남는다.
  Future<void> delete(StudySource source) => _col.doc(source.id).delete();

  static List<StudySource> _sorted(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = [
      for (final d in snap.docs) StudySource.fromMap(d.id, d.data()),
    ];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// 파일 크기 검사. 넘으면 [SourceException].
  static void checkSizes(List<SourceFile> files) {
    if (files.isEmpty) throw const SourceException('고른 파일이 없어요.');
    var total = 0;
    for (final f in files) {
      if (f.sizeBytes == 0) {
        throw SourceException('${f.fileName}: 빈 파일이에요.');
      }
      if (f.sizeBytes > SourceFile.maxSizeBytes) {
        throw SourceException('${f.fileName}: 파일이 너무 커요. 15MB 이하로 올려 주세요.');
      }
      total += f.sizeBytes;
    }
    if (total > SourceFile.maxBatchBytes) {
      throw const SourceException('한 번에 보내기엔 사진이 너무 많아요. 나눠서 올려 주세요.');
    }
  }
}
