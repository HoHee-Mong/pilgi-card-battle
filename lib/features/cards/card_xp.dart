import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/card.dart';
import '../room/progress_repository.dart';
import '../room/progress_rules.dart';

/// 이번 저장으로 카드가 처음 검수 완료가 됐는지.
/// 새 카드([before]가 null)를 바로 검수 완료로 저장하거나, 초안을 검수 완료로 바꿀 때만 true.
/// (초안 저장, 이미 검수 완료인 카드 수정은 XP 없음 → 같은 카드로 두 번 받지 않는다)
bool becameVerified(CardStatus? before, CardStatus after) =>
    after == CardStatus.verified && before != CardStatus.verified;

/// 카드 [count]장을 만든 XP와 퀘스트("카드 3장 만들기")를 기록한다.
/// 실패해도 카드 저장 흐름은 막지 않는다.
Future<void> recordCardsCreated(WidgetRef ref, int count) async {
  final uid = ref.read(uidProvider);
  if (uid == null || count <= 0) return;
  final progress = ref.read(progressRepositoryProvider);
  for (var i = 0; i < count; i++) {
    await progress.record(uid, XpEvent.cardCreated);
  }
}
