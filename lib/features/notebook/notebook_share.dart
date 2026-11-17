import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/card.dart';
import '../../core/models/model_utils.dart';
import '../../core/models/source.dart';
import '../../core/models/subject.dart';
import '../cards/data/card_repository.dart';
import '../sources/data/source_repository.dart';
import 'notebook_export.dart';

/// 공유 족보 안의 카드 한 장 (카드 본문만, 내 계정 정보·방 정보 없음).
class SharedCard {
  const SharedCard({
    required this.week,
    required this.type,
    required this.question,
    this.choices = const [],
    required this.answer,
    this.explanation = '',
    this.concept = '',
    this.sourceLabel = '',
    this.verified = false,
    this.author = '',
    this.votes,
  });

  final int week;
  final CardType type;
  final String question;
  final List<String> choices;
  final String answer;
  final String explanation;
  final String concept;
  final String sourceLabel;
  final bool verified;

  /// 카드를 만든 사람 이름 (방 카드일 때)
  final String author;

  /// "나올 것 같아요" 수 (방 카드일 때)
  final int? votes;

  factory SharedCard.fromExport(ExportCard c) => SharedCard(
    week: c.card.week,
    type: c.card.type,
    question: c.card.question,
    choices: c.card.choices,
    answer: c.card.answer,
    explanation: c.card.explanation,
    concept: c.card.concept,
    sourceLabel: c.card.sourceLabel,
    verified: c.card.isVerified,
    author: c.author ?? '',
    votes: c.votes,
  );

  factory SharedCard.fromMap(Map<String, dynamic> m) => SharedCard(
    week: readInt(m['week'], 1),
    type: readEnum(CardType.values, m['type'], CardType.mcq),
    question: m['question'] as String? ?? '',
    choices: readStringList(m['choices']),
    answer: m['answer'] as String? ?? '',
    explanation: m['explanation'] as String? ?? '',
    concept: m['concept'] as String? ?? '',
    sourceLabel: m['sourceLabel'] as String? ?? '',
    verified: m['verified'] as bool? ?? false,
    author: m['author'] as String? ?? '',
    votes: (m['votes'] as num?)?.toInt(),
  );

  Map<String, dynamic> toMap() => {
    'week': week,
    'type': type.name,
    'question': question,
    'choices': choices,
    'answer': answer,
    'explanation': explanation,
    'concept': concept,
    'sourceLabel': sourceLabel,
    'verified': verified,
    'author': author,
    if (votes != null) 'votes': votes,
  };

  /// 받는 사람의 카드로 만든다. 검수 상태는 보낸 사람 것을 따른다.
  QuizCard toQuizCard({
    required String id,
    required String ownerId,
    required String ownerNickname,
    required String subjectId,
    required String sourceId,
    required String from,
    required DateTime now,
  }) => QuizCard(
    id: id,
    ownerId: ownerId,
    ownerNickname: ownerNickname,
    subjectId: subjectId,
    week: week,
    sourceId: sourceId,
    sourceLabel: sourceLabel.isEmpty ? '$from 족보' : '$from 족보 · $sourceLabel',
    type: type,
    question: question,
    choices: choices,
    answer: answer,
    explanation: explanation,
    concept: concept,
    status: verified ? CardStatus.verified : CardStatus.draft,
    createdAt: now,
    updatedAt: now,
  );
}

/// `shares/{code}` — 공유 링크로 보내는 족보 한 묶음.
/// 보내는 순간의 카드를 복사해 두므로, 나중에 원래 카드를 고치거나 지워도 바뀌지 않는다.
/// 원본 파일(PDF·녹음·사진)은 들어가지 않는다.
class NotebookShare {
  const NotebookShare({
    required this.code,
    required this.ownerId,
    required this.ownerNickname,
    required this.subjectName,
    required this.scope,
    required this.summaries,
    required this.cards,
    required this.createdAt,
  });

  /// 6자리 공유 코드 = 문서 ID
  final String code;
  final String ownerId;
  final String ownerNickname;
  final String subjectName;
  final ExportScope scope;
  final List<ExportSummary> summaries;
  final List<SharedCard> cards;
  final DateTime createdAt;

  /// 한 번에 공유할 수 있는 카드 수 (Firestore 문서 1MB 제한 안쪽)
  static const maxCards = 500;

  List<int> get weeks => {for (final c in cards) c.week}.toList()..sort();

