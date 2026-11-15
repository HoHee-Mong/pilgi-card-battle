import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_profile.dart';
import '../../core/models/card.dart';
import '../../core/models/room.dart';
import '../../core/theme/tokens.dart';
import '../bank/bank_repository.dart';
import '../room/room_repository.dart';

/// 내가 들어간 방 목록 (B의 RoomRepository 사용). 로그인 전이면 빈 목록.
final myRoomsProvider = StreamProvider<List<Room>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(roomRepositoryProvider).watchMyRooms(uid);
});

/// 검수 완료한 카드를 방 문제은행에 공유한다 (B의 `BankRepository.addCard`).
/// 공유한 방 ID를 돌려준다. 취소하면 null.
Future<String?> showShareToRoomSheet(
  BuildContext context, {
  required QuizCard card,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => _ShareSheet(card: card),
  );
}

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.card});

  final QuizCard card;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  String? _busyRoomId;

  /// 이번 시트에서 방금 공유한 방 (카드 스트림이 갱신되기 전에도 표시)
  final Set<String> _justShared = {};

  Future<void> _share(Room room) async {
    if (_busyRoomId != null) return;
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    setState(() => _busyRoomId = room.id);
    try {
      final nickname = await ref
          .read(userProfileRepositoryProvider)
          .ensureNickname(uid);
      await ref
          .read(bankRepositoryProvider)
          .addCard(
            roomId: room.id,
            card: widget.card,
            uid: uid,
            nickname: nickname,
          );
      if (!mounted) return;
      setState(() => _justShared.add(room.id));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"${room.name}" 문제은행에 올렸어요')));
      Navigator.of(context).pop(room.id);
    } on BankException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('공유하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _busyRoomId = null);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(myRoomsProvider);
    final card = widget.card;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.section,
        AppSpacing.page,
        AppSpacing.page + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('방에 공유', style: AppTextStyles.titleM),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '친구들이 "나올 것 같아요"를 누를 수 있게 문제은행에 올려요.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sectionTight),
          if (!card.isVerified)
            Text(
              '검수 완료한 카드만 공유할 수 있어요. 먼저 검수를 끝내 주세요.',
              style: AppTextStyles.body.copyWith(color: AppColors.inkSub),
            )
          else
            rooms.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.section),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('방 목록을 불러오지 못했어요\n$e'),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    '들어간 스터디 방이 없어요.\n문제은행 탭에서 방을 만들거나 초대 코드로 들어가세요.',
                    style: AppTextStyles.body.copyWith(color: AppColors.inkSub),
                  );
                }
                // 같은 과목 방을 위로
                final sorted = [...list]
                  ..sort((a, b) {
                    final sa = a.subjectId == card.subjectId ? 0 : 1;
                    final sb = b.subjectId == card.subjectId ? 0 : 1;
                    return sa.compareTo(sb);
                  });
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final room = sorted[i];
                      final shared =
                          card.roomIds.contains(room.id) ||
                          _justShared.contains(room.id);
                      final busy = _busyRoomId == room.id;
                      final sameSubject = room.subjectId == card.subjectId;
                      return _RoomRow(
                        room: room,
                        shared: shared,
                        busy: busy,
                        sameSubject: sameSubject,
                        onTap: shared || busy ? null : () => _share(room),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.room,
    required this.shared,
    required this.busy,
    required this.sameSubject,
    required this.onTap,
  });

  final Room room;
  final bool shared;
  final bool busy;
  final bool sameSubject;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: shared ? AppColors.lime : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name, style: AppTextStyles.heading),
                    Text(
                      '${room.memberIds.length}명 · 코드 ${room.code}'
                      '${sameSubject ? '' : ' · 다른 과목'}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  shared ? '공유됨' : '공유',
                  style: AppTextStyles.button.copyWith(color: AppColors.ink),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
