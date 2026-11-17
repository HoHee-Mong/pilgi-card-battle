import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/models/room.dart';
import '../../core/theme/layout.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/outlined_text.dart';
import '../../core/widgets/rank_stamp.dart';
import '../../core/widgets/vote_button.dart';
import '../../fx/confetti.dart';
import '../../fx/motion.dart';
import '../room/progress_rules.dart';
import 'mock_exam_model.dart';

/// 모의고사 결과 (시안 game-result, sun 배경).
/// 점수·랭크·걸린 시간·XP, 틀린 문제(정답·내 답·투표 수), 맞힌 문제, 문제마다 `VoteButton`.
/// "한 판 더"면 `again`, "끝내기"면 `done`을 돌려준다.
class MockExamResultScreen extends StatelessWidget {
  const MockExamResultScreen({
    super.key,
    required this.room,
    required this.marks,
    required this.elapsed,
    this.xp,
  });

  final Room room;
  final List<MockMark> marks;

  final Duration elapsed;

  /// 얻은 XP. 저장 실패면 null
  final int? xp;

  @override
  Widget build(BuildContext context) {
    final total = marks.length;
    final score = marks.where((m) => m.correct).length;
    final percent = percentOf(score, total);
    final wrong = marks.where((m) => !m.correct).toList();
    final right = marks.where((m) => m.correct).toList();
    final passed = percent >= 50;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop('done');
      },
      child: Scaffold(
        backgroundColor: AppColors.sun,
        body: Stack(
          children: [
            SafeArea(
              child: ListView(
                padding: AppLayout.pagePadding(
                  context,
                  top: AppSpacing.section,
                  bottom: AppSpacing.section * 2,
                ),
                children: [
                  Center(child: RankStamp(rank: resultRank(percent))),
                  Center(
                    child:
                        OutlinedText(
                              mockResultTitle(score, total),
                              color: passed ? AppColors.pink : AppColors.paper,
                            )
                            .animateOrStill(context)
                            .scaleXY(
                              begin: 2,
                              end: 1,
                              duration: AppMotion.stamp,
                              curve: AppMotion.spring,
                            ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '우리가 만든 ${room.name} 모의고사 $total문항',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: '$score',
                          suffix: '/$total',
                          label: '맞힌 문제',
                          color: AppColors.paper,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _Stat(
                          value: formatClock(elapsed.inSeconds),
                          label: '걸린 시간',
                          color: AppColors.lime,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _Stat(
                          value: xp == null ? '-' : '+$xp',
                          label: '획득 XP',
                          color: AppColors.cyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.section),
                  if (wrong.isEmpty)
                    const ChunkyCard(
                      color: AppColors.lime,
                      child: Text(
                        '전부 맞혔어요. 이번 보스는 완전히 격파!',
                        style: AppTextStyles.heading,
                      ),
                    )
                  else
                    ChunkyCard(
                      title: '틀린 문제 ${wrong.length}개',
                      trailing: Text(
                        '오답 노트에 저장',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.grape,
                        ),
                      ),
                      child: Column(
                        children: [
                          for (final m in wrong)
                            _MarkRow(roomId: room.id, mark: m),
                        ],
                      ),
                    ),
                  if (right.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.section),
                    ChunkyCard(
                      title: '맞힌 문제 ${right.length}개',
                      child: Column(
                        children: [
                          for (final m in right)
                            _MarkRow(roomId: room.id, mark: m),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '시험에 나올 것 같은 문제엔 별을 눌러 주세요',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  Row(
                    children: [
                      Expanded(
                        child: ChunkyButton(
                          label: '한 판 더',
                          color: AppColors.paper,
                          large: true,
                          onPressed: () => Navigator.of(context).pop('again'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ChunkyButton(
                          label: '끝내기',
                          large: true,
                          onPressed: () => Navigator.of(context).pop('done'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (passed) const Positioned.fill(child: ConfettiRain()),
          ],
        ),
      ),
    );
  }
}

/// 문제 한 줄: 맞음/틀림 표시, 질문, (틀렸으면) 정답·내 답, 투표 버튼(지금 투표 수)
class _MarkRow extends StatelessWidget {
  const _MarkRow({required this.roomId, required this.mark});

  final String roomId;
  final MockMark mark;

  @override
  Widget build(BuildContext context) {
    final card = mark.card;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              mark.correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: mark.correct ? AppColors.grape : AppColors.pink,
              semanticLabel: mark.correct ? '맞음' : '틀림',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.question,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!mark.correct)
                  Text(
                    '정답: ${card.answer} · 내 답: ${mark.answer ?? '안 풂'}',
                    style: AppTextStyles.bodyS,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          VoteButton(roomId: roomId, cardId: card.id, compact: true),
        ],
      ),
    );
  }
}

/// 결과 숫자 블록 (시안: 17/20 맞힌 문제)
class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.color,
    this.suffix,
  });

  final String value;
  final String? suffix;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      color: color,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                text: value,
                style: AppTextStyles.titleL,
                children: [
                  if (suffix != null)
                    TextSpan(text: suffix, style: AppTextStyles.heading),
                ],
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.label.copyWith(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}
