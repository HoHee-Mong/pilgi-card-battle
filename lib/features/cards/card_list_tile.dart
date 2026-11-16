import 'package:flutter/material.dart';

import '../../core/models/card.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/stat_chip.dart';

String cardTypeShort(CardType t) => switch (t) {
  CardType.mcq => '객관식',
  CardType.ox => 'OX',
  CardType.short => '단답',
};

/// 유형별 번호 블록 색 (시안 랭킹 목록의 2·3·4위 블록처럼 유형마다 색이 다르다).
Color cardTypeColor(CardType t) => switch (t) {
  CardType.mcq => AppColors.cyan,
  CardType.ox => AppColors.sun,
  CardType.short => AppColors.pink,
};

/// 카드 목록 한 줄 블록: 유형 블록, 문제, 정답, 상태·개념 태그.
/// [similarCount]가 0보다 크면 "비슷한 문제 N" 표시를 붙인다.
/// [caption]을 주면 "정답: …" 줄 대신 그 글을 쓴다 (방 카드: 작성자·출처).
/// [showStatus]가 false면 검수 상태·공유 태그를 숨긴다. [trailing]은 오른쪽 끝(투표 버튼 등).
class CardListTile extends StatelessWidget {
  const CardListTile({
    super.key,
    required this.card,
    required this.onTap,
    this.similarCount = 0,
    this.caption,
    this.showStatus = true,
    this.trailing,
  });

  final QuizCard card;
  final VoidCallback onTap;
  final int similarCount;
  final String? caption;
  final bool showStatus;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      onTap: onTap,
      radius: AppRadius.button,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TypeBlock(type: card.type),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  caption ??
                      '정답: ${card.answer}'
                          '${card.concept.isNotEmpty ? ' · ${card.concept}' : ''}',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showStatus || similarCount > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (showStatus)
                        StatChip(
                          label: card.isVerified ? '검수 완료' : '초안',
                          color: card.isVerified
                              ? AppColors.lime
                              : AppColors.cream,
                          border: false,
                        ),
                      if (showStatus && card.roomIds.isNotEmpty)
                        StatChip(
                          label: '공유 ${card.roomIds.length}곳',
                          color: AppColors.cyan,
                          border: false,
                        ),
                      if (similarCount > 0)
                        StatChip(
                          label: '비슷한 문제 $similarCount',
                          color: AppColors.wrong,
                          border: false,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// 왼쪽 유형 블록 (객관식 / OX / 단답).
class _TypeBlock extends StatelessWidget {
  const _TypeBlock({required this.type});

  final CardType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cardTypeColor(type),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.ink, width: AppBlock.border),
      ),
      child: Text(
        cardTypeShort(type),
        style: AppTextStyles.chip.copyWith(
          fontSize: type == CardType.mcq ? 12 : 15,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
