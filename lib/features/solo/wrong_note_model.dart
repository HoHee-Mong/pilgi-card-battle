import '../../core/models/attempt.dart';
import '../../core/models/card.dart';

/// 오답 노트 한 줄. 풀이 기록(`attempts`)만으로 계산한다 — 혼자 풀기·배틀·모의고사 모두 반영.
///
/// 한 번이라도 틀린 카드가 노트에 들어오고, 가장 최근 기록이 정답이면 "복습 완료".
class WrongEntry {
  const WrongEntry({
    required this.cardId,
    required this.wrongCount,
    required this.lastAt,
    required this.lastMode,
    required this.reviewed,
  });

  final String cardId;

  /// 틀린 횟수
  final int wrongCount;

  /// 마지막 풀이 시각
  final DateTime lastAt;

  /// 마지막으로 푼 곳
  final AttemptMode lastMode;

  /// 마지막 풀이가 정답이면 true (= 복습 완료)
  final bool reviewed;

  bool get needsReview => !reviewed;
}

/// 틀린 적 있는 카드마다 [WrongEntry]를 만든다. 복습 필요가 먼저, 그다음 최근 순.
List<WrongEntry> buildWrongNote(Iterable<Attempt> attempts) {
  final byCard = <String, List<Attempt>>{};
  for (final a in attempts) {
    byCard.putIfAbsent(a.cardId, () => []).add(a);
  }
  final entries = <WrongEntry>[];
  for (final MapEntry(key: cardId, value: list) in byCard.entries) {
    final wrong = list.where((a) => !a.correct).length;
    if (wrong == 0) continue;
    list.sort((a, b) => b.at.compareTo(a.at));
    final last = list.first;
    entries.add(
      WrongEntry(
        cardId: cardId,
        wrongCount: wrong,
        lastAt: last.at,
        lastMode: last.mode,
        reviewed: last.correct,
      ),
    );
  }
  entries.sort((a, b) {
    if (a.reviewed != b.reviewed) return a.reviewed ? 1 : -1;
    return b.lastAt.compareTo(a.lastAt);
  });
  return entries;
}

/// 오답 노트 화면용: 카드 본문 + 기록.
typedef WrongCard = ({QuizCard card, WrongEntry entry});

String attemptModeLabel(AttemptMode m) => switch (m) {
  AttemptMode.solo => '혼자 풀기',
  AttemptMode.battle => '배틀',
  AttemptMode.mock => '모의고사',
};
