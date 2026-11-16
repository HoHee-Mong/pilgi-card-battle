import 'package:flutter/material.dart';

import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/outlined_text.dart';
import '../../core/widgets/vote_button.dart';
import '../cards/card_list_tile.dart';
import 'solo_model.dart';
import 'solo_setup_screen.dart';

/// 혼자 풀기 결과 (sun 배경, 시안 game-result 구성). 틀린 문제는 오답 노트로 자동 저장됨.
class SoloResultScreen extends StatelessWidget {
  const SoloResultScreen({
    super.key,
    required this.subject,
    required this.results,
    required this.total,
  });

  final Subject subject;
  final List<QuizResult> results;

  /// 원래 문제집 크기 (중간에 그만두면 results보다 크다)
  final int total;

  @override
  Widget build(BuildContext context) {
    final correct = countCorrect(results);
    final wrong = results.where((r) => !r.correct).toList();
    final rate = results.isEmpty ? 0 : (correct * 100 / results.length).round();
    final rank = switch (rate) {
      >= 90 => 'S',
      >= 75 => 'A',
      >= 50 => 'B',
      _ => 'C',
    };

    return Scaffold(
      backgroundColor: AppColors.sun,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.section * 2,
            AppSpacing.page,
            AppSpacing.section,
          ),
          children: [
            Center(
              child: Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.grape,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: AppColors.ink,
                    width: AppBlock.border,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.ink,
                      offset: Offset(0, AppBlock.shadow),
                    ),
                  ],
                ),
                child: OutlinedText(
                  rank,
                  style: AppTextStyles.titleL.copyWith(fontSize: 64),
                  color: AppColors.paper,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            Center(
              child: Text(
                results.length < total ? '중간 점검!' : '혼자 풀기 끝!',
                style: AppTextStyles.titleL,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: Text(
                '${subject.name} · ${results.length}문제',
                style: AppTextStyles.body,
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: '$correct',
                    suffix: '/${results.length}',
                    label: '맞힌 문제',
                    color: AppColors.paper,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Stat(
                    value: '$rate%',
                    label: '정답률',
                    color: AppColors.lime,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Stat(
                    value: '${wrong.length}',
                    label: '오답 노트',
                    color: AppColors.cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            if (wrong.isNotEmpty) ...[
              ChunkyCard(
                title: '틀린 문제 ${wrong.length}개',
                trailing: const Text(
                  '오답 노트로 자동 저장',
                  style: AppTextStyles.caption,
                ),
                child: Column(
                  children: [
                    for (final r in wrong) ...[
                      CardListTile(
                        card: r.card,
                        caption: '정답: ${r.card.answer} · 내 답: ${r.answer}',
                        showStatus: false,
                        trailing: r.card.roomIds.isEmpty
                            ? null
                            : VoteButton(
                                roomId: r.card.roomIds.first,
                                cardId: r.card.id,
                                compact: true,
                              ),
                        onTap: () {},
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
            ] else
              const ChunkyCard(
                color: AppColors.lime,
                child: Text(
                  '전부 맞혔어요. 보스가 떨고 있어요!',
                  style: AppTextStyles.heading,
                ),
              ),
            const SizedBox(height: AppSpacing.section),
            Row(
              children: [
                Expanded(
                  child: ChunkyButton(
                    label: '한 판 더',
                    color: AppColors.paper,
                    large: true,
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => SoloSetupScreen(subject: subject),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ChunkyButton(
                    label: '끝내기',
                    large: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 결과 숫자 블록 (시안: 17/20 맞힌 문제, X6 최고 콤보, +240 XP).
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
          Text.rich(
            TextSpan(
              text: value,
              style: AppTextStyles.titleL,
              children: [
                if (suffix != null)
                  TextSpan(text: suffix, style: AppTextStyles.heading),
              ],
            ),
            textAlign: TextAlign.center,
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
