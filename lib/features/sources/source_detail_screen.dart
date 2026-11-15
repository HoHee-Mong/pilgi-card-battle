import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/source.dart';
import '../../core/theme/tokens.dart';
import '../cards/card_providers.dart';
import '../cards/card_review_screen.dart';
import 'source_providers.dart';
import 'source_tile.dart';

/// 자료 하나: 상태, 요약, 만든 카드 검수로 이동.
/// 원본을 저장하지 않으므로 "다시 뽑기"는 없다. 더 뽑으려면 자료를 다시 올린다.
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
        title: const Text('자료 기록을 지울까요?'),
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

  void _openReview(BuildContext context, StudySource source) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CardReviewScreen(sourceId: source.id, title: source.fileName),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sourceProvider(sourceId));
    final cards = ref.watch(sourceCardsProvider(sourceId)).value ?? const [];
    final draftCount = cards.where((c) => !c.isVerified).length;

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
                  source.summary ??
                      (source.isProcessing
                          ? '분석 중이에요…'
                          : source.isFailed
                          ? '카드를 만들지 못했어요. 자료를 다시 올려 주세요.'
                          : '요약이 없어요.'),
                  style: source.summary == null
                      ? AppTextStyles.body.copyWith(color: AppColors.inkSub)
                      : AppTextStyles.body,
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              if (cards.isNotEmpty)
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _openReview(context, source),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(
                      draftCount > 0
                          ? '카드 ${cards.length}장 검수하기 · 초안 $draftCount'
                          : '카드 ${cards.length}장 보기',
                    ),
                  ),
                )
              else if (!source.isProcessing)
                Text(
                  '이 자료로 만든 카드가 없어요.',
                  style: AppTextStyles.body.copyWith(color: AppColors.inkSub),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '원본 파일은 저장하지 않아요. 카드를 더 뽑으려면 주차 화면에서 자료를 다시 올려 주세요.',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        );
      },
    );
  }
}
