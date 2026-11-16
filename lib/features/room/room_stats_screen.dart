import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/room.dart';
import '../../core/theme/layout.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/stat_chip.dart';
import '../bank/bank_repository.dart';
import 'room_stats.dart';

final _bankProvider = StreamProvider.autoDispose
    .family<List<BankEntry>, String>(
      (ref, roomId) => ref.watch(bankRepositoryProvider).watchBank(roomId),
    );

/// 우리 방 기록 (P2): 예상 적중왕(받은 표), 내 기여도, 모의고사 점수 비교.
class RoomStatsScreen extends ConsumerWidget {
  const RoomStatsScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  final String roomId;
  final String roomName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final bank = ref.watch(_bankProvider(roomId)).value ?? const <BankEntry>[];
    final exams = ref.watch(roomMockExamsProvider(roomId)).value ?? const [];
    final contributors = rankContributors(bank);
    final mocks = rankMockExams(exams);
    final me = contributors.where((c) => c.uid == myUid).firstOrNull;
    final king = contributors.isNotEmpty && contributors.first.votes > 0
        ? contributors.first
        : null;

    return Scaffold(
      backgroundColor: AppColors.sun,
      body: SafeArea(
        child: ListView(
          padding: AppLayout.pagePadding(
            context,
            top: AppSpacing.lg,
            bottom: AppSpacing.section * 2,
          ),
          children: [
            Row(
              children: [
                ChunkyButton(
                  expand: false,
                  color: AppColors.paper,
                  semanticLabel: '뒤로',
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Icon(Icons.chevron_left_rounded),
                ),
                const Spacer(),
                Flexible(
                  child: StatChip(label: roomName, color: AppColors.paper),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            const Text('우리 방 기록', style: AppTextStyles.titleL),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              '표는 친구들의 예상일 뿐, 출제 보장은 아니에요',
              style: AppTextStyles.label,
            ),
            const SizedBox(height: AppSpacing.section),
            _KingCard(king: king, myUid: myUid),
            const SizedBox(height: AppSpacing.section),
            ChunkyCard(
              title: '내 기여도',
              child: Text(
                me == null
                    ? '아직 문제은행에 올린 카드가 없어요'
                    : '카드 ${me.cards}장을 올렸고, 친구들이 ${me.votes}번 나올 것 같대요',
                style: AppTextStyles.bodyS,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            ChunkyCard(
              title: '받은 표 순위',
              child: contributors.isEmpty
                  ? const Text('아직 올라온 카드가 없어요', style: AppTextStyles.bodyS)
                  : Column(
                      children: [
                        for (final (i, c) in contributors.indexed)
                          _RankRow(
                            rank: i + 1,
                            name: c.uid == myUid
                                ? '${c.nickname} (나)'
                                : c.nickname,
                            value: '표 ${c.votes}',
                            sub: '카드 ${c.cards}장',
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.section),
            ChunkyCard(
              title: '모의고사 점수 비교',
              child: mocks.isEmpty
                  ? const Text('아직 모의고사를 푼 사람이 없어요', style: AppTextStyles.bodyS)
                  : Column(
                      children: [
                        for (final (i, m) in mocks.indexed)
                          _RankRow(
                            rank: i + 1,
                            name: m.uid == myUid
                                ? '${m.nickname} (나)'
                                : m.nickname,
                            value: '${m.score}/${m.total}',
                            sub: '최고 ${m.percent}% · ${m.tries}번',
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 예상 적중왕: 받은 표가 가장 많은 사람 (시안 결과 화면의 어두운 카드)
class _KingCard extends StatelessWidget {
  const _KingCard({required this.king, required this.myUid});

  final Contributor? king;
  final String? myUid;

  static const _avatar = AppSpacing.minTouch * 1.5;

  @override
  Widget build(BuildContext context) {
    final king = this.king;
    return ChunkyCard(
      color: AppColors.ink,
      shadowColor: AppColors.grape,
      child: Row(
        children: [
          Container(
            width: _avatar,
            height: _avatar,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.pink,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.sun, width: AppBlock.border),
            ),
            child: Text(
              king == null || king.nickname.isEmpty
                  ? '?'
                  : king.nickname.characters.first,
              style: AppTextStyles.heading,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '예상 적중왕',
                  style: AppTextStyles.chip.copyWith(color: AppColors.sun),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (king == null)
                  Text(
                    '아직 없어요. 표를 많이 받으면 왕관!',
                    style: AppTextStyles.bodyS.copyWith(color: AppColors.paper),
                  )
                else ...[
                  Text(
                    king.uid == myUid ? '${king.nickname} (나)' : king.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleM.copyWith(
                      color: AppColors.paper,
                    ),
                  ),
                  Text(
                    '받은 표 ${king.votes}개 · 카드 ${king.cards}장',
                    style: AppTextStyles.label.copyWith(color: AppColors.cream),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.value,
    required this.sub,
  });

  final int rank;
  final String name;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.minTouch,
            child: Text('$rank위', style: AppTextStyles.chip),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(sub, style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(value, style: AppTextStyles.chip),
        ],
      ),
    );
  }
}