  factory NotebookShare.fromMap(String code, Map<String, dynamic> m) =>
      NotebookShare(
        code: code,
        ownerId: m['ownerId'] as String? ?? '',
        ownerNickname: m['ownerNickname'] as String? ?? '',
        subjectName: m['subjectName'] as String? ?? '',
        scope: readEnum(ExportScope.values, m['scope'], ExportScope.myVerified),
        summaries: [
          for (final s in (m['summaries'] as List? ?? const []))
            if (s is Map)
              (
                week: readInt(s['week'], 1),
                label: s['label'] as String? ?? '',
                summary: s['summary'] as String? ?? '',
              ),
        ],
        cards: [
          for (final c in (m['cards'] as List? ?? const []))
            if (c is Map) SharedCard.fromMap(Map<String, dynamic>.from(c)),
        ],
        createdAt: readDate(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
    'ownerId': ownerId,
    'ownerNickname': ownerNickname,
    'subjectName': subjectName,
    'scope': scope.name,
    'summaries': [
      for (final s in summaries)
        {'week': s.week, 'label': s.label, 'summary': s.summary},
    ],
    'cards': [for (final c in cards) c.toMap()],
    'cardCount': cards.length,
    'createdAt': writeDate(createdAt),
  };

  /// PDF·텍스트로 받을 때. 정답·해설 포함.
  NotebookExport toExport({bool withAnswers = true}) => NotebookExport.build(
    subjectName: subjectName,
    scope: ExportScope.shared,
    withAnswers: withAnswers,
    summaries: summaries,
    cards: [
      for (final (i, c) in cards.indexed)
        (
          card: c
              .toQuizCard(
                id: '$i',
                ownerId: '',
                ownerNickname: '',
                subjectId: '',
                sourceId: '',
                from: ownerNickname,
                now: createdAt,
              )
              .copyWith(sourceLabel: c.sourceLabel),
          votes: c.votes,
          author: c.author.isEmpty ? null : c.author,
        ),
    ],
  );
}

/// 웹 주소로 열면 바로 받는 화면으로 가는 링크. 앱(폰)에서는 코드만 쓴다.
String? shareLinkFor(String code) {
  if (!kIsWeb) return null;
  return '${Uri.base.origin}/#/share/$code';
}

/// 링크·코드 어느 쪽을 붙여 넣어도 6자리 코드를 꺼낸다. 없으면 null.
String? parseShareCode(String input) {
  final t = input.trim().toUpperCase();
  final m = RegExp(r'/SHARE/([A-Z0-9]{6})').firstMatch(t);
  if (m != null) return m.group(1);
  final plain = t.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return plain.length == 6 ? plain : null;
}

class ShareException implements Exception {
  const ShareException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ShareRepository {
  ShareRepository(this._db, {Random? random})
    : _rng = random ?? Random.secure();

  final FirebaseFirestore _db;
  final Random _rng;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('shares');

  /// 방 초대 코드와 같은 글자 (헷갈리는 0·O·1·I·L 뺌)
  static const _codeChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  String _newCode() => List.generate(
    6,
    (_) => _codeChars[_rng.nextInt(_codeChars.length)],
  ).join();

  /// 공유 족보를 만들고 코드를 돌려준다. 겹치는 코드면 다시 뽑는다.
  Future<NotebookShare> create({
    required String uid,
    required String nickname,
    required NotebookExport export,
    required List<ExportSummary> summaries,
  }) async {
    final cards = [
      for (final w in export.weeks)
        for (final c in w.cards) SharedCard.fromExport(c),
    ];
    if (cards.isEmpty) throw const ShareException('공유할 카드가 없어요.');
    if (cards.length > NotebookShare.maxCards) {
      throw const ShareException(
        '카드가 너무 많아요 (${NotebookShare.maxCards}장까지). 범위를 줄여 주세요.',
      );
    }
    final weeks = {for (final c in cards) c.week};
    for (var tries = 0; tries < 5; tries++) {
      final code = _newCode();
      final share = NotebookShare(
        code: code,
        ownerId: uid,
        ownerNickname: nickname,
        subjectName: export.subjectName,
        scope: export.scope,
        summaries: [
          for (final s in summaries)
            if (weeks.contains(s.week)) s,
        ],
        cards: cards,
        createdAt: DateTime.now(),
      );
      final ref = _col.doc(code);
      final created = await _db.runTransaction((tx) async {
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, share.toMap());
        return true;
      });
      if (created) return share;
    }
    throw const ShareException('공유 코드를 만들지 못했어요. 다시 해 주세요.');
  }

  Future<NotebookShare?> get(String code) async {
    final d = await _col.doc(code.toUpperCase()).get();
    return d.exists ? NotebookShare.fromMap(d.id, d.data()!) : null;
  }

  /// 받은 족보를 내 과목에 카드로 넣는다. 주차별 요약은 자료 기록으로 넣어
  /// 족보 노트에 같이 보이게 한다. 넣은 카드 수를 돌려준다.
  Future<int> importInto({
    required NotebookShare share,
    required Subject subject,
    required String uid,
    required String nickname,
    required CardRepository cards,
    required SourceRepository sources,
  }) async {
    final now = DateTime.now();
    final from = share.ownerNickname.isEmpty ? '친구' : share.ownerNickname;
    // 주차마다 자료 기록 하나 (요약이 없으면 빈 요약)
    final sourceIdByWeek = <int, String>{};
    for (final week in share.weeks) {
      final sum = share.summaries
          .where((s) => s.week == week)
          .map((s) => s.summary)
          .join('\n\n');
      final id = sources.newId();
      sourceIdByWeek[week] = id;
      await sources.create(
        StudySource(
          id: id,
          ownerId: uid,
          subjectId: subject.id,
          week: week,
          kind: SourceKind.pdf,
          fileName: '$from님이 공유한 족보',
          status: SourceStatus.done,
          summary: sum.isEmpty ? null : sum,
          createdAt: now,
        ),
      );
    }
    final list = [
      for (final c in share.cards)
        c.toQuizCard(
          id: cards.newId(),
          ownerId: uid,
          ownerNickname: nickname,
          subjectId: subject.id,
          sourceId: sourceIdByWeek[c.week] ?? '',
          from: from,
          now: now,
        ),
    ];
    await cards.createAll(list);
    return list.length;
  }
}

final shareRepositoryProvider = Provider<ShareRepository>(
  (ref) => ShareRepository(FirebaseFirestore.instance),
);

/// 공유 코드로 족보 한 묶음 읽기.
final sharedNotebookProvider = FutureProvider.autoDispose
    .family<NotebookShare?, String>(
      (ref, code) => ref.watch(shareRepositoryProvider).get(code),
    );
