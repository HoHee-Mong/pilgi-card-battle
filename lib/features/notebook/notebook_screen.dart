import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/card.dart';
import '../../core/models/source.dart';
import '../../core/models/subject.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/chunky_card.dart';
import '../../core/widgets/stat_chip.dart';
import '../../core/widgets/vote_button.dart';
import '../cards/card_edit_screen.dart';
import '../cards/card_list_tile.dart';
import '../cards/card_providers.dart';
import '../sources/source_detail_screen.dart';
import '../sources/source_tile.dart';
import '../subjects/arcade_app_bar.dart';
import 'notebook_model.dart';
import 'notebook_providers.dart';
import 'room_card_sheet.dart';

/// AI 족보 노트: 과목의 카드를 주차별로 모아 보고, 핵심 요약과 출처를 같이 본다.
/// 필터: 내 카드(검수 상태) / 방 카드(투표 수).
class NotebookScreen extends ConsumerStatefulWidget {
  const NotebookScreen({super.key, required this.subject});

  final Subject subject;

  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends ConsumerState<NotebookScreen> {
  NotebookScope _scope = NotebookScope.mine;
  NotebookStatus _status = NotebookStatus.all;

  Subject get subject => widget.subject;

  @override
  Widget build(BuildContext context) {
    final sources =
        ref.watch(subjectSourcesProvider(subject.id)).value ?? const [];
    final sourcesByWeek = groupByWeek(sources, (s) => s.week);

    return Scaffold(
      appBar: ArcadeAppBar(
        trailing: [StatChip(label: subject.name, color: AppColors.paper)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.section * 2,
        ),
        children: [
          const ArcadeTitle(title: '족보 노트', subtitle: '주차별 카드와 핵심 요약, 출처'),
          const SizedBox(height: AppSpacing.section),
          _ScopeChips(
            value: _scope,
            onChanged: (v) => setState(() => _scope = v),
          ),
          if (_scope == NotebookScope.mine) ...[
            const SizedBox(height: AppSpacing.sm),
            _StatusChips(
              value: _status,
              onChanged: (v) => setState(() => _status = v),
            ),
          ],
          const SizedBox(height: AppSpacing.section),
          switch (_scope) {
            NotebookScope.mine => _MineBody(
              subject: subject,
              status: _status,
              sourcesByWeek: sourcesByWeek,
            ),
            NotebookScope.room => _RoomBody(
              subject: subject,
              sourcesByWeek: sourcesByWeek,
            ),
          },
        ],
      ),
    );
  }
}

// ───────────────────────── 필터 칩 ─────────────────────────

class _ScopeChips extends StatelessWidget {
  const _ScopeChips({required this.value, required this.onChanged});

  final NotebookScope value;
  final ValueChanged<NotebookScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final (s, label) in const [
          (NotebookScope.mine, '내 카드'),
          (NotebookScope.room, '방 카드'),
        ])
          ChoiceChip(
            label: Text(label),
            selected: value == s,
            onSelected: (_) => onChanged(s),
          ),
      ],
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.value, required this.onChanged});

  final NotebookStatus value;
  final ValueChanged<NotebookStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final (s, label) in const [
          (NotebookStatus.all, '전체'),
          (NotebookStatus.verified, '검수 완료'),
          (NotebookStatus.draft, '초안'),
        ])
          ChoiceChip(
            label: Text(label),
            selected: value == s,
            onSelected: (_) => onChanged(s),
          ),
      ],
    );
  }
}

// ───────────────────────── 내 카드 ─────────────────────────

class _MineBody extends ConsumerWidget {
  const _MineBody({
    required this.subject,
    required this.status,
    required this.sourcesByWeek,
  });

