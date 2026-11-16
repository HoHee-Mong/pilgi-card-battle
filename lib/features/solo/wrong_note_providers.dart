import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/card.dart';
import '../bank/bank_repository.dart';
import '../cards/card_providers.dart';
import 'solo_providers.dart';
import 'wrong_note_model.dart';

/// 과목의 오답 노트 (카드 본문 포함). 풀이 기록이 바뀌면 다시 계산한다.
///
/// 배틀에서 틀린 친구 카드는 내 카드 목록에 없으므로 `cards` 컬렉션에서 따로 읽는다.
final wrongNoteProvider = FutureProvider.family<List<WrongCard>, String>((
  ref,
  subjectId,
) async {
  final attempts =
      ref.watch(subjectAttemptsProvider(subjectId)).value ?? const [];
  final entries = buildWrongNote(attempts);
  if (entries.isEmpty) return const [];

  final mine =
      ref.watch(myCardsProvider((subjectId: subjectId, week: null))).value ??
      const <QuizCard>[];
  final byId = {for (final c in mine) c.id: c};
  final missing = [
    for (final e in entries)
      if (!byId.containsKey(e.cardId)) e.cardId,
  ];
  if (missing.isNotEmpty) {
    final fetched = await ref.read(bankRepositoryProvider).cardsByIds(missing);
    for (final c in fetched) {
      byId[c.id] = c;
    }
  }
  return [
    for (final e in entries)
      if (byId[e.cardId] != null) (card: byId[e.cardId]!, entry: e),
  ];
});
