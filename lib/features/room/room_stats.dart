import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/mock_exam.dart';
import '../../core/models/room.dart';

/// 예상 적중왕 후보 한 명: 내가 올린 카드들이 받은 "나올 것 같아요" 합계
class Contributor {
  const Contributor({
    required this.uid,
    required this.nickname,
    required this.votes,
    required this.cards,
  });

  final String uid;
  final String nickname;

  /// 받은 표 합계
  final int votes;

  /// 문제은행에 올린 카드 수
  final int cards;
}

/// 문제은행 → 작성자별 받은 표 (많은 순, 같으면 카드 많은 순, 그다음 이름순).
List<Contributor> rankContributors(List<BankEntry> entries) {
  final votes = <String, int>{};
  final cards = <String, int>{};
  final names = <String, String>{};
  for (final e in entries) {
    votes[e.addedBy] = (votes[e.addedBy] ?? 0) + e.voteCount;
    cards[e.addedBy] = (cards[e.addedBy] ?? 0) + 1;
    if (e.addedByNickname.isNotEmpty) names[e.addedBy] = e.addedByNickname;
  }
  final list = [
    for (final uid in votes.keys)
      Contributor(
        uid: uid,
        nickname: names[uid] ?? '친구',
        votes: votes[uid]!,
        cards: cards[uid]!,
      ),
  ];
  list.sort((a, b) {
    final v = b.votes.compareTo(a.votes);
    if (v != 0) return v;
    final c = b.cards.compareTo(a.cards);
    return c != 0 ? c : a.nickname.compareTo(b.nickname);
  });
  return list;
}

/// 모의고사 점수 비교 한 줄: 한 사람의 최고 기록
class MockBest {
  const MockBest({
    required this.uid,
    required this.nickname,
    required this.score,
    required this.total,
    required this.tries,
  });

  final String uid;
  final String nickname;
  final int score;
  final int total;

  /// 제출한 횟수
  final int tries;

  /// 맞힌 비율 0~100 (문항 수가 달라도 비교되게)
  int get percent => total == 0 ? 0 : (score * 100 / total).round();
}

/// 제출한 모의고사만 모아 사람별 최고 비율 기록 (높은 순).
List<MockBest> rankMockExams(List<MockExam> exams) {
  final best = <String, MockExam>{};
  final tries = <String, int>{};
  double ratio(MockExam e) => e.total == 0 ? 0 : e.score / e.total;
  for (final e in exams) {
    if (!e.isSubmitted) continue;
    tries[e.uid] = (tries[e.uid] ?? 0) + 1;
    final prev = best[e.uid];
    if (prev == null || ratio(e) > ratio(prev)) best[e.uid] = e;
  }
  final list = [
    for (final e in best.values)
      MockBest(
        uid: e.uid,
        nickname: e.nickname.isEmpty ? '친구' : e.nickname,
        score: e.score,
        total: e.total,
        tries: tries[e.uid]!,
      ),
  ];
  list.sort((a, b) {
    final p = b.percent.compareTo(a.percent);
    return p != 0 ? p : b.total.compareTo(a.total);
  });
  return list;
}

/// 방의 모의고사 기록 (A가 `rooms/{roomId}/mockExams`에 쓴다. B는 읽기만)
final roomMockExamsProvider = StreamProvider.autoDispose
    .family<List<MockExam>, String>((ref, roomId) {
      return FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('mockExams')
          .snapshots()
          .map(
            (snap) => [
              for (final d in snap.docs) MockExam.fromMap(d.id, d.data()),
            ],
          );
    });
