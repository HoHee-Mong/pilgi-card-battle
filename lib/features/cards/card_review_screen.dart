import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/card.dart';
import '../../core/theme/tokens.dart';
import 'card_edit_screen.dart';
import 'card_list_tile.dart';
import 'card_providers.dart';

/// 자료 하나로 만든 카드 검수 목록. 초안이 위로 온다.
class CardReviewScreen extends ConsumerWidget {
  const CardReviewScreen({
    super.key,
    required this.sourceId,
    required this.title,
  });

  final String sourceId;
  final String title;

  Future<void> _verifyAll(
    BuildContext context,
    WidgetRef ref,
    List<QuizCard> drafts,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('초안 ${drafts.length}장을 모두 검수 완료로 바꿀까요?'),
        content: const Text('AI가 만든 문제는 틀릴 수 있어요. 한 장씩 보고 넘기는 걸 권해요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('모두 완료'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(cardRepositoryProvider);
    for (final c in drafts) {
      await repo.setStatus(c.id, CardStatus.verified);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(sourceCardsProvider(sourceId));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오지 못했어요\n$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                '이 자료로 만든 카드가 없어요.',
                style: AppTextStyles.body.copyWith(color: AppColors.inkSub),
              ),
            );
          }
          final drafts = list.where((c) => !c.isVerified).toList();
          final verified = list.where((c) => c.isVerified).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.section,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '초안 ${drafts.length} · 검수 완료 ${verified.length}',
                      style: AppTextStyles.label,
                    ),
                  ),
                  if (drafts.isNotEmpty)
                    TextButton(
                      onPressed: () => _verifyAll(context, ref, drafts),
                      child: const Text('모두 완료'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final c in [...drafts, ...verified]) ...[
                CardListTile(
                  card: c,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CardEditScreen.edit(card: c),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}
