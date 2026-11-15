import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/source.dart';
import '../../core/theme/tokens.dart';
import 'source_providers.dart';
import 'source_tile.dart';

/// 자료 하나: 상태, 요약, 카드 뽑기 진입. 카드 생성은 A 작업 7·8번에서 붙인다.
class SourceDetailScreen extends ConsumerWidget {
  const SourceDetailScreen({super.key, required this.sourceId});

  final String sourceId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    StudySource source,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('자료를 지울까요?'),
        content: const Text('이 자료로 만든 카드는 그대로 남아요.'),
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
    if (ok != true) return;
    await ref.read(sourceRepositoryProvider).delete(source);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sourceProvider(sourceId));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('불러오지 못했어요\n$e')),
      ),
      data: (source) {
        if (source == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('지워진 자료예요')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: '지우기',
                onPressed: () => _delete(context, ref, source),
                icon: const Icon(Icons.delete_outline),
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
              Row(
                children: [
                  Icon(sourceIcon(source.kind), size: 28, color: AppColors.ink),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(source.fileName, style: AppTextStyles.titleM),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text('${source.week}주차', style: AppTextStyles.label),
                  const SizedBox(width: AppSpacing.sm),
                  SourceStatusChip(status: source.status),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              const Text('핵심 요약', style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.page),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Text(
                  source.summary ?? '아직 분석 전이에요. 아래에서 카드를 뽑으면 요약도 같이 만들어요.',
                  style: source.summary == null
                      ? AppTextStyles.body.copyWith(color: AppColors.inkSub)
                      : AppTextStyles.body,
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  // TODO(A-7): CardGenerator 연결
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('카드 뽑기는 다음 작업에서 연결돼요')),
                  ),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('이 자료로 카드 뽑기'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
