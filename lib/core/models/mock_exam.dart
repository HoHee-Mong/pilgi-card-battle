import 'model_utils.dart';

/// `rooms/{roomId}/mockExams/{examId}` — "우리가 만든 모의고사" 기록.
class MockExam {
  const MockExam({
    required this.id,
    required this.uid,
    required this.nickname,
    required this.cardIds,
    required this.weeks,
    required this.timeLimitSec,
    this.score = 0,
    required this.total,
    this.wrongCardIds = const [],
    required this.startedAt,
    this.submittedAt,
  });

  final String id;
  final String uid;
  final String nickname;

  /// voteCount 내림차순으로 뽑은 문항
  final List<String> cardIds;
  final List<int> weeks;
  final int timeLimitSec;
  final int score;
  final int total;
  final List<String> wrongCardIds;
  final DateTime startedAt;

  /// 제출 전이면 null
  final DateTime? submittedAt;

  bool get isSubmitted => submittedAt != null;

  factory MockExam.fromMap(String id, Map<String, dynamic> map) {
    return MockExam(
      id: id,
      uid: map['uid'] as String? ?? '',
      nickname: map['nickname'] as String? ?? '',
      cardIds: readStringList(map['cardIds']),
      weeks: readIntList(map['weeks']),
      timeLimitSec: readInt(map['timeLimitSec']),
      score: readInt(map['score']),
      total: readInt(map['total']),
      wrongCardIds: readStringList(map['wrongCardIds']),
      startedAt: readDate(map['startedAt']),
      submittedAt: readDateOrNull(map['submittedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nickname': nickname,
      'cardIds': cardIds,
      'weeks': weeks,
      'timeLimitSec': timeLimitSec,
      'score': score,
      'total': total,
      'wrongCardIds': wrongCardIds,
      'startedAt': writeDate(startedAt),
      'submittedAt': submittedAt == null ? null : writeDate(submittedAt!),
    };
  }

  /// 제출 시 채점 결과를 채운다.
  MockExam copyWith({
    int? score,
    List<String>? wrongCardIds,
    DateTime? submittedAt,
  }) {
    return MockExam(
      id: id,
      uid: uid,
      nickname: nickname,
      cardIds: cardIds,
      weeks: weeks,
      timeLimitSec: timeLimitSec,
      score: score ?? this.score,
      total: total,
      wrongCardIds: wrongCardIds ?? this.wrongCardIds,
      startedAt: startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
}
