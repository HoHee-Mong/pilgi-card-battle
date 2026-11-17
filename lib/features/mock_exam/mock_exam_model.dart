import '../../core/models/card.dart';
import '../../core/models/room.dart';
import '../solo/solo_model.dart';

/// 모의고사 문항 수 선택지 (`docs/SPEC.md` B)
const mockCounts = [10, 20, 30];

/// 문항당 제한 시간. 전체 제한 시간 = 문항 수 × 이 값.
const mockSecondsPerQuestion = 60;

int mockTimeLimitSec(int questions) => questions * mockSecondsPerQuestion;

/// 문제은행에 있는 주차 (오름차순)
List<int> bankWeeks(List<BankEntry> entries) =>
    ({for (final e in entries) e.week}.toList()..sort());

/// 범위 안 문제 수. [weeks]가 비면 전체.
int countInWeeks(List<BankEntry> entries, Set<int> weeks) =>
    entries.where((e) => weeks.isEmpty || weeks.contains(e.week)).length;

/// 채점 결과 한 문제
typedef MockMark = ({QuizCard card, String? answer, bool correct});

/// 일괄 채점. 안 푼 문제([answers]에 없거나 빈 답)는 오답.
List<MockMark> gradeMock(List<QuizCard> cards, Map<String, String> answers) {
  return [
    for (final c in cards)
      () {
        final a = answers[c.id]?.trim();
        final answered = a != null && a.isNotEmpty;
        return (
          card: c,
          answer: answered ? a : null,
          correct: answered && isCorrectAnswer(c, a),
        );
      }(),
  ];
}

/// 남은 보스 체력 = 아직 답하지 않은 문제 수
int unansweredCount(List<QuizCard> cards, Map<String, String> answers) =>
    cards.where((c) => (answers[c.id]?.trim() ?? '').isEmpty).length;

/// 맞힌 비율 0~100
int percentOf(int score, int total) =>
    total == 0 ? 0 : (score * 100 / total).round();

/// 초 → "18:42" (1시간 넘으면 "1:05:00")
String formatClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

/// 결과 제목
String mockResultTitle(int score, int total) {
  if (total > 0 && score == total) return '완벽 격파!';
  return percentOf(score, total) >= 50 ? '보스 격파!' : '보스가 버텼어요';
}

/// 채점 연출에서 한 문제에 쓰는 시간 (문항이 많으면 빠르게, 전체 4초 안팎)
Duration gradingStep(int total) {
  if (total <= 0) return Duration.zero;
  final ms = (4000 / total).clamp(150, 450).round();
  return Duration(milliseconds: ms);
}

/// 알약에 넣을 짧은 이름 ([max]자 넘으면 말줄임)
String shortLabel(String s, int max) {
  final runes = s.runes.toList();
  return runes.length <= max ? s : '${String.fromCharCodes(runes.take(max))}…';
}
