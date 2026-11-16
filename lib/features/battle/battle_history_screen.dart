import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/theme/layout.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/rank_stamp.dart';
import '../../core/widgets/stat_chip.dart';
import 'battle_record.dart';
import 'battle_repository.dart';

final _recordsProvider = StreamProvider.autoDispose<List<BattleRecord>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(battleRepositoryProvider).watchRecords(uid);
});

const _outcomeText = {
  BattleOutcome.win: '승리',
  BattleOutcome.lose: '패배',
  BattleOutcome.draw: '무승부',
};

const _outcomeColor = {
  BattleOutcome.win: AppColors.lime,
  BattleOutcome.lose: AppColors.wrong,
  BattleOutcome.draw: AppColors.cyan,
};

String _date(DateTime d) =>
    '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

String _opponentText(BattleRecord r) {
  if (r.opponents.isEmpty) return '상대 없음';
  final names = [
    for (final o in r.opponents) o.nickname.isEmpty ? '친구' : o.nickname,
  ];
  return 'vs ${names.join(', ')}';
}

/// 내 배틀 기록 목록 (최근 순). 읽기만 하고 아무것도 저장하지 않는다.
class BattleHistoryScreen extends ConsumerWidget {
  const BattleHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(_recordsProvider);
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: const Text('내 배틀 기록', style: AppTextStyles.heading),
      ),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _Empty('기록을 불러오지 못했어요.'),
        data: (list) => list.isEmpty
            ? const _Empty('아직 배틀 기록이 없어요.\n친구랑 한 판 해 보세요!')
            : ListView(
                padding: AppLayout.pagePadding(
                  context,
                  top: AppSpacing.sm,
                  bottom: AppSpacing.section * 2,
                ),
                children: [
                  for (final r in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ChunkyCard(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BattleRecordScreen(record: r),
                          ),
                        ),
                        child: Row(
                          children: [
                            StatChip(
                              label: _outcomeText[r.outcome]!,
                              color: _outcomeColor[r.outcome]!,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _opponentText(r),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.heading,
                                  ),
                                  Text(
                                    '${_date(r.at)} · ${r.roomName.isEmpty ? '스터디 방' : r.roomName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.caption,
                                  ),
                                  Text(
                                    '${r.myScore}점 · 정답률 ${r.percent}% · 최고 콤보 x${r.bestCombo}',
                                    style: AppTextStyles.label,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// 배틀 기록 한 판 자세히
class BattleRecordScreen extends StatelessWidget {
  const BattleRecordScreen({super.key, required this.record});

  final BattleRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: Text(_date(r.at), style: AppTextStyles.heading),
      ),
      body: ListView(
        padding: AppLayout.pagePadding(
          context,
          top: AppSpacing.sm,
          bottom: AppSpacing.section * 2,
        ),
        children: [
          Center(child: RankStamp(rank: r.grade)),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: StatChip(
              label: '${_outcomeText[r.outcome]!} · ${r.rank}위',
              color: _outcomeColor[r.outcome]!,
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          ChunkyCard(
            title: '요약',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line('방', r.roomName.isEmpty ? '스터디 방' : r.roomName),
                _line('상대', _opponentText(r)),
                _line('내 점수', '${r.myScore}점'),
                for (final o in r.opponents)
                  _line(o.nickname.isEmpty ? '친구' : o.nickname, '${o.score}점'),
                _line(
                  '문제',
                  '${r.total}문제 (정답 ${r.correct} · 오답 ${r.total - r.correct})',
                ),
                _line('정답률', '${r.percent}%'),
                _line('최고 콤보', 'x${r.bestCombo}'),
                _line('받은 XP', r.xp == null ? '-' : '+${r.xp}'),
              ],
            ),
          ),
          if (r.rounds.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.section),
            ChunkyCard(
              title: '문제별 결과',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, q) in r.rounds.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatChip(
                            label: q.correct ? '적중' : '빗나감',
                            color: q.correct ? AppColors.lime : AppColors.wrong,
                            border: false,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  q.question.isEmpty
                                      ? '${i + 1}번 문제'
                                      : q.question,
                                  style: AppTextStyles.bodyS.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (q.answer.isNotEmpty)
                                  Text(
                                    '정답: ${q.answer}',
                                    style: AppTextStyles.caption,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          ChunkyButton(
            label: '목록으로',
            color: AppColors.paper,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  static Widget _line(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppSpacing.minTouch * 2,
          child: Text(k, style: AppTextStyles.label),
        ),
        Expanded(child: Text(v, style: AppTextStyles.bodyS)),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: AppColors.inkSub),
        ),
      ),
    );
  }
}
