import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/room.dart';
import '../../core/models/source.dart';
import '../bank/bank_repository.dart';
import '../room/room_providers.dart';
import '../sources/source_providers.dart';
import 'notebook_model.dart';

/// 과목 전체 자료 (요약·출처 목록용). 로그인 전이면 빈 목록.
final subjectSourcesProvider = StreamProvider.family<List<StudySource>, String>(
  (ref, subjectId) {
    final uid = ref.watch(uidProvider);
    if (uid == null) return Stream.value(const []);
    return ref
        .watch(sourceRepositoryProvider)
        .watchSubject(uid: uid, subjectId: subjectId);
  },
);

/// 내가 들어간 방 중 이 과목 방들 (B의 [myRoomsProvider] 사용).
final subjectRoomsProvider = Provider.family<List<Room>, String>((
  ref,
  subjectId,
) {
  final rooms = ref.watch(myRoomsProvider).value ?? const [];
  return rooms.where((r) => r.subjectId == subjectId).toList();
});

/// 방 하나의 문제은행 (주차순).
final roomBankProvider = StreamProvider.family<List<BankEntry>, String>(
  (ref, roomId) =>
      ref.watch(bankRepositoryProvider).watchBank(roomId, sort: BankSort.week),
);

/// 이 과목 방들에 올라온 카드 전부 (카드 본문 포함, 같은 카드는 한 번만).
/// 방 문제은행이 바뀌면 다시 읽는다.
final roomCardsProvider = FutureProvider.family<List<RoomCard>, String>((
  ref,
  subjectId,
) async {
  final rooms = ref.watch(subjectRoomsProvider(subjectId));
  final best = pickBestEntries([
    for (final room in rooms)
      for (final entry
          in ref.watch(roomBankProvider(room.id)).value ?? const [])
        (entry: entry, room: room),
  ]);
  if (best.isEmpty) return const [];
  final cards = await ref
      .read(bankRepositoryProvider)
      .cardsByIds(best.keys.toList());
  return [
    for (final c in cards)
      (card: c, entry: best[c.id]!.entry, room: best[c.id]!.room),
  ];
});
