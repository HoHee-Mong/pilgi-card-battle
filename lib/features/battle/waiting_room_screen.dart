import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_profile.dart';
import '../../core/models/room.dart';
import '../../core/theme/layout.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/chunky_press.dart';
import '../../core/widgets/stat_chip.dart';
import '../../fx/haptics.dart';
import '../bank/bank_repository.dart';
import '../room/room_repository.dart';
import 'battle_repository.dart';
import 'battle_view.dart';

final _roomProvider = StreamProvider.autoDispose.family<Room?, String>(
  (ref, roomId) => ref.watch(roomRepositoryProvider).watchRoom(roomId),
);

final _bankProvider = StreamProvider.autoDispose
    .family<List<BankEntry>, String>(
      (ref, roomId) => ref.watch(bankRepositoryProvider).watchBank(roomId),
    );

/// 배틀 대기실: 참가자 실시간, 준비, 방장 설정·시작.
///
/// 들어오면 players에 나를 넣고, 나가면(뒤로 가기) 뺀다.
class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  late final BattleRepository _battle = ref.read(battleRepositoryProvider);
  String? _uid;
  bool _starting = false;
  late final AppLifecycleListener _lifecycle;
  String? _error;

  @override
  void initState() {
    super.initState();
    _enter();
    // 앱을 아예 닫으면 대기실·배틀에서 뺀다 (내렸다 돌아오는 건 그대로 둠).
    _lifecycle = AppLifecycleListener(onDetach: _leave);
  }

  void _leave() {
    final uid = _uid;
    if (uid == null) return;
    _uid = null;
    _battle.leave(roomId: widget.roomId, uid: uid).ignore();
  }

  Future<void> _enter() async {
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    _uid = uid;
    try {
      final nickname = await ref
          .read(userProfileRepositoryProvider)
          .ensureNickname(uid);
      await _battle.enter(roomId: widget.roomId, uid: uid, nickname: nickname);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    // 화면을 떠나면 대기실에서 뺀다 (기다리지 않음).
    _leave();
    super.dispose();
  }

  static String _errorText(Object e) => switch (e) {
    BattleException(:final message) => message,
    _ => '문제가 생겼어요. 잠시 후 다시 해 주세요.',
  };

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
    } catch (e) {
      Haptics.medium();
      if (mounted) setState(() => _error = _errorText(e));
    }
  }

  Future<void> _start() async {
    final uid = _uid;
    if (uid == null || _starting) return;
    setState(() => _starting = true);
    await _run(
      () => _battle.start(
        roomId: widget.roomId,
        uid: uid,
        bank: ref.read(bankRepositoryProvider),
      ),
    );
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(_roomProvider(widget.roomId)).value;
    final bank = ref.watch(_bankProvider(widget.roomId)).value ?? const [];
    final uid = _uid ?? ref.watch(uidProvider);

    return Scaffold(
      // 대기실 grape, 배틀 중 ink (보스전 시안), 결과 sun (결과 시안)
      backgroundColor: switch (room?.status) {
        RoomStatus.playing => AppColors.ink,
        RoomStatus.finished => AppColors.sun,
        _ => AppColors.grape,
      },
      body: SafeArea(
        child: room == null || uid == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.paper),
              )
            : _body(room, bank, uid),
      ),
    );
  }

  Widget _body(Room room, List<BankEntry> bank, String uid) {
    if (room.status != RoomStatus.waiting) {
      return BattleView(
        room: room,
        uid: uid,
        onBackToWaiting: () =>
            _run(() => _battle.backToWaiting(roomId: widget.roomId)),
      );
    }
    final isHost = room.isHost(uid);
    final me = room.players[uid];
    final pickable = BankRepository.pickTopVoted(
      bank,
      weeks: room.weeks,
      limit: room.questionCount,
    ).length;
    final blocker = startBlocker(room, uid, bankCount: pickable);
    final weeks = {for (final e in bank) e.week}.toList()..sort();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppLayout.pagePadding(
              context,
              top: AppSpacing.lg,
              bottom: AppSpacing.section,
            ),
            children: [
              Row(
                children: [
                  ChunkyButton(
                    expand: false,
                    color: AppColors.paper,
                    semanticLabel: '대기실 나가기',
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.chevron_left_rounded),
                  ),
                  const Spacer(),
                  StatChip(label: '초대 코드 ${room.code}', color: AppColors.sun),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              Text(
                '배틀 대기실',
                style: AppTextStyles.titleL.copyWith(color: AppColors.paper),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${room.name} · 같은 문제를 동시에 풀어요',
                style: AppTextStyles.label.copyWith(color: AppColors.cream),
              ),
              const SizedBox(height: AppSpacing.section),
              ...[
                _Players(room: room, myUid: uid),
                const SizedBox(height: AppSpacing.section),
                _Settings(
                  room: room,
                  editable: isHost,
                  weeks: weeks,
                  pickable: pickable,
                  onCount: (n) => _run(
                    () => _battle.setSettings(
                      roomId: widget.roomId,
                      questionCount: n,
                    ),
                  ),
                  onWeeks: (w) => _run(
                    () => _battle.setSettings(roomId: widget.roomId, weeks: w),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (room.status == RoomStatus.waiting)
          Padding(
            padding: AppLayout.pagePadding(
              context,
              top: 0,
              bottom: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null || (isHost && blocker != null))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      _error ?? blocker!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.cream,
                      ),
                    ),
                  ),
                if (isHost)
                  ChunkyButton(
                    label: '배틀 시작',
                    large: true,
                    color: AppColors.lime,
                    loading: _starting,
                    onPressed: blocker == null ? _start : null,
                  )
                else
                  ChunkyButton(
                    label: me?.ready == true ? '준비 풀기' : '준비 완료',
                    large: true,
                    color: me?.ready == true ? AppColors.paper : AppColors.lime,
                    onPressed: me == null
                        ? null
                        : () {
                            Haptics.light();
                            _run(
                              () => _battle.setReady(
                                roomId: widget.roomId,
                                uid: uid,
                                ready: !me.ready,
                              ),
                            );
                          },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 참가자 목록: 첫 글자, 닉네임, 방장/나 표시, 준비 상태
class _Players extends StatelessWidget {
  const _Players({required this.room, required this.myUid});

  final Room room;
  final String myUid;

  static const _avatar = AppSpacing.minTouch;

  @override
  Widget build(BuildContext context) {
    // 방장 먼저, 그다음 닉네임 순
    final entries = room.players.entries.toList()
      ..sort((a, b) {
        if (a.key == room.hostId) return -1;
        if (b.key == room.hostId) return 1;
        return a.value.nickname.compareTo(b.value.nickname);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '참가자 ${entries.length}명',
          style: AppTextStyles.heading.copyWith(color: AppColors.paper),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ChunkyCard(
              radius: AppRadius.button,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: _avatar,
                    height: _avatar,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e.key == myUid ? AppColors.lime : AppColors.cyan,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.ink,
                        width: AppBlock.border,
                      ),
                    ),
                    child: Text(
                      e.value.nickname.isEmpty
                          ? '?'
                          : e.value.nickname.characters.first,
                      style: AppTextStyles.chip.copyWith(color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      e.key == myUid
                          ? '${e.value.nickname} (나)'
                          : e.value.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading,
                    ),
                  ),
                  if (e.key == room.hostId)
                    const StatChip(label: '방장', color: AppColors.sun)
                  else
                    StatChip(
                      label: e.value.ready ? '준비 완료' : '준비 중',
                      color: e.value.ready ? AppColors.lime : AppColors.cream,
                    ),
                ],
              ),
            ),
          ),
        if (entries.length < kBattleMinPlayers)
          Text(
            '친구에게 초대 코드 ${room.code}를 알려 주세요',
            style: AppTextStyles.label.copyWith(color: AppColors.cream),
          ),
      ],
    );
  }
}

