import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import '../sources/source_detail_screen.dart';
import '../sources/source_providers.dart';
import '../sources/source_tile.dart';
import '../sources/upload_sheet.dart';

/// 과목의 한 주차. 자료 목록·업로드. 카드 목록은 족보 노트(A 작업 12번)에서.
class WeekScreen extends ConsumerWidget {
  const WeekScreen({super.key, required this.subject, required this.week});

  final Subject subject;
  final int week;

  Future<void> _upload(BuildContext context) async {
    final uploaded = await showUploadSheet(
      context,
      subjectId: subject.id,
      week: week,
    );
    if (uploaded.isEmpty || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${uploaded.length}개 올렸어요')));
    if (uploaded.length == 1) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SourceDetailScreen(sourceId: uploaded.single.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(
      weekSourcesProvider((subjectId: subject.id, week: week)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(subject.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _upload(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('자료 추가', style: AppTextStyles.button),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.section * 4,
        ),
        children: [
          Text('$week주차', style: AppTextStyles.titleL),
          const SizedBox(height: AppSpacing.section),
          const Text('자료', style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.md),
          sources.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.section),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              '자료를 불러오지 못했어요\n$e',
              style: AppTextStyles.body.copyWith(color: AppColors.inkSub),
            ),
            data: (list) {
              if (list.isEmpty) return _Empty(onUpload: () => _upload(context));
              return Column(
                children: [
                  for (final s in list) ...[
                    SourceTile(
                      source: s,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SourceDetailScreen(sourceId: s.id),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.page),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
            onPressed: onUpload,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('자료 추가'),
          ),
        ],
      ),
    );
  }
}
