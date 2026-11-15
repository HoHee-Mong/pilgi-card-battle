import 'model_utils.dart';

/// 방 상태. Firestore에는 `name` 그대로 저장한다.
enum RoomStatus { waiting, playing, finished }

/// `rooms/{roomId}.players[uid]` — 방 참가자 한 명.
class RoomPlayer {
  const RoomPlayer({
    required this.nickname,
    this.score = 0,
    this.combo = 0,
    this.ready = false,
  });

  final String nickname;

  /// 배틀 누적 점수
  final int score;

  /// 현재 연속 정답 수
  final int combo;

  /// 대기실 준비 여부
  final bool ready;

  factory RoomPlayer.fromMap(Map<String, dynamic> map) {
    return RoomPlayer(
      nickname: map['nickname'] as String? ?? '',
      score: readInt(map['score']),
      combo: readInt(map['combo']),
      ready: map['ready'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'score': score,
      'combo': combo,
      'ready': ready,
    };
  }

  RoomPlayer copyWith({String? nickname, int? score, int? combo, bool? ready}) {
    return RoomPlayer(
      nickname: nickname ?? this.nickname,
      score: score ?? this.score,
      combo: combo ?? this.combo,
      ready: ready ?? this.ready,
    );
  }
}

/// `rooms/{roomId}` — 스터디 방. docs/DATA.md와 1:1.
class Room {
  const Room({
    required this.id,
    required this.code,
    required this.hostId,
    required this.subjectId,
    required this.name,
    this.weeks = const [],
    this.questionCount = 5,
    this.status = RoomStatus.waiting,
    this.players = const {},
    this.memberIds = const [],
    this.cardIds = const [],
    this.round = 0,
    this.roundStartedAt,
    required this.createdAt,
  });

  /// Firestore 문서 ID. `toMap`에는 넣지 않는다.
  final String id;

  /// 6자리 초대 코드
  final String code;
  final String hostId;
  final String subjectId;
  final String name;

  /// 배틀 범위 (주차)
  final List<int> weeks;

  /// 배틀 문항 수 (5 | 10)
  final int questionCount;
  final RoomStatus status;

  /// uid → 참가자
  final Map<String, RoomPlayer> players;

  /// 방에 들어온 적 있는 uid 목록. "내 방 목록"을 `arrayContains`로 찾을 때 쓴다.
  /// (`players`는 배틀 대기실·점수용, 나가도 멤버로 남는다)
  final List<String> memberIds;

  /// 배틀 출제 순서 (bank에서 voteCount 높은 순 우선)
  final List<String> cardIds;

  /// 현재 문제 index
  final int round;
  final DateTime? roundStartedAt;
  final DateTime createdAt;

  bool isHost(String uid) => hostId == uid;
  bool isMember(String uid) => memberIds.contains(uid);

  /// 참가자 닉네임. 모르면 빈 문자열.
  String nicknameOf(String uid) => players[uid]?.nickname ?? '';

  factory Room.fromMap(String id, Map<String, dynamic> map) {
    final rawPlayers = map['players'];
    return Room(
      id: id,
      code: map['code'] as String? ?? '',
      hostId: map['hostId'] as String? ?? '',
      subjectId: map['subjectId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      weeks: readIntList(map['weeks']),
      questionCount: readInt(map['questionCount'], 5),
      status: readEnum(RoomStatus.values, map['status'], RoomStatus.waiting),
      players: rawPlayers is Map
          ? {
              for (final e in rawPlayers.entries)
                if (e.value is Map)
                  e.key.toString(): RoomPlayer.fromMap(
                    Map<String, dynamic>.from(e.value as Map),
                  ),
            }
          : const {},
      memberIds: readStringList(map['memberIds']),
      cardIds: readStringList(map['cardIds']),
      round: readInt(map['round']),
      roundStartedAt: readDateOrNull(map['roundStartedAt']),
      createdAt: readDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'hostId': hostId,
      'subjectId': subjectId,
      'name': name,
      'weeks': weeks,
      'questionCount': questionCount,
      'status': status.name,
      'players': {for (final e in players.entries) e.key: e.value.toMap()},
      'memberIds': memberIds,
      'cardIds': cardIds,
      'round': round,
      'roundStartedAt': roundStartedAt == null
          ? null
          : writeDate(roundStartedAt!),
      'createdAt': writeDate(createdAt),
    };
  }

  /// 화면 작업용 더미 방.
  factory Room.sample() {
    return Room(
      id: 'sample-room',
      code: 'K7Q2MX',
      hostId: 'sample-user',
      subjectId: 'sample-subject',
      name: '네트워크 스터디',
      weeks: const [3, 4],
      players: const {
        'sample-user': RoomPlayer(nickname: '승호', ready: true),
        'sample-user-2': RoomPlayer(nickname: '선우'),
      },
      memberIds: const ['sample-user', 'sample-user-2'],
      createdAt: DateTime(2026, 11, 12),
    );
  }
}

/// `rooms/{roomId}/bank/{cardId}` — 공동 문제은행 항목 + "나올 것 같아요" 투표.
class BankEntry {
  const BankEntry({
    required this.cardId,
    required this.addedBy,
    required this.addedByNickname,
    required this.week,
    this.voteCount = 0,
    this.voters = const [],
    required this.addedAt,
  });

  /// 문서 ID와 같다.
  final String cardId;
  final String addedBy;
  final String addedByNickname;
  final int week;

  /// 트랜잭션으로만 증감
  final int voteCount;

  /// 투표한 uid. 한 사람 1표, 다시 누르면 제거
  final List<String> voters;
  final DateTime addedAt;

  bool votedBy(String uid) => voters.contains(uid);

  factory BankEntry.fromMap(String id, Map<String, dynamic> map) {
    final cardId = map['cardId'] as String?;
    return BankEntry(
      cardId: cardId == null || cardId.isEmpty ? id : cardId,
      addedBy: map['addedBy'] as String? ?? '',
      addedByNickname: map['addedByNickname'] as String? ?? '',
      week: readInt(map['week'], 1),
      voteCount: readInt(map['voteCount']),
      voters: readStringList(map['voters']),
      addedAt: readDate(map['addedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cardId': cardId,
      'addedBy': addedBy,
      'addedByNickname': addedByNickname,
      'week': week,
      'voteCount': voteCount,
      'voters': voters,
      'addedAt': writeDate(addedAt),
    };
  }

  BankEntry copyWith({int? voteCount, List<String>? voters}) {
    return BankEntry(
      cardId: cardId,
      addedBy: addedBy,
      addedByNickname: addedByNickname,
      week: week,
      voteCount: voteCount ?? this.voteCount,
      voters: voters ?? this.voters,
      addedAt: addedAt,
    );
  }

  /// 화면 작업용 더미. [QuizCard.sample]과 같은 index를 쓰면 cardId가 맞는다.
  factory BankEntry.sample([int index = 0]) {
    const voterSets = [
      ['sample-user-2', 'u3', 'u4'],
      ['sample-user'],
      <String>[],
    ];
    final voters = voterSets[index % 3];
    return BankEntry(
      cardId: 'sample-$index',
      addedBy: index.isEven ? 'sample-user' : 'sample-user-2',
      addedByNickname: index.isEven ? '승호' : '선우',
      week: index % 3 == 0 ? 3 : 4,
      voteCount: voters.length,
      voters: voters,
      addedAt: DateTime(2026, 11, 12).add(Duration(hours: index)),
    );
  }
}