/// 문항 수·범위. 방장만 바꿀 수 있고, 다른 사람은 보기만.
class _Settings extends StatelessWidget {
  const _Settings({
    required this.room,
    required this.editable,
    required this.weeks,
    required this.pickable,
    required this.onCount,
    required this.onWeeks,
  });

  final Room room;
  final bool editable;

  /// 문제은행에 있는 주차들
  final List<int> weeks;

  /// 지금 설정으로 뽑히는 문제 수
  final int pickable;
  final ValueChanged<int> onCount;
  final ValueChanged<List<int>> onWeeks;

  void _toggleWeek(int w) {
    final next = {...room.weeks};
    if (!next.remove(w)) next.add(w);
    onWeeks(next.toList());
  }

  @override
  Widget build(BuildContext context) {
    final all = room.weeks.isEmpty;
    return ChunkyCard(
      title: editable ? '배틀 설정' : '배틀 설정 (방장이 정해요)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('문항 수', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final n in kBattleQuestionCounts)
                _Choice(
                  label: '$n문제',
                  selected: room.questionCount == n,
                  onTap: editable ? () => onCount(n) : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('범위', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Choice(
                label: '전체',
                selected: all,
                onTap: editable ? () => onWeeks(const []) : null,
              ),
              for (final w in weeks)
                _Choice(
                  label: '$w주',
                  selected: room.weeks.contains(w),
                  onTap: editable ? () => _toggleWeek(w) : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            pickable == 0
                ? '이 범위에는 문제은행 문제가 없어요'
                : pickable < room.questionCount
                ? '투표 많은 순으로 $pickable문제가 나와요 (문제은행에 이만큼 있어요)'
                : '투표 많은 순으로 $pickable문제가 나와요',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.lime : AppColors.paper;
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: ChunkyPress(
        onTap: onTap == null
            ? null
            : () {
                Haptics.selection();
                onTap!();
              },
        color: color,
        radius: AppRadius.chip,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          label,
          style: AppTextStyles.chip.copyWith(color: onChunkyColor(color)),
        ),
      ),
    );
  }
}
