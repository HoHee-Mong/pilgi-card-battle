import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/user_profile.dart';
import '../../core/models/room.dart';
import '../../core/models/subject.dart';
import '../../core/router.dart';
import '../../core/theme/layout.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/boss_sprite.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/outlined_text.dart';
import '../../core/widgets/stat_chip.dart';
import '../../fx/sound.dart';
import '../bank/bank_repository.dart';
import '../subjects/subject_providers.dart';
import '../subjects/subject_utils.dart';
import 'boss_preview_screen.dart';
import 'room_providers.dart';

final _bankCountProvider = StreamProvider.autoDispose.family<int, String>(
  (ref, roomId) => ref
      .watch(bankRepositoryProvider)
      .watchBank(roomId)
      .map((list) => list.length),
);

/// 로비 (시안 `docs/design/game-lobby.png`). grape 배경.
///
/// P1 범위: 이번 보스(가장 가까운 시험), 카드 뽑기, 스터디 방, 모의고사 도전.
/// 레벨·XP·연속 출석·오늘의 퀘스트는 P2에서 추가한다.
class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = ref.watch(nicknameProvider).value ?? '';
    final subjects = ref.watch(mySubjectsProvider).value ?? const <Subject>[];
    final room = ref.watch(currentRoomProvider).value;

    return Scaffold(
      backgroundColor: AppColors.grape,
      body: SafeArea(
        child: ListView(
          padding: AppLayout.pagePadding(
            context,
            top: AppSpacing.lg,
            bottom: AppSpacing.section * 2,
          ),
          children: [
            _Profile(nickname: nickname),
            const SizedBox(height: AppSpacing.section + AppSpacing.sm),
            _BossCard(boss: nextExam(subjects)),
            const SizedBox(height: AppSpacing.section),
            ChunkyButton(
              label: '필기 찍고 카드 뽑기',
              icon: Icons.photo_camera_outlined,
              large: true,
              onPressed: () => context.go(AppRoutes.cards),
            ),
            const SizedBox(height: AppSpacing.section),
            // 두 카드 높이를 맞추려고 최소 높이를 같게 준다 (IntrinsicHeight는 글꼴 측정 차이로 넘칠 수 있음)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _RoomCard(room: room)),
                const SizedBox(width: AppSpacing.md),
                const Expanded(child: _MockCard()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 시험일이 오늘 이후인 과목 중 가장 가까운 것. 없으면 null.
Subject? nextExam(List<Subject> subjects, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final today = DateTime(t.year, t.month, t.day);
  Subject? best;
  for (final s in subjects) {
    final d = s.examDate;
    if (d == null || DateTime(d.year, d.month, d.day).isBefore(today)) continue;
    if (best == null || d.isBefore(best.examDate!)) best = s;
  }
  return best;
}

class _Profile extends StatelessWidget {
  const _Profile({required this.nickname});
  final String nickname;

  static const _avatar = AppSpacing.minTouch + AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final initial = nickname.isEmpty ? '?' : nickname.characters.first;
    return Row(
      children: [
        Container(
          width: _avatar,
          height: _avatar,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.lime,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: AppBlock.border),
          ),
          child: Text(initial, style: AppTextStyles.heading),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nickname.isEmpty ? '반가워요' : nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.heading.copyWith(color: AppColors.paper),
              ),
              Text(
                '오늘도 같이 예상 문제 모아 봐요',
                style: AppTextStyles.label.copyWith(color: AppColors.cream),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const _SoundToggle(),
      ],
    );
  }
}

/// 효과음 켜기/끄기 (설정은 기기에 저장)
class _SoundToggle extends ConsumerWidget {
  const _SoundToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(soundOnProvider);
    return ChunkyButton(
      expand: false,
      color: on ? AppColors.sun : AppColors.paper,
      semanticLabel: on ? '효과음 끄기' : '효과음 켜기',
      onPressed: () async {
        await ref.read(soundOnProvider.notifier).toggle();
        if (!on) Sound.play(Sfx.vote); // 켰을 때 들려주기
      },
      child: Icon(on ? Icons.volume_up_rounded : Icons.volume_off_rounded),
    );
  }
}

/// "이번 보스": 가장 가까운 시험. 없으면 시험일 정하기 안내.
/// 보스를 누르면 한 대 때릴 수 있다 (적중! 연출 맛보기).
class _BossCard extends StatefulWidget {
  const _BossCard({required this.boss});
  final Subject? boss;

  @override
  State<_BossCard> createState() => _BossCardState();
}

class _BossCardState extends State<_BossCard> {
  final _controller = BossController();

  static const _bossSize = AppSpacing.minTouch * 2.2;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boss = widget.boss;
    final dday = examDDayLabel(boss?.examDate);
    return ChunkyCard(
      onTap: boss == null ? () => context.go(AppRoutes.cards) : null,
      // 개발용: 길게 누르면 보스 연출 미리보기 (배포 빌드에서는 꺼짐)
      onLongPress: kDebugMode
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BossPreviewScreen(),
              ),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StatChip(
                  label: '이번 보스',
                  color: AppColors.pink,
                  border: false,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  boss?.name ?? '아직 보스가 없어요',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleM,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  boss == null
                      ? '내 카드에서 과목 시험일을 정하면 나타나요'
                      : '시험일 ${boss.examDate!.month}월 ${boss.examDate!.day}일',
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ),
          if (boss != null && dday != null) ...[
            const SizedBox(width: AppSpacing.md),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BossSprite(
                  hp: 1,
                  maxHp: 1,
                  size: _bossSize,
                  controller: _controller,
                  onTap: _controller.hit,
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedText(
                  dday,
                  style: AppTextStyles.titleM,
                  color: AppColors.pink,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomCard extends ConsumerWidget {
  const _RoomCard({required this.room});
  final Room? room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = this.room;
    final count = room == null
        ? null
        : ref.watch(_bankCountProvider(room.id)).value;
    final names = room == null
        ? const <String>[]
        : [for (final p in room.players.values) p.nickname];

    return ChunkyCard(
      color: AppColors.lime,
      onTap: () => context.go(AppRoutes.bank),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _smallCardMinHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room?.name ?? '스터디 방',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading,
            ),
            const SizedBox(height: AppSpacing.md),
            if (names.isNotEmpty) ...[
              _Faces(names: names),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              room == null
                  ? '방을 만들어 친구를 불러요'
                  : '${room.memberIds.length}명 · 예상 문제 ${count ?? 0}개',
              style: AppTextStyles.label.copyWith(color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// 로비 아래 두 카드의 최소 내용 높이
const _smallCardMinHeight = AppSpacing.minTouch * 3;

/// 참가자 첫 글자 동그라미를 겹쳐 놓은 줄 (최대 4명)
class _Faces extends StatelessWidget {
  const _Faces({required this.names});
  final List<String> names;

  static const _size = AppSpacing.minTouch;
  static const _colors = [
    AppColors.sun,
    AppColors.cyan,
    AppColors.pink,
    AppColors.paper,
  ];

  @override
  Widget build(BuildContext context) {
    final shown = names.take(_colors.length).toList();
    return SizedBox(
      height: _size,
      width: _size + (shown.length - 1) * _size * 0.7,
      child: Stack(
        children: [
          for (final (i, name) in shown.indexed)
            Positioned(
              left: i * _size * 0.7,
              child: Container(
                width: _size,
                height: _size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.ink,
                    width: AppBlock.border,
                  ),
                ),
                child: Text(
                  name.isEmpty ? '?' : name.characters.first,
                  style: AppTextStyles.chip.copyWith(color: AppColors.ink),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MockCard extends StatelessWidget {
  const _MockCard();

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      color: AppColors.cyan,
      onTap: () => context.go(AppRoutes.mock),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _smallCardMinHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('모의고사 도전', style: AppTextStyles.heading),
            const SizedBox(height: AppSpacing.md),
            const Icon(
              Icons.edit_outlined,
              color: AppColors.ink,
              size: AppSpacing.minTouch * 0.7,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '표 많은 문제로 풀어 봐요',
              style: AppTextStyles.label.copyWith(color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}
