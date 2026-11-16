import '../../core/models/card.dart';
import '../../core/models/model_utils.dart';
import '../../core/models/room.dart';
import '../room/progress_rules.dart';
import 'battle_repository.dart';
import 'battle_result.dart';

/// 승패
enum BattleOutcome { win, lose, draw }

/// 배틀 기록의 상대 한 명
class RecordOpponent {
  const RecordOpponent({
    required this.uid,
    required this.nickname,
    required this.score,
  });

  final String uid;
  final String nickname;
  final int score;

  factory RecordOpponent.fromMap(Map<String, dynamic> m) => RecordOpponent(
    uid: m['uid'] as String? ?? '',
    nickname: m['nickname'] as String? ?? '',
    score: readInt(m['score']),
  );

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'nickname': nickname,
    'score': score,
  };
}

/// 배틀 기록의 문제 한 개. 방이 지워져도 볼 수 있게 문제 글을 같이 둔다.
class RecordRound {
  const RecordRound({
    required this.cardId,
    required this.question,
    required this.answer,
    required this.correct,
  });

  final String cardId;
  final String question;
  final String answer;
  final bool correct;

  factory RecordRound.fromMap(Map<String, dynamic> m) => RecordRound(
    cardId: m['cardId'] as String? ?? '',
    question: m['question'] as String? ?? '',
    answer: m['answer'] as String? ?? '',
    correct: m['correct'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'cardId': cardId,
    'question': question,
    'answer': answer,
    'correct': correct,
  };
}

/// `users/{uid}/battles/{battleId}` — 내 배틀 기록 한 판 (docs/DATA.md).
/// 없는 필드는 기본값으로 읽는다 (예전 기록도 열리게).
class BattleRecord {
  const BattleRecord({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.at,
    required this.myScore,
    required this.rank,
    required this.total,
    required this.correct,
    required this.bestCombo,
    required this.outcome,
    this.opponents = const [],
    this.rounds = const [],
    this.xp,
  });

  final String id;
  final String roomId;
  final String roomName;
  final DateTime at;
  final int myScore;

  /// 몇 등 (1부터)
  final int rank;
  final int total;
  final int correct;
  final int bestCombo;
  final BattleOutcome outcome;
  final List<RecordOpponent> opponents;
  final List<RecordRound> rounds;

  /// 받은 XP. 저장 직후에는 null일 수 있다.
  final int? xp;

  int get percent => total == 0 ? 0 : (correct * 100 / total).round();

  /// 결과 랭크 S/A/B/C
  String get grade => resultRank(percent);

  factory BattleRecord.fromMap(String id, Map<String, dynamic> m) {
    List<Map<String, dynamic>> maps(Object? v) => v is List
        ? [
            for (final e in v)
              if (e is Map) Map<String, dynamic>.from(e),
          ]
        : const [];
    return BattleRecord(
      id: id,
      roomId: m['roomId'] as String? ?? '',
      roomName: m['roomName'] as String? ?? '',
      at: readDate(m['at']),
      myScore: readInt(m['myScore']),
      rank: readInt(m['rank'], 1),
      total: readInt(m['total']),
      correct: readInt(m['correct']),
      bestCombo: readInt(m['bestCombo']),
      outcome: readEnum(BattleOutcome.values, m['outcome'], BattleOutcome.draw),
      opponents: [
        for (final o in maps(m['opponents'])) RecordOpponent.fromMap(o),
      ],
      rounds: [for (final r in maps(m['rounds'])) RecordRound.fromMap(r)],
      xp: (m['xp'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'roomId': roomId,
    'roomName': roomName,
    'at': writeDate(at),
    'myScore': myScore,
    'rank': rank,
    'total': total,
    'correct': correct,
    'bestCombo': bestCombo,
    'outcome': outcome.name,
    'opponents': [for (final o in opponents) o.toMap()],
    'rounds': [for (final r in rounds) r.toMap()],
    'xp': xp,
  };
}

/// 결과 화면의 정보로 내 기록 한 판을 만든다.
/// 승패: 1등이고 같은 점수가 없으면 승, 1등 점수가 같으면 무, 아니면 패.
BattleRecord buildBattleRecord({
  required Room room,
  required String myUid,
  required List<QuizCard> cards,
  required List<BattleAnswer> answers,
  required DateTime at,
}) {
  final myScore = room.players[myUid]?.score ?? 0;
  final others = [
    for (final e in room.players.entries)
      if (e.key != myUid)
        RecordOpponent(
          uid: e.key,
          nickname: e.value.nickname,
          score: e.value.score,
        ),
  ];
  final best = others.isEmpty
      ? null
      : others.map((o) => o.score).reduce((a, b) => a > b ? a : b);
  final outcome = best == null || myScore > best
      ? BattleOutcome.win
      : myScore == best
      ? BattleOutcome.draw
      : BattleOutcome.lose;
  final rank = 1 + others.where((o) => o.score > myScore).length;

  final total = room.cardIds.length;
  final summary = BattleSummary.of(answers, total);
  final byId = {for (final c in cards) c.id: c};
  final byRound = {for (final a in answers) a.round: a};
  return BattleRecord(
    id: room.battleId,
    roomId: room.id,
    roomName: room.name,
    at: at,
    myScore: myScore,
    rank: rank,
    total: total,
    correct: summary.correct,
    bestCombo: summary.bestCombo,
    outcome: outcome,
    opponents: others,
    rounds: [
      for (final (r, id) in room.cardIds.indexed)
        RecordRound(
          cardId: id,
          question: byId[id]?.question ?? '',
          answer: byId[id]?.answer ?? '',
          correct: byRound[r]?.correct ?? false,
        ),
    ],
  );
}
