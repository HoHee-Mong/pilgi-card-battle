import 'package:flutter/material.dart';

import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';

/// 과목의 한 주차. 자료 목록·업로드(A 작업 6번)와 카드 목록이 여기에 붙는다.
class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key, required this.subject, required this.week});

  final Subject subject;
  final int week;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(subject.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.section,
        ),
        children: [
          Text('$week주차', style: AppTextStyles.titleL),
          const SizedBox(height: AppSpacing.section),
          const Text('자료', style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.page),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              children: [
                Text(
                  '아직 자료가 없어요.\n필기 사진이나 PDF를 올리면 AI가 카드를 만들어요.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: AppColors.inkSub),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  // TODO(A-6): 자료 업로드 화면 연결
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('자료 업로드는 다음 작업에서 연결돼요')),
                  ),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('자료 추가'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
