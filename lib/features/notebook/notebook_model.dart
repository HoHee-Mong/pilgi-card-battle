import 'dart:collection';

import '../../core/models/card.dart';
import '../../core/models/room.dart';

/// 족보 노트에서 보는 카드 범위.
enum NotebookScope {
  /// 내가 만든 카드 (초안 포함)
  mine,

  /// 같은 과목 방 문제은행에 올라온 카드 (친구 것 포함, 투표 수 표시)
  room,
}

/// 내 카드 검수 상태 필터.
enum NotebookStatus { all, verified, draft }

/// 방 카드 한 장: 카드 본문 + 문제은행 항목(투표) + 그 방.
typedef RoomCard = ({QuizCard card, BankEntry entry, Room room});

List<QuizCard> filterByStatus(List<QuizCard> cards, NotebookStatus status) {
  return switch (status) {
    NotebookStatus.all => cards,
    NotebookStatus.verified => cards.where((c) => c.isVerified).toList(),
    NotebookStatus.draft => cards.where((c) => !c.isVerified).toList(),
  };
}

/// 주차 오름차순으로 묶는다. 같은 주차 안의 순서는 [items] 순서를 지킨다.
SplayTreeMap<int, List<T>> groupByWeek<T>(
  Iterable<T> items,
  int Function(T) weekOf,
) {
  final map = SplayTreeMap<int, List<T>>();
  for (final it in items) {
    map.putIfAbsent(weekOf(it), () => []).add(it);
  }
  return map;
}

/// 여러 방에 같은 카드가 올라가 있으면 투표가 가장 많은 방의 항목만 남긴다.
/// 결과 키는 cardId.
Map<String, ({BankEntry entry, Room room})> pickBestEntries(
  Iterable<({BankEntry entry, Room room})> items,
) {
  final best = <String, ({BankEntry entry, Room room})>{};
  for (final it in items) {
    final prev = best[it.entry.cardId];
    if (prev == null || it.entry.voteCount > prev.entry.voteCount) {
      best[it.entry.cardId] = it;
    }
  }
  return best;
}
