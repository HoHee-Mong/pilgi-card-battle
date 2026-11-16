import '../../core/models/progress.dart';

/// XP를 받는 행동. A의 카드 만들기·모의고사에서도 [ProgressRepository.record]로 부른다.
enum XpEvent {
  /// "나올 것 같아요" 투표 (취소는 해당 없음)
  vote(5),

  /// 카드 만들기 (검수 완료 또는 직접 쓰기) — A가 부름
  cardCreated(10),

  /// 배틀 한 판 끝 (점수 보너스는 따로)
  battle(30),

  /// 모의고사 제출 — A가 부름
  mock(40);

  const XpEvent(this.xp);
  final int xp;
}

/// 투표 XP는 하루 이만큼까지만 (눌렀다 취소 반복 방지)
const kVoteXpPerDay = 20;

/// 오늘의 퀘스트
class Quest {
  const Quest({
    required this.id,
    required this.title,
    required this.target,
    required this.xp,
    required this.countOf,
  });

  final String id;
  final String title;
  final int target;
  final int xp;
  final int Function(Progress) countOf;

  int progressOf(Progress p) => countOf(p).clamp(0, target);
  bool doneBy(Progress p) => countOf(p) >= target;
}

/// 매일 같은 퀘스트 3개 (시안: 투표 5번, 카드 3장)
final kDailyQuests = [
  Quest(
    id: 'vote5',
    title: '‘나올 것 같아요’ 5번 누르기',
    target: 5,
    xp: 30,
    countOf: (p) => p.votes,
  ),
  Quest(
    id: 'card3',
    title: '카드 3장 만들기',
    target: 3,
    xp: 50,
    countOf: (p) => p.cards,
  ),
  Quest(
    id: 'battle1',
    title: '친구랑 배틀 1판',
    target: 1,
    xp: 40,
    countOf: (p) => p.battles,
  ),
];

/// 레벨 n → n+1에 필요한 XP (레벨이 오를수록 조금씩 늘어남)
int xpToNext(int level) => 50 + level * 50;

/// 누적 XP → (레벨, 이번 레벨에서 모은 XP, 다음 레벨까지 필요한 XP). 레벨은 1부터.
(int level, int into, int need) levelOf(int xp) {
  var level = 1;
  var left = xp < 0 ? 0 : xp;
  while (left >= xpToNext(level)) {
    left -= xpToNext(level);
    level++;
  }
  return (level, left, xpToNext(level));
}

/// 칭호 (이 레벨부터)
const kTitles = [
  (1, '예상 새내기'),
  (3, '예상 견습생'),
  (6, '예상 탐정'),
  (10, '예상왕'),
  (15, '예상 전설'),
];

String titleOf(int level) =>
    kTitles.lastWhere((t) => level >= t.$1, orElse: () => kTitles.first).$2;

/// 다음 칭호와 그 레벨. 마지막 칭호면 null.
(int level, String title)? nextTitle(int level) {
  for (final t in kTitles) {
    if (t.$1 > level) return t;
  }
  return null;
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 날짜가 바뀌었으면 하루 카운터를 비운다.
Progress rollDay(Progress p, String today) => p.day == today
    ? p
    : p.copyWith(
        day: today,
        votes: 0,
        cards: 0,
        battles: 0,
        mocks: 0,
        claimed: const [],
      );

/// 오늘 앱을 열었을 때 연속 출석 갱신 (어제 왔으면 +1, 오늘 이미 왔으면 그대로, 아니면 1)
Progress applyCheckIn(Progress p, DateTime now) {
  final today = dayKey(now);
  if (p.lastActive == today) return rollDay(p, today);
  final yesterday = dayKey(now.subtract(const Duration(days: 1)));
  final streak = p.lastActive == yesterday ? p.streak + 1 : 1;
  return rollDay(p, today).copyWith(streak: streak, lastActive: today);
}

/// 행동 하나 반영: XP + 하루 카운터 + 다 채운 퀘스트 보상 자동 지급.
/// 반환: (새 진행, 이번에 받은 XP 합계)
(Progress, int) applyEvent(
  Progress p,
  XpEvent event,
  DateTime now, {
  int bonusXp = 0,
}) {
  var next = applyCheckIn(p, now);
  var gained = bonusXp;
  switch (event) {
    case XpEvent.vote:
      if (next.votes < kVoteXpPerDay) gained += event.xp;
      next = next.copyWith(votes: next.votes + 1);
    case XpEvent.cardCreated:
      gained += event.xp;
      next = next.copyWith(cards: next.cards + 1);
    case XpEvent.battle:
      gained += event.xp;
      next = next.copyWith(battles: next.battles + 1);
    case XpEvent.mock:
      gained += event.xp;
      next = next.copyWith(mocks: next.mocks + 1);
  }
  final claimed = [...next.claimed];
  for (final q in kDailyQuests) {
    if (!claimed.contains(q.id) && q.doneBy(next)) {
      claimed.add(q.id);
      gained += q.xp;
    }
  }
  return (next.copyWith(xp: next.xp + gained, claimed: claimed), gained);
}

/// 결과 랭크 (맞힌 비율 0~100). 배틀·모의고사 결과에 같이 쓴다.
String resultRank(int percent) => switch (percent) {
  >= 90 => 'S',
  >= 70 => 'A',
  >= 50 => 'B',
  _ => 'C',
};
