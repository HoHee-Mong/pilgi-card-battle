import 'model_utils.dart';

/// 카드 유형. Firestore에는 `name` 그대로 저장한다 ("mcq" | "ox" | "short").
enum CardType { mcq, ox, short }

/// AI가 만든 카드는 항상 [draft]. 사용자가 검수해야 [verified].
enum CardStatus { draft, verified }

enum CardVisibility { private, room }

/// `cards/{cardId}` — docs/DATA.md와 1:1.
class QuizCard {
  const QuizCard({
    required this.id,
    required this.ownerId,
    required this.ownerNickname,
    required this.subjectId,
    required this.week,
    required this.sourceId,
    required this.sourceLabel,
    required this.type,
    required this.question,
    this.choices = const [],
    required this.answer,
    this.explanation = '',
    this.concept = '',
    this.status = CardStatus.draft,
    this.visibility = CardVisibility.private,
    this.roomIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firestore 문서 ID. `toMap`에는 넣지 않는다.
  final String id;
  final String ownerId;
  final String ownerNickname;
  final String subjectId;
  final int week;
  final String sourceId;

  /// 예: "3주차 강의자료.pdf p.12" / "3주차 녹음 23:41"
  final String sourceLabel;
  final CardType type;
  final String question;

  /// mcq만 사용. 나머지 유형은 빈 리스트.
  final List<String> choices;

  /// mcq는 정답 보기 텍스트, ox는 "O"/"X", short는 정답 문자열.
  final String answer;
  final String explanation;

  /// 개념 태그
  final String concept;
  final CardStatus status;
  final CardVisibility visibility;
  final List<String> roomIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isVerified => status == CardStatus.verified;

  factory QuizCard.fromMap(String id, Map<String, dynamic> map) {
    return QuizCard(
      id: id,
      ownerId: map['ownerId'] as String? ?? '',
      ownerNickname: map['ownerNickname'] as String? ?? '',
      subjectId: map['subjectId'] as String? ?? '',
      week: readInt(map['week'], 1),
      sourceId: map['sourceId'] as String? ?? '',
      sourceLabel: map['sourceLabel'] as String? ?? '',
      type: readEnum(CardType.values, map['type'], CardType.mcq),
      question: map['question'] as String? ?? '',
      choices: readStringList(map['choices']),
      answer: map['answer'] as String? ?? '',
      explanation: map['explanation'] as String? ?? '',
      concept: map['concept'] as String? ?? '',
      status: readEnum(CardStatus.values, map['status'], CardStatus.draft),
      visibility: readEnum(
        CardVisibility.values,
        map['visibility'],
        CardVisibility.private,
      ),
      roomIds: readStringList(map['roomIds']),
      createdAt: readDate(map['createdAt']),
      updatedAt: readDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'ownerNickname': ownerNickname,
      'subjectId': subjectId,
      'week': week,
      'sourceId': sourceId,
      'sourceLabel': sourceLabel,
      'type': type.name,
      'question': question,
      'choices': choices,
      'answer': answer,
      'explanation': explanation,
      'concept': concept,
      'status': status.name,
      'visibility': visibility.name,
      'roomIds': roomIds,
      'createdAt': writeDate(createdAt),
      'updatedAt': writeDate(updatedAt),
    };
  }

  QuizCard copyWith({
    String? id,
    String? ownerId,
    String? ownerNickname,
    String? subjectId,
    int? week,
    String? sourceId,
    String? sourceLabel,
    CardType? type,
    String? question,
    List<String>? choices,
    String? answer,
    String? explanation,
    String? concept,
    CardStatus? status,
    CardVisibility? visibility,
    List<String>? roomIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuizCard(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerNickname: ownerNickname ?? this.ownerNickname,
      subjectId: subjectId ?? this.subjectId,
      week: week ?? this.week,
      sourceId: sourceId ?? this.sourceId,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      type: type ?? this.type,
      question: question ?? this.question,
      choices: choices ?? this.choices,
      answer: answer ?? this.answer,
      explanation: explanation ?? this.explanation,
      concept: concept ?? this.concept,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      roomIds: roomIds ?? this.roomIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// B가 화면 작업할 때 쓰는 더미 카드. [index]마다 유형(mcq/ox/short)이 바뀐다.
  factory QuizCard.sample([int index = 0]) {
    final now = DateTime(2026, 11, 12);
    final base = QuizCard(
      id: 'sample-$index',
      ownerId: 'sample-user',
      ownerNickname: '승호',
      subjectId: 'sample-subject',
      week: 3,
      sourceId: 'sample-source',
      sourceLabel: '3주차 강의자료.pdf p.12',
      type: CardType.mcq,
      question: 'TCP 3-way handshake에서 두 번째로 보내는 패킷은?',
      choices: const ['SYN', 'SYN+ACK', 'ACK', 'FIN'],
      answer: 'SYN+ACK',
      explanation: '클라이언트 SYN → 서버 SYN+ACK → 클라이언트 ACK 순서다.',
      concept: 'TCP 연결 수립',
      status: CardStatus.verified,
      createdAt: now,
      updatedAt: now,
    );
    switch (index % 3) {
      case 1:
        return base.copyWith(
          ownerNickname: '선우',
          week: 4,
          sourceLabel: '4주차 녹음 23:41',
          type: CardType.ox,
          question: 'UDP는 전송 순서를 보장한다.',
          choices: const [],
          answer: 'X',
          explanation: 'UDP는 순서와 신뢰성을 보장하지 않는다.',
          concept: 'UDP 특징',
        );
      case 2:
        return base.copyWith(
          week: 4,
          sourceLabel: '4주차 강의자료.pdf p.3',
          type: CardType.short,
          question: 'IP 주소를 MAC 주소로 바꿔 주는 프로토콜은?',
          choices: const [],
          answer: 'ARP',
          explanation: 'ARP(Address Resolution Protocol)가 IP → MAC 변환을 한다.',
          concept: 'ARP',
        );
      default:
        return base;
    }
  }
}
