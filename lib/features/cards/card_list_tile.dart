import 'package:flutter/material.dart';

import '../../core/models/card.dart';
import '../../core/theme/tokens.dart';

String cardTypeShort(CardType t) => switch (t) {
  CardType.mcq => '객관식',
  CardType.ox => 'OX',
  CardType.short => '단답',
};

/// 카드 목록 한 줄: 유형, 상태, 문제, 개념 태그.
class CardListTile extends StatelessWidget {
  const CardListTile({super.key, required this.card, required this.onTap});

  final QuizCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Tag(
                    cardTypeShort(card.type),
                    color: scheme.surfaceContainerHighest,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _Tag(
                    card.isVerified ? '검수 완료' : '초안',
                    color: card.isVerified
                        ? AppColors.lime
                        : scheme.surfaceContainerHighest,
                  ),
                  const Spacer(),
                  if (card.concept.isNotEmpty)
                    Flexible(
                      child: Text(
                        card.concept,
                        style: AppTextStyles.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                card.question,
                style: AppTextStyles.bodyS.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '정답: ${card.answer}',
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
