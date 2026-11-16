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

/// 지금 보고 있는 방. 방 고르기 화면이 생기기 전까지는 가장 최근 방.
final currentRoomProvider = Provider<AsyncValue<Room?>>((ref) {
  return ref
      .watch(myRoomsProvider)
      .whenData((rooms) => rooms.isEmpty ? null : rooms.first);
});
