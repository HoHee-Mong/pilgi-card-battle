import 'package:flutter/material.dart';

import '../../core/ai/card_generator.dart';
import '../../core/models/card.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/stat_chip.dart';
import '../../core/widgets/vote_button.dart';
import '../cards/card_list_tile.dart';
import 'notebook_model.dart';

/// 방 문제은행 카드 한 장을 읽기 전용으로 보여 준다 (친구 카드는 고칠 수 없다).
/// 아래에 B의 [VoteButton]으로 "나올 것 같아요"를 누를 수 있다.
Future<void> showRoomCardSheet(BuildContext context, RoomCard item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      side: BorderSide(color: AppColors.ink, width: AppBlock.border),
    ),
    builder: (_) => _RoomCardSheet(item: item),
  );
}

class _RoomCardSheet extends StatelessWidget {
  const _RoomCardSheet({required this.item});

  final RoomCard item;

  @override
  Widget build(BuildContext context) {
    final card = item.card;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.section,
        AppSpacing.page,
        AppSpacing.page + MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                StatChip(label: '${card.week}주차', color: AppColors.paper),
                StatChip(
                  label: CardGenerator.typeLabel(card.type),
                  color: cardTypeColor(card.type),
                ),
                StatChip(
                  label: '${item.entry.addedByNickname} 카드',
                  color: AppColors.paper,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(card.question, style: AppTextStyles.titleM),
            const SizedBox(height: AppSpacing.lg),
            if (card.type == CardType.mcq)
              for (final (i, choice) in card.choices.indexed) ...[
                _Choice(
                  letter: String.fromCharCode(65 + i),
                  text: choice,
                  correct: choice == card.answer,
                ),
                const SizedBox(height: AppSpacing.sm),
              ]
            else
              _Choice(letter: '답', text: card.answer, correct: true),
            if (card.explanation.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const Text('해설', style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.xs),
              Text(card.explanation, style: AppTextStyles.body),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              '출처: ${card.sourceLabel.isEmpty ? '직접 작성' : card.sourceLabel}'
              ' · ${item.room.name}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.section),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '시험에 나올 것 같으면 눌러 주세요',
                    style: AppTextStyles.label,
                  ),
                ),
                VoteButton(roomId: item.room.id, cardId: card.id),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 보기 한 줄 (시안 보스전의 A/B/C/D 블록). 정답은 lime.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.letter,
    required this.text,
    required this.correct,
  });

  final String letter;
  final String text;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: correct ? AppColors.lime : AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.ink, width: AppBlock.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: AppColors.ink, width: 2),
            ),
            child: Text(letter, style: AppTextStyles.chip),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: AppTextStyles.body)),
          if (correct) const Text('정답', style: AppTextStyles.chip),
        ],
      ),
    );
  }
}
