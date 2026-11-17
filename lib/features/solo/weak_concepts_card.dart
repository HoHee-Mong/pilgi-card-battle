import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/card.dart';
import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/stat_chip.dart';
import '../cards/card_providers.dart';
import 'solo_model.dart';
import 'solo_play_screen.dart';
import 'solo_providers.dart';
import 'weak_concepts.dart';

/// 과목 화면의 "약한 개념 TOP 3": 개념 태그별 정답률 → 약한 개념과 추천 카드 풀기.
class WeakConceptsCard extends ConsumerWidget {
  const WeakConceptsCard({super.key, required this.subject});

  final Subject subject;

  /// 추천 카드로 한 번에 내는 문항 수.
  static const quizSize = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attempts =
        ref.watch(subjectAttemptsProvider(subject.id)).value ?? const [];
    final cards =
        ref.watch(myCardsProvider((subjectId: subject.id, week: null))).value ??
        const <QuizCard>[];
    if (cards.isEmpty) return const SizedBox.shrink();

    final weak = weakConcepts(attempts);
    if (weak.isEmpty) {
      return ChunkyCard(
        title: '약한 개념 TOP 3',
        child: Text(
          attempts.isEmpty
              ? '문제를 풀면 개념별 정답률을 모아 약한 개념을 알려 줘요.'
              : '아직 약한 개념이 없어요. 개념마다 2번 이상 풀면 계산해요.',
          style: AppTextStyles.bodyS,
        ),
      );
    }
    final recommended = recommendCards(cards, weak);
    return ChunkyCard(
      title: '약한 개념 TOP 3',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, w) in weak.indexed) ...[
            Row(
              children: [
                StatChip(
                  label: '${i + 1}',
                  color: i == 0 ? AppColors.wrong : AppColors.paper,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    w.concept,
                    style: AppTextStyles.heading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '정답률 ${w.percent}% · ${w.tries}번',
                  style: AppTextStyles.label,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: LinearProgressIndicator(
                value: w.rate,
                minHeight: 8,
                color: AppColors.lime,
                backgroundColor: AppColors.cream,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          ChunkyButton(
            label: recommended.isEmpty
                ? '추천할 내 카드가 없어요'
                : '추천 카드 ${recommended.length < quizSize ? recommended.length : quizSize}문제 풀기',
            icon: Icons.fitness_center_rounded,
            color: AppColors.pink,
            onPressed: recommended.isEmpty
                ? null
                : () {
                    final set = buildQuizSet(
                      recommended,
                      weeks: const {},
                      types: {...CardType.values},
                      count: quizSize,
                      lastSolved: lastSolvedAt(attempts),
                    );
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<String>(
                        builder: (_) =>
                            SoloPlayScreen(subject: subject, cards: set),
                      ),
                    );
                  },
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            '혼자 풀기·배틀·모의고사 기록을 개념 태그별로 모아 계산해요.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
