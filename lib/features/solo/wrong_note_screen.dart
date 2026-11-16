import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/models/card.dart';
import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/stat_chip.dart';
import '../cards/card_edit_screen.dart';
import '../cards/card_list_tile.dart';
import '../subjects/arcade_app_bar.dart';
import 'solo_play_screen.dart';
import 'wrong_note_model.dart';
import 'wrong_note_providers.dart';

enum _Filter { needsReview, reviewed, all }

/// 오답 노트: 틀린 문제 모아보기, 다시 풀기, 복습 완료 표시.
/// 혼자 풀기·배틀(B)·모의고사 기록을 모두 본다.
class WrongNoteScreen extends ConsumerStatefulWidget {
  const WrongNoteScreen({super.key, required this.subject});

  final Subject subject;

  @override
  ConsumerState<WrongNoteScreen> createState() => _WrongNoteScreenState();
}

class _WrongNoteScreenState extends ConsumerState<WrongNoteScreen> {
  _Filter _filter = _Filter.needsReview;

  Future<void> _retry(List<QuizCard> cards) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => SoloPlayScreen(subject: widget.subject, cards: cards),
      ),
    );
  }

  void _open(WrongCard item) {
    final uid = ref.read(uidProvider);
    if (item.card.ownerId == uid) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CardEditScreen.edit(card: item.card),
        ),
      );
    } else {
      _peek(item.card);
    }
  }

  /// 친구 카드(배틀에서 틀린 것)는 읽기만.
  Future<void> _peek(QuizCard card) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
        side: BorderSide(color: AppColors.ink, width: AppBlock.border),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.section,
          AppSpacing.page,
          AppSpacing.page + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatChip(label: '${card.ownerNickname} 카드', color: AppColors.paper),
            const SizedBox(height: AppSpacing.md),
            Text(card.question, style: AppTextStyles.titleM),
            const SizedBox(height: AppSpacing.md),
            ChunkyCard(
              color: AppColors.lime,
              radius: AppRadius.button,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text('정답: ${card.answer}', style: AppTextStyles.body),
            ),
            if (card.explanation.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(card.explanation, style: AppTextStyles.body),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final async = ref.watch(wrongNoteProvider(subject.id));

    return Scaffold(
      appBar: ArcadeAppBar(
        trailing: [StatChip(label: subject.name, color: AppColors.paper)],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: ArcadeEmpty(message: '오답 노트를 불러오지 못했어요\n$e'),
        ),
        data: (all) {
          final needs = all.where((w) => w.entry.needsReview).toList();
          final done = all.where((w) => w.entry.reviewed).toList();
          final shown = switch (_filter) {
            _Filter.needsReview => needs,
            _Filter.reviewed => done,
            _Filter.all => all,
          };
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.section * 2,
            ),
            children: [
              const ArcadeTitle(
                title: '오답 노트',
                subtitle: '틀린 문제를 다시 맞히면 복습 완료로 바뀌어요',
              ),
              const SizedBox(height: AppSpacing.section),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  StatChip(
                    label: '복습 필요 ${needs.length}',
                    color: AppColors.pink,
                  ),
                  StatChip(
                    label: '복습 완료 ${done.length}',
                    color: AppColors.lime,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              ChunkyButton(
                label: needs.isEmpty
                    ? '복습할 문제가 없어요'
                    : '복습 필요 ${needs.length}문제 다시 풀기',
                icon: Icons.replay_rounded,
                large: true,
                onPressed: needs.isEmpty
                    ? null
                    : () => _retry([for (final w in needs) w.card]),
              ),
              const SizedBox(height: AppSpacing.section),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final (f, label) in const [
                    (_Filter.needsReview, '복습 필요'),
                    (_Filter.reviewed, '복습 완료'),
                    (_Filter.all, '전체'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (all.isEmpty)
                const ArcadeEmpty(
                  message: '아직 틀린 문제가 없어요.\n혼자 풀기나 배틀에서 틀린 문제가 여기 모여요.',
                )
              else if (shown.isEmpty)
                const ArcadeEmpty(message: '여기에 해당하는 문제가 없어요.')
              else
                for (final w in shown) ...[
                  CardListTile(
                    card: w.card,
                    caption:
                        '틀림 ${w.entry.wrongCount}번 · '
                        '${attemptModeLabel(w.entry.lastMode)} '
                        '${w.entry.lastAt.month}.${w.entry.lastAt.day}',
                    showStatus: false,
                    trailing: StatChip(
                      label: w.entry.reviewed ? '복습 완료' : '복습 필요',
                      color: w.entry.reviewed ? AppColors.lime : AppColors.pink,
                      border: false,
                    ),
                    onTap: () => _open(w),
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
