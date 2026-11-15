import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/card_generator.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/models/card.dart';
import 'data/card_repository.dart';

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => CardRepository(FirebaseFirestore.instance),
);

/// Gemini 모델은 만들 때 비용이 있어 한 번만 만든다.
final cardGeneratorProvider = Provider<CardGenerator>((ref) => CardGenerator());

/// 자료 하나로 만든 카드 목록.
final sourceCardsProvider = StreamProvider.family<List<QuizCard>, String>((
  ref,
  sourceId,
) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(cardRepositoryProvider)
      .watchBySource(uid: uid, sourceId: sourceId);
});

/// 과목·주차의 내 카드 (week가 null이면 과목 전체).
final myCardsProvider =
    StreamProvider.family<List<QuizCard>, ({String subjectId, int? week})>((
      ref,
      key,
    ) {
      final uid = ref.watch(uidProvider);
      if (uid == null) return Stream.value(const []);
      return ref
          .watch(cardRepositoryProvider)
          .watchMine(uid: uid, subjectId: key.subjectId, week: key.week);
    });

final cardProvider = StreamProvider.family<QuizCard?, String>(
  (ref, id) => ref.watch(cardRepositoryProvider).watch(id),
);
