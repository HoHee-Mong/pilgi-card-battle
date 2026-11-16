import 'model_utils.dart';

/// `users/{uid}/progress/main` — 레벨·XP·연속 출석·오늘의 퀘스트 (B 소유, P2).
///
/// 하루 단위 카운터(`votes`·`cards`·`battles`·`mocks`)와 `claimed`는 [day]가 바뀌면 0부터 다시 센다.
class Progress {
  const Progress({
    this.xp = 0,
    this.streak = 0,
    this.lastActive = '',
    this.day = '',
    this.votes = 0,
    this.cards = 0,
    this.battles = 0,
    this.mocks = 0,
    this.claimed = const [],
  });

  /// 누적 XP
  final int xp;

  /// 연속 출석 일수
  final int streak;

  /// 마지막으로 앱을 연 날 (yyyy-MM-dd, 기기 날짜)
  final String lastActive;

  /// 아래 하루 카운터가 가리키는 날 (yyyy-MM-dd)
  final String day;
  final int votes;
  final int cards;
  final int battles;
  final int mocks;

  /// 오늘 보상을 받은 퀘스트 id
  final List<String> claimed;

  factory Progress.fromMap(Map<String, dynamic> map) => Progress(
    xp: readInt(map['xp']),
    streak: readInt(map['streak']),
    lastActive: map['lastActive'] as String? ?? '',
    day: map['day'] as String? ?? '',
    votes: readInt(map['votes']),
    cards: readInt(map['cards']),
    battles: readInt(map['battles']),
    mocks: readInt(map['mocks']),
    claimed: readStringList(map['claimed']),
  );

  Map<String, dynamic> toMap() => {
    'xp': xp,
    'streak': streak,
    'lastActive': lastActive,
    'day': day,
    'votes': votes,
    'cards': cards,
    'battles': battles,
    'mocks': mocks,
    'claimed': claimed,
  };

  Progress copyWith({
    int? xp,
    int? streak,
    String? lastActive,
    String? day,
    int? votes,
    int? cards,
    int? battles,
    int? mocks,
    List<String>? claimed,
  }) => Progress(
    xp: xp ?? this.xp,
    streak: streak ?? this.streak,
    lastActive: lastActive ?? this.lastActive,
    day: day ?? this.day,
    votes: votes ?? this.votes,
    cards: cards ?? this.cards,
    battles: battles ?? this.battles,
    mocks: mocks ?? this.mocks,
    claimed: claimed ?? this.claimed,
  );
}
