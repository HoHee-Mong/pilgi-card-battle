import 'model_utils.dart';

/// 업로드 원본 종류. Firestore에는 `name` 그대로 저장한다.
enum SourceKind { image, pdf, audio }

/// `processing`(AI 분석 중) → `done` | `failed`
/// (`uploaded`는 Storage를 쓰던 때의 값. 지금은 쓰지 않지만 읽기 호환을 위해 남긴다)
enum SourceStatus { uploaded, processing, done, failed }

/// `sources/{sourceId}` — 자료 기록 (A). 항상 비공개.
///
/// Storage를 쓰지 않는다(Blaze 요금제 필요). 파일 바이트는 기기에서 바로 Gemini로 보내고,
/// 여기에는 파일 이름·종류·주차·상태·요약만 남는다. 원본은 저장하지 않는다.
/// `transcript`·`emphasis`(녹음, P2)는 그때 필드만 추가한다.
class StudySource {
  const StudySource({
    required this.id,
    required this.ownerId,
    required this.subjectId,
    required this.week,
    required this.kind,
    required this.fileName,
    this.status = SourceStatus.processing,
    this.summary,
    required this.createdAt,
  });

  /// Firestore 문서 ID. `toMap`에는 넣지 않는다.
  final String id;
  final String ownerId;
  final String subjectId;
  final int week;
  final SourceKind kind;

  /// 표시용 이름. 사진 여러 장이면 "필기 11.15 2130 (3장)"처럼 묶는다.
  final String fileName;
  final SourceStatus status;

  /// AI 핵심 요약. 분석 전·실패면 null.
  final String? summary;
  final DateTime createdAt;

  bool get isProcessing => status == SourceStatus.processing;
  bool get isDone => status == SourceStatus.done;
  bool get isFailed => status == SourceStatus.failed;

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
      status: readEnum(
        SourceStatus.values,
        map['status'],
        SourceStatus.processing,
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
      status: status ?? this.status,
      summary: summary ?? this.summary,
      createdAt: createdAt,
    );
  }
}
