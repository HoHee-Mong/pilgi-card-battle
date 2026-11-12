import 'model_utils.dart';

/// 어디서 푼 기록인지. B의 배틀 결과는 [battle]로 저장한다.
enum AttemptMode { solo, battle, mock }

/// `users/{uid}/attempts/{attemptId}` — A가 쓰고, B도 배틀 결과를 여기에 쓴다.
class Attempt {
  const Attempt({
    required this.id,
    required this.cardId,
    required this.subjectId,
    required this.concept,
    required this.correct,
    required this.mode,
    required this.at,
  });

  final String id;
  final String cardId;
  final String subjectId;
  final String concept;
  final bool correct;
  final AttemptMode mode;
  final DateTime at;

  factory Attempt.fromMap(String id, Map<String, dynamic> map) {
    return Attempt(
      id: id,
      cardId: map['cardId'] as String? ?? '',
      subjectId: map['subjectId'] as String? ?? '',
      concept: map['concept'] as String? ?? '',
      correct: map['correct'] as bool? ?? false,
      mode: readEnum(AttemptMode.values, map['mode'], AttemptMode.solo),
      at: readDate(map['at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cardId': cardId,
      'subjectId': subjectId,
      'concept': concept,
      'correct': correct,
      'mode': mode.name,
      'at': writeDate(at),
    };
  }
}
