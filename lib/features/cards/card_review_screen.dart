import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/card.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/stat_chip.dart';
import '../subjects/arcade_app_bar.dart';
import '../subjects/arcade_dialog.dart';
import 'card_edit_screen.dart';
import 'card_list_tile.dart';
import 'card_providers.dart';
import 'card_xp.dart';
import 'card_similarity.dart';

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
    final ok = await showArcadeConfirm(
      context,
      title: '초안 ${drafts.length}장을 모두 검수 완료로 바꿀까요?',
      message: 'AI가 만든 문제는 틀릴 수 있어요. 한 장씩 보고 넘기는 걸 권해요.',
      confirmLabel: '모두 완료',
      confirmColor: AppColors.lime,
    );
    if (!ok) return;
    final repo = ref.read(cardRepositoryProvider);
    for (final c in drafts) {
      await repo.setStatus(c.id, CardStatus.verified);
    }
    await recordCardsCreated(ref, drafts.length);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(sourceCardsProvider(sourceId));
    return Scaffold(
      appBar: const ArcadeAppBar(),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오지 못했어요\n$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.page),
              child: ArcadeEmpty(message: '이 자료로 만든 카드가 없어요.'),
            );
          }
          final drafts = list.where((c) => !c.isVerified).toList();
          final verified = list.where((c) => c.isVerified).toList();
          // 같은 과목의 내 카드 전체와 비교해 비슷한 문제가 있는 카드를 표시한다.
          final pool =
              ref
                  .watch(
                    myCardsProvider((
                      subjectId: list.first.subjectId,
                      week: null,
                    )),
                  )
                  .value ??
              list;
          final similarCounts = CardSimilarity.countWithin(list, pool);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.section * 2,
            ),
            children: [
              ArcadeTitle(title: '카드 검수', subtitle: title),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  StatChip(
                    label: '초안 ${drafts.length}',
                    color: drafts.isEmpty ? AppColors.paper : AppColors.pink,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatChip(
                    label: '검수 완료 ${verified.length}',
                    color: AppColors.lime,
                  ),
                ],
              ),
              if (drafts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.section),
                ChunkyButton(
                  label: '초안 ${drafts.length}장 모두 완료',
                  icon: Icons.done_all,
                  color: AppColors.paper,
                  onPressed: () => _verifyAll(context, ref, drafts),
                ),
              ],
              const SizedBox(height: AppSpacing.section),
              for (final c in [...drafts, ...verified]) ...[
                CardListTile(
                  card: c,
                  similarCount: similarCounts[c.id] ?? 0,
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
