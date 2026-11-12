import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import 'subject_detail_screen.dart';
import 'subject_form_sheet.dart';
import 'subject_providers.dart';
import 'subject_utils.dart';

/// 내 과목 목록. B의 라우터/하단 탭이 오면 홈 탭 안에 들어간다.
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
      appBar: AppBar(title: const Text('내 과목')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        icon: const Icon(Icons.add),
        label: const Text('과목 만들기', style: AppTextStyles.button),
      ),
      body: subjects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message('과목을 불러오지 못했어요\n$e'),
        data: (list) {
          if (list.isEmpty) {
            return const _Message('아직 과목이 없어요.\n시험 볼 과목을 하나 만들어 보세요.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.section * 4,
            ),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) => _SubjectTile(subject: list[i]),
          );
        },
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final dday = examDDayLabel(subject.examDate);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SubjectDetailScreen(subjectId: subject.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.name, style: AppTextStyles.heading),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      dday ?? '시험일 미정',
                      style: AppTextStyles.caption.copyWith(
                        color: dday == null
                            ? AppColors.inkSub
                            : AppColors.blueText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkSub),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: AppColors.inkSub),
        ),
      ),
    );
  }
}
