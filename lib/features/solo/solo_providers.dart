import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/attempt.dart';
import '../../core/models/card_meta.dart';
import 'data/attempt_repository.dart';

final attemptRepositoryProvider = Provider<AttemptRepository>(
  (ref) => AttemptRepository(FirebaseFirestore.instance),
);

/// 내 카드 상태 전체 (cardId → meta). 로그인 전이면 빈 맵.
final cardMetaProvider = StreamProvider<Map<String, CardMeta>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(attemptRepositoryProvider).watchMeta(uid);
});

/// 과목의 내 풀이 기록 (최신순).
final subjectAttemptsProvider = StreamProvider.family<List<Attempt>, String>((
  ref,
  subjectId,
) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(attemptRepositoryProvider)
      .watchBySubject(uid: uid, subjectId: subjectId);
});
