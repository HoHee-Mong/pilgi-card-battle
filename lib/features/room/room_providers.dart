import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/room.dart';
import 'room_repository.dart';

/// 내가 들어간 방 목록 (최근 만든 방 먼저). 로그인 전이면 빈 목록.
final myRoomsProvider = StreamProvider<List<Room>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(roomRepositoryProvider).watchMyRooms(uid);
});

/// 사용자가 고른 방 id. 고른 적 없으면 null (→ 가장 최근 방).
class SelectedRoomId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String roomId) => state = roomId;
}

final selectedRoomIdProvider = NotifierProvider<SelectedRoomId, String?>(
  SelectedRoomId.new,
);

/// 지금 보고 있는 방. 고른 방이 목록에 있으면 그 방, 아니면 가장 최근 방.
final currentRoomProvider = Provider<AsyncValue<Room?>>((ref) {
  final selected = ref.watch(selectedRoomIdProvider);
  return ref
      .watch(myRoomsProvider)
      .whenData((rooms) => pickCurrentRoom(rooms, selected));
});

/// [currentRoomProvider]의 고르는 규칙 (테스트용으로 분리)
Room? pickCurrentRoom(List<Room> rooms, String? selectedId) {
  if (rooms.isEmpty) return null;
  for (final r in rooms) {
    if (r.id == selectedId) return r;
  }
  return rooms.first;
}
