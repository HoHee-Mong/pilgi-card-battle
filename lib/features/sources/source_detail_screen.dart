import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/source.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/stat_chip.dart';
import '../cards/card_providers.dart';
import '../cards/card_review_screen.dart';
import '../subjects/arcade_app_bar.dart';
import '../subjects/arcade_dialog.dart';
import 'source_providers.dart';
import 'source_tile.dart';

/// 자료 하나: 상태, 요약, (녹음이면) 시간별 전사, 만든 카드 검수로 이동.
/// 원본을 저장하지 않으므로 "다시 뽑기"는 없다. 더 뽑으려면 자료를 다시 올린다.
class SourceDetailScreen extends ConsumerWidget {
  const SourceDetailScreen({super.key, required this.sourceId});

  final String sourceId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    StudySource source,
  ) async {
    final ok = await showArcadeConfirm(
      context,
      title: '자료 기록을 지울까요?',
      message: '이 자료로 만든 카드는 그대로 남아요.',
      confirmLabel: '지우기',
      confirmColor: AppColors.wrong,
    );
    if (!ok) return;
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
        appBar: const ArcadeAppBar(),
        body: Center(child: Text('불러오지 못했어요\n$e')),
      ),
      data: (source) {
        if (source == null) {
          return const Scaffold(
            appBar: ArcadeAppBar(),
            body: Center(child: Text('지워진 자료예요')),
          );
        }
        return Scaffold(
          appBar: ArcadeAppBar(
            trailing: [
              ArcadeIconButton(
                icon: Icons.delete_outline,
                semanticLabel: '지우기',
                onPressed: () => _delete(context, ref, source),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.section * 2,
            ),
            children: [
              Row(
                children: [
                  StatChip(label: '${source.week}주차', color: AppColors.paper),
                  const SizedBox(width: AppSpacing.sm),
                  StatChip(
                    label: sourceStatusLabel(source.status),
                    color: sourceStatusColor(source.status),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(sourceIcon(source.kind), size: 30, color: AppColors.ink),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(source.fileName, style: AppTextStyles.titleM),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              ChunkyCard(
                title: '핵심 요약',
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
              if (source.transcript.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.section),
                TranscriptCard(lines: source.transcript),
              ],
              const SizedBox(height: AppSpacing.section),
              if (cards.isNotEmpty)
                ChunkyButton(
                  label: draftCount > 0
                      ? '카드 ${cards.length}장 검수하기 · 초안 $draftCount'
                      : '카드 ${cards.length}장 보기',
                  icon: Icons.fact_check_outlined,
                  large: true,
                  color: draftCount > 0 ? AppColors.pink : AppColors.lime,
                  onPressed: () => _openReview(context, source),
                )
              else if (!source.isProcessing)
                const ArcadeEmpty(message: '이 자료로 만든 카드가 없어요.'),
              const SizedBox(height: AppSpacing.md),
              const Text(
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

/// 녹음 시간별 전사. 길면 앞부분만 보이고 "전체 보기"로 펼친다.
class TranscriptCard extends StatefulWidget {
  const TranscriptCard({super.key, required this.lines});

  final List<TranscriptLine> lines;

  /// 접혀 있을 때 보이는 줄 수
  static const foldedLines = 6;

  @override
  State<TranscriptCard> createState() => _TranscriptCardState();
}

class _TranscriptCardState extends State<TranscriptCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final lines = widget.lines;
    final foldable = lines.length > TranscriptCard.foldedLines;
    final shown = _open || !foldable
        ? lines
        : lines.take(TranscriptCard.foldedLines).toList();
    return ChunkyCard(
      title: '강의 전사',
      trailing: Text(
        '${lines.length}문단 · ${lines.last.clock}',
        style: AppTextStyles.caption,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final l in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: AppSpacing.minTouch * 1.2,
                    child: Text(
                      l.clock,
                      style: AppTextStyles.chip.copyWith(
                        color: AppColors.grape,
                      ),
                    ),
                  ),
                  Expanded(child: Text(l.text, style: AppTextStyles.bodyS)),
                ],
              ),
            ),
          if (foldable)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _open = !_open),
                child: Text(_open ? '접기' : '전체 보기 (${lines.length}문단)'),
              ),
            ),
        ],
      ),
    );
  }
}
