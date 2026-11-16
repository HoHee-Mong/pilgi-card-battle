import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/chunky_press.dart';
import '../../core/widgets/stat_chip.dart';
import '../../core/widgets/chunky_button.dart';
import '../cards/card_providers.dart';
import '../notebook/notebook_screen.dart';
import '../solo/solo_setup_screen.dart';
import 'arcade_app_bar.dart';
import 'arcade_dialog.dart';
import 'subject_form_sheet.dart';
import 'subject_providers.dart';
import 'subject_utils.dart';
import 'week_screen.dart';

/// 과목 상세: 보스 카드(시험일), 주차 선택(1~16).
class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({super.key, required this.subjectId});

  final String subjectId;

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.ink),
              title: const Text('과목 수정', style: AppTextStyles.body),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.ink),
              title: const Text('과목 지우기', style: AppTextStyles.body),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'edit':
        await showSubjectFormSheet(context, subject: subject);
      case 'delete':
        final ok = await showArcadeConfirm(
          context,
          title: '과목을 지울까요?',
          message: '과목 안의 자료와 카드는 그대로 남아요. (정리는 나중에)',
          confirmLabel: '지우기',
          confirmColor: AppColors.wrong,
        );
        if (ok) {
          await ref.read(subjectRepositoryProvider).delete(subject.id);
          if (context.mounted) Navigator.of(context).pop();
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectAsync = ref.watch(subjectProvider(subjectId));

    return subjectAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: const ArcadeAppBar(),
        body: Center(child: Text('불러오지 못했어요\n$e')),
      ),
      data: (subject) {
        if (subject == null) {
          return const Scaffold(
            appBar: ArcadeAppBar(),
            body: Center(child: Text('지워진 과목이에요')),
          );
        }
        final dday = examDDayLabel(subject.examDate);
        final cardCount =
            ref
                .watch(myCardsProvider((subjectId: subject.id, week: null)))
                .value
                ?.length ??
            0;
        return Scaffold(
          appBar: ArcadeAppBar(
            trailing: [
              ArcadeIconButton(
                icon: Icons.more_horiz,
                semanticLabel: '더보기',
                onPressed: () => _onMenu(context, ref, subject),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.section,
            ),
            children: [
              _BossCard(subject: subject, dday: dday, cardCount: cardCount),
              const SizedBox(height: AppSpacing.section),
              Row(
                children: [
                  Expanded(
                    child: ChunkyButton(
                      label: '혼자 풀기',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SoloSetupScreen(subject: subject),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ChunkyButton(
                      label: '족보 노트',
                      icon: Icons.menu_book_outlined,
                      color: AppColors.cyan,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => NotebookScreen(subject: subject),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              const ArcadeSectionHeader(title: '주차 선택'),
              const SizedBox(height: AppSpacing.xs),
              const Text('자료와 카드는 주차별로 모여요.', style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.md),
              _WeekGrid(
                onTap: (week) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WeekScreen(subject: subject, week: week),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 시안 로비의 "이번 보스" 카드: 칩 + 과목 이름 + 카드 수 + D-day.
class _BossCard extends StatelessWidget {
  const _BossCard({
    required this.subject,
    required this.dday,
    required this.cardCount,
  });

  final Subject subject;
  final String? dday;
  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatChip(
                  label: dday == null ? '시험일 미정' : '이번 보스',
                  color: dday == null ? AppColors.paper : AppColors.pink,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(subject.name, style: AppTextStyles.titleL),
                const SizedBox(height: AppSpacing.md),
                Text('모의고사 재료 $cardCount문제 모임', style: AppTextStyles.label),
              ],
            ),
          ),
          if (dday != null) ...[
            const SizedBox(width: AppSpacing.md),
            Text(
              dday!,
              style: AppTextStyles.titleL.copyWith(color: AppColors.pink),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.onTap});

  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 56 + AppBlock.shadow,
      ),
      itemCount: kMaxWeek,
      itemBuilder: (_, i) {
        final week = i + 1;
        return ChunkyPress(
          onTap: () => onTap(week),
          color: AppColors.paper,
          radius: AppRadius.chip,
          height: 56,
          alignment: Alignment.center,
          child: Text('$week주차', style: AppTextStyles.chip),
        );
      },
    );
  }
}
