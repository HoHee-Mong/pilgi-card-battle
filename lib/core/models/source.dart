import 'model_utils.dart';

/// 녹음 전사 한 줄. [t]는 녹음 시작부터 초.
class TranscriptLine {
  const TranscriptLine({required this.t, required this.text});

  final int t;
  final String text;

  /// "23:41" (1시간 넘으면 "1:02:03")
  String get clock => formatSeconds(t);

  factory TranscriptLine.fromMap(Map<String, dynamic> m) =>
      TranscriptLine(t: readInt(m['t']), text: m['text'] as String? ?? '');

  Map<String, dynamic> toMap() => {'t': t, 'text': text};
}

/// 초 → "23:41" / "1:02:03"
String formatSeconds(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}

List<TranscriptLine> _readTranscript(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map) TranscriptLine.fromMap(e.cast<String, dynamic>()),
  ];
}

/// 업로드 원본 종류. Firestore에는 `name` 그대로 저장한다.
enum SourceKind { image, pdf, audio }

/// `processing`(AI 분석 중) → `done` | `failed`
/// (`uploaded`는 Storage를 쓰던 때의 값. 지금은 쓰지 않지만 읽기 호환을 위해 남긴다)
enum SourceStatus { uploaded, processing, done, failed }

/// `sources/{sourceId}` — 자료 기록 (A). 항상 비공개.
///
/// Storage를 쓰지 않는다(Blaze 요금제 필요). 파일 바이트는 기기에서 바로 Gemini로 보내고,
/// 여기에는 파일 이름·종류·주차·상태·요약만 남는다. 원본은 저장하지 않는다.
/// 녹음이면 [transcript](시간별 전사)도 남는다. 녹음 파일 자체는 저장하지 않는다.
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
    this.transcript = const [],
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

  /// 녹음일 때 시간별 전사 (P2). 녹음이 아니면 빈 목록.
  final List<TranscriptLine> transcript;
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
      transcript: _readTranscript(map['transcript']),
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
      if (transcript.isNotEmpty)
        'transcript': [for (final l in transcript) l.toMap()],
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
      transcript: transcript,
      createdAt: createdAt,
    );
  }
}
