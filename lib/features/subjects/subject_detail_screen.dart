import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import 'subject_form_sheet.dart';
import 'subject_providers.dart';
import 'subject_utils.dart';
import 'week_screen.dart';

/// 과목 상세: 시험일, 주차 선택(1~16).
class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({super.key, required this.subjectId});

  final String subjectId;

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    Subject subject,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        await showSubjectFormSheet(context, subject: subject);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('과목을 지울까요?'),
            content: const Text('과목 안의 자료와 카드는 그대로 남아요. (정리는 나중에)'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('지우기'),
              ),
            ],
          ),
        );
        if (ok == true) {
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
        appBar: AppBar(),
        body: Center(child: Text('불러오지 못했어요\n$e')),
      ),
      data: (subject) {
        if (subject == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('지워진 과목이에요')),
          );
        }
        final dday = examDDayLabel(subject.examDate);
        return Scaffold(
          appBar: AppBar(
            actions: [
              PopupMenuButton<String>(
                onSelected: (a) => _onMenu(context, ref, subject, a),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('수정')),
                  PopupMenuItem(value: 'delete', child: Text('지우기')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.section,
            ),
            children: [
              Text(subject.name, style: AppTextStyles.titleL),
              const SizedBox(height: AppSpacing.sm),
              if (dday != null)
                _DDayChip(label: dday)
              else
                Text(
                  '시험일 미정',
                  style: AppTextStyles.label.copyWith(color: AppColors.inkSub),
                ),
              const SizedBox(height: AppSpacing.section),
              const Text('주차 선택', style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.xs),
              Text('자료와 카드는 주차별로 모여요.', style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.lg),
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

class _DDayChip extends StatelessWidget {
  const _DDayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.lime,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
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
        mainAxisExtent: 56,
      ),
      itemCount: kMaxWeek,
      itemBuilder: (_, i) {
        final week = i + 1;
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.button),
            onTap: () => onTap(week),
            child: Center(
              child: Text(
                '$week주차',
                style: AppTextStyles.bodyS.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