  final Subject subject;
  final NotebookStatus status;
  final Map<int, List<StudySource>> sourcesByWeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      myCardsProvider((subjectId: subject.id, week: null)),
    );
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.section),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ArcadeEmpty(message: '카드를 불러오지 못했어요\n$e'),
      data: (all) {
        final cards = filterByStatus(all, status);
        final verified = all.where((c) => c.isVerified).length;
        // 카드는 없어도 자료 요약이 있는 주차는 보여 준다.
        final weeks = {
          ...groupByWeek(cards, (c) => c.week).keys,
          ...sourcesByWeek.keys,
        }.toList()..sort();
        final byWeek = groupByWeek(cards, (c) => c.week);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                StatChip(label: '카드 ${all.length}', color: AppColors.paper),
                StatChip(label: '검수 완료 $verified', color: AppColors.lime),
                if (all.length - verified > 0)
                  StatChip(
                    label: '초안 ${all.length - verified}',
                    color: AppColors.pink,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            if (weeks.isEmpty)
              const ArcadeEmpty(
                message: '아직 카드가 없어요.\n주차 화면에서 필기를 찍거나 직접 써 보세요.',
              ),
            for (final week in weeks) ...[
              _WeekSection(
                week: week,
                sources: sourcesByWeek[week] ?? const [],
                count: byWeek[week]?.length ?? 0,
                children: [
                  for (final c in byWeek[week] ?? const <QuizCard>[]) ...[
                    CardListTile(
                      card: c,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CardEditScreen.edit(card: c),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.section),
            ],
          ],
        );
      },
    );
  }
}

// ───────────────────────── 방 카드 ─────────────────────────

class _RoomBody extends ConsumerWidget {
  const _RoomBody({required this.subject, required this.sourcesByWeek});

  final Subject subject;
  final Map<int, List<StudySource>> sourcesByWeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(subjectRoomsProvider(subject.id));
    if (rooms.isEmpty) {
      return const ArcadeEmpty(
        message: '이 과목으로 들어간 스터디 방이 없어요.\n문제은행 탭에서 방을 만들거나 초대 코드로 들어가면 친구 카드가 여기 모여요.',
      );
    }
    final async = ref.watch(roomCardsProvider(subject.id));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.section),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ArcadeEmpty(message: '방 카드를 불러오지 못했어요\n$e'),
      data: (items) {
        if (items.isEmpty) {
          return const ArcadeEmpty(
            message: '아직 방에 공유된 카드가 없어요.\n검수 완료한 카드를 "방에 공유"해 보세요.',
          );
        }
        final byWeek = groupByWeek(items, (it) => it.card.week);
        final votes = items.fold<int>(0, (n, it) => n + it.entry.voteCount);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                StatChip(
                  label: rooms.length == 1
                      ? rooms.single.name
                      : '방 ${rooms.length}곳',
                  color: AppColors.lime,
                ),
                StatChip(label: '카드 ${items.length}', color: AppColors.paper),
                StatChip(
                  label: '나올 것 같아요 $votes',
                  icon: Icons.star_outline,
                  color: AppColors.sun,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            for (final entry in byWeek.entries) ...[
              _WeekSection(
                week: entry.key,
                sources: sourcesByWeek[entry.key] ?? const [],
                count: entry.value.length,
                children: [
                  for (final it in entry.value) ...[
                    CardListTile(
                      card: it.card,
                      caption:
                          '${it.entry.addedByNickname} · '
                          '${it.card.sourceLabel.isEmpty ? '직접 작성' : it.card.sourceLabel}',
                      showStatus: false,
                      trailing: VoteButton(
                        roomId: it.room.id,
                        cardId: it.card.id,
                        compact: true,
                      ),
                      onTap: () => showRoomCardSheet(context, it),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.section),
            ],
          ],
        );
      },
    );
  }
}

// ───────────────────────── 주차 섹션 ─────────────────────────

/// "N주차" 제목 + 그 주차 자료의 핵심 요약 + 카드 목록.
class _WeekSection extends StatelessWidget {
  const _WeekSection({
    required this.week,
    required this.sources,
    required this.count,
    required this.children,
  });

  final int week;
  final List<StudySource> sources;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final withSummary = sources.where((s) => s.summary != null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('$week주차', style: AppTextStyles.titleM)),
            StatChip(label: '카드 $count', color: AppColors.paper),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final s in withSummary) ...[
          _SummaryCard(source: s),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text('이 주차에는 카드가 없어요.', style: AppTextStyles.caption),
          )
        else
          ...children,
      ],
    );
  }
}

/// 자료 핵심 요약 카드. 누르면 자료 상세로.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.source});

  final StudySource source;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      color: AppColors.sun,
      radius: AppRadius.button,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SourceDetailScreen(sourceId: source.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(sourceIcon(source.kind), size: 18, color: AppColors.ink),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '핵심 요약 · ${source.fileName}',
                  style: AppTextStyles.label.copyWith(color: AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.ink),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            source.summary!,
            style: AppTextStyles.bodyS,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
