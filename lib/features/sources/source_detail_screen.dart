import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/source.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_button.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/stat_chip.dart';
import '../cards/card_providers.dart';
import '../cards/card_review_screen.dart';
import '../notebook/notebook_providers.dart';
import '../subjects/arcade_app_bar.dart';
import '../subjects/arcade_dialog.dart';
import 'concept_signals.dart';
import 'source_providers.dart';
import 'source_tile.dart';

/// 자료 하나: 상태, 요약, (녹음) 교수님 강조 발언·전사본, 중요 개념 근거, 만든 카드 검수로 이동.
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
              if (source.emphasis.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.section),
                _EmphasisCard(lines: source.emphasis),
              ],
              if (cards.isNotEmpty || source.emphasis.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.section),
                _ConceptCard(
                  signals: buildConceptSignals(
                    cards: cards,
                    emphasis: source.emphasis,
                    votesByCardId: {
                      for (final rc
                          in ref
                                  .watch(roomCardsProvider(source.subjectId))
                                  .value ??
                              const [])
                        rc.card.id: rc.entry.voteCount,
                    },
                  ),
                  isAudio: source.kind == SourceKind.audio,
                ),
              ],
              if (source.transcript.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.section),
                _TranscriptCard(lines: source.transcript),
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

/// 교수님이 실제로 한 강조 발언 (녹음 시간과 함께).
class _EmphasisCard extends StatelessWidget {
  const _EmphasisCard({required this.lines});

  final List<EmphasisLine> lines;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      title: '교수님 강조 발언',
      color: AppColors.sun,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatChip(label: formatTimestamp(e.t), color: AppColors.paper),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('“${e.quote}”', style: AppTextStyles.body),
                      if (e.concept.isNotEmpty)
                        Text(e.concept, style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            '녹음에서 교수님이 직접 말한 부분만 모았어요. 잘못 들었을 수 있으니 시간으로 확인해 보세요.',
            style: AppTextStyles.caption.copyWith(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

/// 개념별 근거: AI 추정 / 교수님 실제 발언 / 친구 투표를 서로 다른 색으로 구분한다.
class _ConceptCard extends StatelessWidget {
  const _ConceptCard({required this.signals, required this.isAudio});

  final List<ConceptSignal> signals;
  final bool isAudio;

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty) return const SizedBox.shrink();
    return ChunkyCard(
      title: '중요 개념',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              const StatChip(label: 'AI 추정', color: AppColors.paper),
              if (isAudio)
                const StatChip(label: '교수님 발언', color: AppColors.sun),
              const StatChip(label: '친구 투표', color: AppColors.lime),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final s in signals.take(8)) ...[
            Text(s.concept, style: AppTextStyles.heading),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (s.cardCount > 0)
                  StatChip(
                    label: 'AI 카드 ${s.cardCount}',
                    color: AppColors.paper,
                    border: false,
                  ),
                for (final q in s.quotes.take(3))
                  StatChip(
                    label: '교수님 ${formatTimestamp(q.t)}',
                    icon: Icons.record_voice_over_outlined,
                    color: AppColors.sun,
                    border: false,
                  ),
                if (s.votes > 0)
                  StatChip(
                    label: '친구 ${s.votes}표',
                    icon: Icons.how_to_vote_outlined,
                    color: AppColors.lime,
                    border: false,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const Text(
            'AI 추정은 AI가 문제로 만든 개념, 교수님 발언은 녹음 속 실제 말, 친구 투표는 방에서 받은 "나올 것 같아요" 수예요. 출제 보장은 아니에요.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

/// 녹음 전사본 (접어 두고 펼쳐 본다).
class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.lines});

  final List<TranscriptLine> lines;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text('전사본 · ${lines.length}줄', style: AppTextStyles.heading),
          subtitle: const Text('강의 핵심 구간을 시간별로', style: AppTextStyles.caption),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        formatTimestamp(l.t),
                        style: AppTextStyles.label,
                      ),
                    ),
                    Expanded(child: Text(l.text, style: AppTextStyles.bodyS)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
