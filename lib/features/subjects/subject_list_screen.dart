import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/stat_chip.dart';
import 'arcade_app_bar.dart';
import 'subject_detail_screen.dart';
import 'subject_form_sheet.dart';
import 'subject_providers.dart';
import 'subject_utils.dart';

/// 내 과목 목록 ("내 카드" 탭의 첫 화면). 과목 = 잡아야 할 보스.
class SubjectListScreen extends ConsumerWidget {
  const SubjectListScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final created = await showSubjectFormSheet(context);
    if (created != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SubjectDetailScreen(subjectId: created.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(mySubjectsProvider);

    return Scaffold(
      appBar: const ArcadeAppBar(showBack: false),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.page,
        ),
        child: ChunkyButton(
          label: '과목 만들기',
          icon: Icons.add,
          large: true,
          onPressed: () => _create(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.section,
        ),
        children: [
          const ArcadeTitle(title: '내 과목', subtitle: '시험 볼 과목마다 카드를 모아요'),
          const SizedBox(height: AppSpacing.section),
          ...subjects.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(AppSpacing.section),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [ArcadeEmpty(message: '과목을 불러오지 못했어요\n$e')],
            data: (list) => list.isEmpty
                ? [
                    ArcadeEmpty(
                      message: '아직 과목이 없어요.\n시험 볼 과목을 하나 만들어 보세요.',
                      actionLabel: '첫 과목 만들기',
                      actionIcon: Icons.add,
                      onAction: () => _create(context),
                    ),
                  ]
                : [
                    for (final s in list) ...[
                      _SubjectCard(subject: s),
                      const SizedBox(height: AppSpacing.section),
                    ],
                  ],
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final dday = examDDayLabel(subject.examDate);
    return ChunkyCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SubjectDetailScreen(subjectId: subject.id),
        ),
      ),
      child: Row(
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
                Text(subject.name, style: AppTextStyles.titleM),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (dday != null)
            Text(
              dday,
              style: AppTextStyles.titleM.copyWith(color: AppColors.pink),
            )
          else
            const Icon(Icons.chevron_right, color: AppColors.inkSub, size: 28),
        ],
      ),
    );
  }
}
