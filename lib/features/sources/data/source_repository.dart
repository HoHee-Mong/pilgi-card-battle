import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/models/source.dart';

/// 업로드할 파일 하나. 플랫폼(모바일·웹)에 상관없이 바이트로 다룬다.
class UploadFile {
  const UploadFile({
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
}

class SourceException implements Exception {
  const SourceException(this.message);
  final String message;

  @override
  String toString() => 'SourceException: $message';
}

/// `sources` 컬렉션 + Storage 원본 (A 소유).
class SourceRepository {
  SourceRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  /// 한 파일 최대 크기. Gemini inline 입력 한도(20MB)보다 작게 잡는다.
  static const maxSizeBytes = 15 * 1024 * 1024;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('sources');

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
        .map((snap) {
          final list = [
            for (final d in snap.docs) StudySource.fromMap(d.id, d.data()),
          ];
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
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
        .map((snap) {
          final list = [
            for (final d in snap.docs) StudySource.fromMap(d.id, d.data()),
          ];
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<StudySource?> watch(String id) {
    return _col
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? StudySource.fromMap(d.id, d.data()!) : null);
  }

  Future<StudySource?> get(String id) async {
    final d = await _col.doc(id).get();
    return d.exists ? StudySource.fromMap(d.id, d.data()!) : null;
  }

  /// Storage에 올리고 `sources` 문서를 만든다 (status: uploaded).
  /// [onProgress]는 0.0~1.0.
  Future<StudySource> upload({
    required String uid,
    required String subjectId,
    required int week,
    required UploadFile file,
    void Function(double progress)? onProgress,
  }) async {
    if (file.sizeBytes == 0) {
      throw const SourceException('빈 파일이에요.');
    }
    if (file.sizeBytes > maxSizeBytes) {
      throw const SourceException('파일이 너무 커요. 15MB 이하로 올려 주세요.');
    }

    final doc = _col.doc();
    final safeName = sanitizeFileName(file.fileName);
    final storagePath = 'sources/$uid/${doc.id}/$safeName';

    final task = _storage
        .ref(storagePath)
        .putData(file.bytes, SettableMetadata(contentType: file.contentType));
    if (onProgress != null) {
      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) onProgress(s.bytesTransferred / s.totalBytes);
      });
    }
    await task;

    final source = StudySource(
      id: doc.id,
      ownerId: uid,
      subjectId: subjectId,
      week: week,
      kind: file.kind,
      fileName: safeName,
      storagePath: storagePath,
      createdAt: DateTime.now(),
    );
    await doc.set(source.toMap()..['createdAt'] = FieldValue.serverTimestamp());
    return source;
  }

  /// 원본 바이트 읽기 (AI 분석용).
  Future<Uint8List> download(StudySource source) async {
    final data = await _storage.ref(source.storagePath).getData(maxSizeBytes);
    if (data == null) {
      throw const SourceException('원본 파일을 찾을 수 없어요.');
    }
    return data;
  }

  Future<void> updateStatus(String id, SourceStatus status, {String? summary}) {
    return _col.doc(id).update({'status': status.name, 'summary': ?summary});
  }

  /// 문서와 Storage 원본을 지운다. 카드는 그대로 남는다.
  Future<void> delete(StudySource source) async {
    await _col.doc(source.id).delete();
    try {
      await _storage.ref(source.storagePath).delete();
    } on FirebaseException catch (e) {
      // 이미 없으면 무시
      if (e.code != 'object-not-found') rethrow;
    }
  }

  /// Storage 경로에 넣을 수 있게 파일 이름을 다듬는다. 한글은 그대로 둔다.
  static String sanitizeFileName(String name) {
    final trimmed = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|#\[\]]'), '_');
    final collapsed = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return 'file';
    return collapsed.length > 80
        ? collapsed.substring(collapsed.length - 80)
        : collapsed;
  }
}
