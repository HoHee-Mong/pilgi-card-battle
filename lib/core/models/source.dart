import 'model_utils.dart';

/// 업로드 원본 종류. Firestore에는 `name` 그대로 저장한다.
enum SourceKind { image, pdf, audio }

/// `uploaded`(올림) → `processing`(AI 분석 중) → `done` | `failed`
enum SourceStatus { uploaded, processing, done, failed }

/// `sources/{sourceId}` — 업로드 원본 (A). 항상 비공개.
/// `transcript`·`emphasis`(녹음, P2)는 그때 필드만 추가한다.
class StudySource {
  const StudySource({
    required this.id,
    required this.ownerId,
    required this.subjectId,
    required this.week,
    required this.kind,
    required this.fileName,
    required this.storagePath,
    this.status = SourceStatus.uploaded,
    this.summary,
    required this.createdAt,
  });

  /// Firestore 문서 ID. `toMap`에는 넣지 않는다.
  final String id;
  final String ownerId;
  final String subjectId;
  final int week;
  final SourceKind kind;
  final String fileName;

  /// Firebase Storage 경로. 예: `sources/{uid}/{sourceId}/{fileName}`
  final String storagePath;
  final SourceStatus status;

  /// AI 핵심 요약. 분석 전이면 null.
  final String? summary;
  final DateTime createdAt;

  bool get isProcessing => status == SourceStatus.processing;
  bool get isDone => status == SourceStatus.done;

  /// 카드 출처 표시의 앞부분. 예: "3주차 강의자료.pdf"
  String get label => '$week주차 $fileName';

  factory StudySource.fromMap(String id, Map<String, dynamic> map) {
    return StudySource(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      subjectId: map['subjectId'] as String? ?? '',
      week: readInt(map['week'], 1),
      kind: readEnum(SourceKind.values, map['kind'], SourceKind.image),
      fileName: map['fileName'] as String? ?? '',
      storagePath: map['storagePath'] as String? ?? '',
      status: readEnum(
        SourceStatus.values,
        map['status'],
        SourceStatus.uploaded,
      ),
      summary: map['summary'] as String?,
      createdAt: readDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'subjectId': subjectId,
      'week': week,
      'kind': kind.name,
      'fileName': fileName,
      'storagePath': storagePath,
      'status': status.name,
      'summary': summary,
      'createdAt': writeDate(createdAt),
    };
  }

  StudySource copyWith({SourceStatus? status, String? summary}) {
    return StudySource(
      id: id,
      ownerId: ownerId,
      subjectId: subjectId,
      week: week,
      kind: kind,
      fileName: fileName,
      storagePath: storagePath,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      createdAt: createdAt,
    );
  }
}
